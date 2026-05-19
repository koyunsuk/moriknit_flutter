import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/system_users.dart';
import '../features/dm/data/dm_repository.dart';
import '../features/dm/domain/dm_model.dart';

final dmRepositoryProvider = Provider<DmRepository>((ref) => DmRepository());

final dmRoomsProvider = StreamProvider.family<List<DmRoom>, String>((ref, uid) {
  return ref.watch(dmRepositoryProvider).watchRooms(uid);
});

final dmMessagesProvider = StreamProvider.family<List<DmMessage>, String>((ref, roomId) {
  return ref.watch(dmRepositoryProvider).watchMessages(roomId);
});

/// 이슈 #837 — 어드민 인박스: @moriknit 시스템 봇과의 모든 DM 룸 스트림.
/// 정렬: unrespondedSince ASC (미응답이 오래된 순) → lastMessageAt DESC.
/// dm_rooms collection 에서 participants 에 moriknit_system 이 포함된 룸을
/// arrayContains 로 조회 (어드민 권한 필요).
final adminMoriknitInboxRoomsProvider =
    StreamProvider<List<DmRoom>>((ref) {
  return FirebaseFirestore.instance
      .collection('dm_rooms')
      .where('participants', arrayContains: SystemUsers.moriknitUid)
      .snapshots()
      .map((snap) {
    final rooms = snap.docs.map(DmRoom.fromFirestore).toList();
    // 1) 미응답 룸을 먼저, 그 안에서 unrespondedSince 오래된 순.
    // 2) 미응답 없는 룸은 lastMessageAt 최신순.
    rooms.sort((a, b) {
      final aUn = a.unrespondedSince;
      final bUn = b.unrespondedSince;
      if (aUn != null && bUn != null) {
        return aUn.compareTo(bUn);
      }
      if (aUn != null) return -1;
      if (bUn != null) return 1;
      return b.lastMessageAt.compareTo(a.lastMessageAt);
    });
    return rooms;
  });
});
