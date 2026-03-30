import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/encyclopedia/data/encyclopedia_repository.dart';
import '../features/encyclopedia/data/personal_encyclopedia_repository.dart';
import '../features/encyclopedia/domain/encyclopedia_entry.dart';
import '../features/encyclopedia/domain/personal_encyclopedia_entry.dart';

final encyclopediaRepositoryProvider = Provider<EncyclopediaRepository>((_) => EncyclopediaRepository());

final personalEncyclopediaRepositoryProvider =
    Provider<PersonalEncyclopediaRepository>((_) => PersonalEncyclopediaRepository());

final encyclopediaProvider = StreamProvider<List<EncyclopediaEntry>>((ref) {
  return ref.watch(encyclopediaRepositoryProvider).watchAll();
});

final selectedEncyclopediaCategoryProvider = StateProvider<String>((_) => 'all');

/// 개인 사전 항목 스트림 (uid 기반)
final personalEncyclopediaProvider =
    StreamProvider.family<List<PersonalEncyclopediaEntry>, String>((ref, uid) {
  return ref.watch(personalEncyclopediaRepositoryProvider).watchAll(uid);
});

/// 북마크된 공식 항목의 sourceId 집합
final bookmarkedIdsProvider = Provider.family<Set<String>, String>((ref, uid) {
  final entries = ref.watch(personalEncyclopediaProvider(uid)).valueOrNull ?? [];
  return entries.where((e) => e.isBookmark && e.sourceId.isNotEmpty).map((e) => e.sourceId).toSet();
});

/// 북마크 토글 (추가/제거)
Future<void> toggleBookmark({
  required PersonalEncyclopediaRepository repo,
  required String uid,
  required EncyclopediaEntry entry,
  required bool isCurrentlyBookmarked,
}) async {
  if (isCurrentlyBookmarked) {
    await repo.removeBySourceId(uid, entry.id);
  } else {
    await repo.addBookmark(uid, {
      'term': entry.term,
      'definition': entry.description,
      'example': '',
      'sourceId': entry.id,
      'isBookmark': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
