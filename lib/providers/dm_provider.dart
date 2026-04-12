import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dm/data/dm_repository.dart';
import '../features/dm/domain/dm_model.dart';

final dmRepositoryProvider = Provider<DmRepository>((ref) => DmRepository());

final dmRoomsProvider = StreamProvider.family<List<DmRoom>, String>((ref, uid) {
  return ref.watch(dmRepositoryProvider).watchRooms(uid);
});

final dmMessagesProvider = StreamProvider.family<List<DmMessage>, String>((ref, roomId) {
  return ref.watch(dmRepositoryProvider).watchMessages(roomId);
});
