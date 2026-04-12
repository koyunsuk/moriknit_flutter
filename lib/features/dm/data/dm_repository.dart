import 'package:cloud_firestore/cloud_firestore.dart';

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
    required String uid2,
    required String name2,
    String photo2 = '',
  }) async {
    final docRef = await _rooms.add({
      'participants': [uid1, uid2],
      'participantNames': {uid1: name1, uid2: name2},
      'participantPhotos': {uid1: photo1, uid2: photo2},
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': {uid1: 0, uid2: 0},
    });
    return docRef.id;
  }

  /// Finds or creates a DM room between two users. Returns the room ID.
  Future<String> getOrCreateRoom({
    required String uid1,
    required String name1,
    String photo1 = '',
    required String uid2,
    required String name2,
    String photo2 = '',
  }) async {
    final existing = await findRoom(uid1, uid2);
    if (existing != null) return existing.id;
    return createRoom(uid1: uid1, name1: name1, photo1: photo1, uid2: uid2, name2: name2, photo2: photo2);
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

  /// Searches users by displayName prefix (case-insensitive via range query).
  Future<List<Map<String, String>>> searchUsers(String query, {String? excludeUid}) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final snap = await _db
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: q)
        .where('displayName', isLessThan: '$qꯦ')
        .limit(20)
        .get();
    return snap.docs
        .map((doc) => {
              'uid': doc.id,
              'displayName': (doc.data()['displayName'] as String?) ?? '',
              'email': (doc.data()['email'] as String?) ?? '',
            })
        .where((u) => u['uid'] != excludeUid && (u['displayName']!.isNotEmpty))
        .toList();
  }
}
