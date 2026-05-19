import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../domain/dm_model.dart';

class DmRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('dm_rooms');

  /// Watches all DM rooms where the current user is a participant,
  /// ordered by last message time.
  Stream<List<DmRoom>> watchRooms(String uid) {
    return _rooms
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DmRoom.fromFirestore).toList());
  }

  /// Watches messages in a specific DM room, ordered chronologically.
  Stream<List<DmMessage>> watchMessages(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(DmMessage.fromFirestore).toList());
  }

  /// Finds an existing DM room between two users, or returns null.
  Future<DmRoom?> findRoom(String uid1, String uid2) async {
    final snap = await _rooms
        .where('participants', arrayContains: uid1)
        .get();
    for (final doc in snap.docs) {
      final participants = List<String>.from((doc.data()['participants'] as List?) ?? []);
      if (participants.contains(uid2)) {
        return DmRoom.fromFirestore(doc);
      }
    }
    return null;
  }

  /// Creates a new DM room between two users and returns the room ID.
  Future<String> createRoom({
    required String uid1,
    required String name1,
    String photo1 = '',
    String handle1 = '',
    required String uid2,
    required String name2,
    String photo2 = '',
    String handle2 = '',
  }) async {
    final docRef = await _rooms.add({
      'participants': [uid1, uid2],
      'participantNames': {uid1: name1, uid2: name2},
      'participantPhotos': {uid1: photo1, uid2: photo2},
      // 이슈 #771 — 핸들 스냅샷 저장 (DM 리스트/채팅 헤더에 @handle 표시용)
      'participantHandles': {uid1: handle1, uid2: handle2},
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': {uid1: 0, uid2: 0},
    });
    return docRef.id;
  }

  /// Finds or creates a DM room between two users. Returns the room ID.
  ///
  /// #837 fix — 시스템 봇(`moriknit_system`)이 참여하는 DM은 어드민 Cloud Functions가
  /// 사용하는 deterministic ID(`[uidA, uidB].sort().join('__')`) 와 통일.
  /// 그렇지 않으면 사용자가 만든 auto-generated ID와 어드민이 쓰는 ID가 불일치하여
  /// 어드민 답장이 사용자에게 보이지 않음.
  Future<String> getOrCreateRoom({
    required String uid1,
    required String name1,
    String photo1 = '',
    String handle1 = '',
    required String uid2,
    required String name2,
    String photo2 = '',
    String handle2 = '',
  }) async {
    const systemUid = 'moriknit_system';
    final isSystemDm = uid1 == systemUid || uid2 == systemUid;
    if (isSystemDm) {
      final ids = [uid1, uid2]..sort();
      final detRoomId = ids.join('__');
      final ref = _rooms.doc(detRoomId);
      final snap = await ref.get();
      if (snap.exists) return detRoomId;
      await ref.set({
        'participants': [uid1, uid2],
        'participantNames': {uid1: name1, uid2: name2},
        'participantPhotos': {uid1: photo1, uid2: photo2},
        'participantHandles': {uid1: handle1, uid2: handle2},
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {uid1: 0, uid2: 0},
        'isSystemChannel': true,
      });
      return detRoomId;
    }
    final existing = await findRoom(uid1, uid2);
    if (existing != null) return existing.id;
    return createRoom(
      uid1: uid1, name1: name1, photo1: photo1, handle1: handle1,
      uid2: uid2, name2: name2, photo2: photo2, handle2: handle2,
    );
  }

  /// Sends a message to a DM room and updates the room's metadata.
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
    required String recipientId,
  }) async {
    final batch = _db.batch();

    // Add message
    final msgRef = _rooms.doc(roomId).collection('messages').doc();
    batch.set(msgRef, {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update room metadata
    batch.update(_rooms.doc(roomId), {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Resets the unread count for a user in a DM room.
  Future<void> markAsRead({required String roomId, required String uid}) async {
    await _rooms.doc(roomId).update({
      'unreadCount.$uid': 0,
    });
  }

  /// 이슈 #834 — DM 진입 시 어드민 브로드캐스트 메시지들을 본인 uid 로 readBy 마킹.
  /// - 본인이 readBy 에 없는 broadcast 메시지만 처리 (write 최소화)
  /// - 각 메시지에 대해 markBroadcastRead Cloud Function 호출
  ///   (notifications.readUids arrayUnion + readCount 갱신 보장)
  /// - 일반 DM 메시지(broadcastId 없음)는 처리하지 않음 — 기존 markAsRead 로 충분
  Future<void> markBroadcastMessagesRead({
    required String roomId,
    required String uid,
    required List<DmMessage> messages,
  }) async {
    final targets = messages
        .where((m) => m.isBroadcast)
        .where((m) => m.broadcastId != null)
        .where((m) => !m.readBy.containsKey(uid))
        .toList();
    if (targets.isEmpty) return;

    final callable = FirebaseFunctions.instance.httpsCallable('markBroadcastRead');
    for (final m in targets) {
      try {
        await callable.call(<String, dynamic>{
          'broadcastId': m.broadcastId,
          'messageId': m.id,
          'roomId': roomId,
        });
      } catch (e) {
        // 네트워크/권한 오류는 무시 — 다음 진입 시 재시도됨
        if (kDebugMode) {
          debugPrint('[markBroadcastMessagesRead] failed for ${m.id}: $e');
        }
      }
    }
  }

  /// Deletes a DM room and all its messages for the given user.
  /// Removes the room document and its messages subcollection.
  Future<void> deleteRoom(String roomId) async {
    // Delete all messages in the subcollection first
    final messagesSnap = await _rooms.doc(roomId).collection('messages').get();
    final batch = _db.batch();
    for (final doc in messagesSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_rooms.doc(roomId));
    await batch.commit();
  }

  /// Deletes a single message from a DM room.
  Future<void> deleteMessage({required String roomId, required String messageId}) async {
    await _rooms.doc(roomId).collection('messages').doc(messageId).delete();
  }

  /// #839 — 검색창 터치(focus) 시 빈 쿼리에도 회원 목록을 보여주기 위한 메서드.
  /// @moriknit 시스템 봇을 최상단 고정 + 최근 가입 회원 일부 반환.
  Future<List<Map<String, String>>> listRecentUsers({
    int limit = 20,
    String? excludeUid,
  }) async {
    final results = <String, Map<String, String>>{};

    // 1. @moriknit 시스템 봇 무조건 최상단 (uid='moriknit_system' 직접 조회).
    try {
      final sysDoc = await _db.collection('users').doc('moriknit_system').get();
      if (sysDoc.exists && sysDoc.id != excludeUid) {
        final data = sysDoc.data() ?? {};
        results[sysDoc.id] = {
          'uid': sysDoc.id,
          'displayName': (data['displayName'] as String?) ?? '모리니트',
          'email': (data['email'] as String?) ?? '',
          'handle': (data['handle'] as String?) ?? 'moriknit',
          'photoURL': (data['photoURL'] as String?) ?? '',
        };
      } else {
        // 도큐먼트 lazy-create 전이면 가상 엔트리로 노출.
        results['moriknit_system'] = {
          'uid': 'moriknit_system',
          'displayName': '모리니트',
          'email': '',
          'handle': 'moriknit',
          'photoURL': '',
        };
      }
    } catch (_) {
      // 권한 등 이슈에도 가상 엔트리로 보장.
      results['moriknit_system'] = {
        'uid': 'moriknit_system',
        'displayName': '모리니트',
        'email': '',
        'handle': 'moriknit',
        'photoURL': '',
      };
    }

    // 2. 최근 가입 회원 limit-1 명 추가 (createdAt DESC).
    try {
      final snap = await _db
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      for (final doc in snap.docs) {
        if (doc.id == excludeUid) continue;
        if (results.containsKey(doc.id)) continue;
        final data = doc.data();
        final name = (data['displayName'] as String?) ?? '';
        if (name.isEmpty) continue;
        results[doc.id] = {
          'uid': doc.id,
          'displayName': name,
          'email': (data['email'] as String?) ?? '',
          'handle': (data['handle'] as String?) ?? '',
          'photoURL': (data['photoURL'] as String?) ?? '',
        };
      }
    } catch (_) {
      // createdAt 없는 옛 도큐먼트 안전 무시
    }

    return results.values.toList();
  }

  /// Searches users by displayName prefix and handle prefix (이슈 #771).
  /// 두 쿼리 결과를 합쳐 uid 기준 dedupe.
  Future<List<Map<String, String>>> searchUsers(String query, {String? excludeUid}) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final qLower = q.toLowerCase();
    final results = <String, Map<String, String>>{};

    // displayName prefix 검색
    final nameSnap = await _db
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: q)
        .where('displayName', isLessThan: '$qꯦ')
        .limit(20)
        .get();
    for (final doc in nameSnap.docs) {
      if (doc.id == excludeUid) continue;
      final data = doc.data();
      final name = (data['displayName'] as String?) ?? '';
      if (name.isEmpty) continue;
      results[doc.id] = {
        'uid': doc.id,
        'displayName': name,
        'email': (data['email'] as String?) ?? '',
        'handle': (data['handle'] as String?) ?? '',
        'photoURL': (data['photoURL'] as String?) ?? '',
      };
    }

    // 이슈 #771 — handle prefix 검색 (소문자 normalized)
    try {
      final handleSnap = await _db
          .collection('users')
          .where('handle', isGreaterThanOrEqualTo: qLower)
          .where('handle', isLessThan: '$qLowerꯦ')
          .limit(20)
          .get();
      for (final doc in handleSnap.docs) {
        if (doc.id == excludeUid) continue;
        if (results.containsKey(doc.id)) continue;
        final data = doc.data();
        final handle = (data['handle'] as String?) ?? '';
        if (handle.isEmpty) continue;
        results[doc.id] = {
          'uid': doc.id,
          'displayName': (data['displayName'] as String?) ?? '',
          'email': (data['email'] as String?) ?? '',
          'handle': handle,
          'photoURL': (data['photoURL'] as String?) ?? '',
        };
      }
    } catch (_) {
      // handle 인덱스 없을 때 안전 무시
    }
    return results.values.toList();
  }
}
