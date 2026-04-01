import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/community/data/guestbook_repository.dart';
import '../features/community/domain/guestbook_entry.dart';

final guestbookRepositoryProvider = Provider<GuestbookRepository>((ref) {
  return GuestbookRepository();
});

final guestbookListProvider = StreamProvider<List<GuestbookEntry>>((ref) {
  return ref.watch(guestbookRepositoryProvider).watchLatest(limit: 20);
});
