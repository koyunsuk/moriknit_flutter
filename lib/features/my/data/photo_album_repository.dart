import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/photo_album_item.dart';
import '../../../providers/auth_provider.dart';

class PhotoAlbumRepository {
  final FirebaseFirestore _db;
  final String uid;

  PhotoAlbumRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  /// projects/{uid}/items 의 coverPhotoUrl(또는 photoUrls[0]) 수집
  Future<List<PhotoAlbumItem>> fetchProjectPhotos() async {
    final snap = await _db
        .collection('projects')
        .doc(uid)
        .collection('items')
        .get();

    final result = <PhotoAlbumItem>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final cover = (data['coverPhotoUrl'] as String?) ?? '';
      final photoUrls = (data['photoUrls'] as List?)?.cast<String>() ?? [];

      // coverPhotoUrl 우선, 없으면 photoUrls 전부 추가
      if (cover.isNotEmpty) {
        result.add(PhotoAlbumItem(
          imageUrl: cover,
          sourceType: 'project',
          sourceName: (data['title'] as String?) ?? '',
          createdAt: _parseDate(data['createdAt']),
        ));
      } else {
        for (final url in photoUrls) {
          if (url.isNotEmpty) {
            result.add(PhotoAlbumItem(
              imageUrl: url,
              sourceType: 'project',
              sourceName: (data['title'] as String?) ?? '',
              createdAt: _parseDate(data['createdAt']),
            ));
          }
        }
      }
    }
    return result;
  }

  /// swatches/{uid}/items 의 beforePhotoUrl / afterPhotoUrl 수집
  Future<List<PhotoAlbumItem>> fetchSwatchPhotos() async {
    final snap = await _db
        .collection('swatches')
        .doc(uid)
        .collection('items')
        .get();

    final result = <PhotoAlbumItem>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['swatchName'] as String?) ?? '';
      final createdAt = _parseDate(data['createdAt']);

      for (final field in ['beforePhotoUrl', 'afterPhotoUrl']) {
        final url = (data[field] as String?) ?? '';
        if (url.isNotEmpty) {
          result.add(PhotoAlbumItem(
            imageUrl: url,
            sourceType: 'swatch',
            sourceName: name,
            createdAt: createdAt,
          ));
        }
      }
    }
    return result;
  }

  /// 전체 사진 수집 후 최신순 정렬
  Future<List<PhotoAlbumItem>> fetchAll() async {
    final results = await Future.wait([
      fetchProjectPhotos(),
      fetchSwatchPhotos(),
    ]);
    final all = [...results[0], ...results[1]];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime(2000);
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime(2000);
      }
    }
    return DateTime(2000);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final photoAlbumRepositoryProvider = Provider<PhotoAlbumRepository>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  return PhotoAlbumRepository(
    db: FirebaseFirestore.instance,
    uid: auth?.uid ?? '',
  );
});

final photoAlbumItemsProvider =
    FutureProvider<List<PhotoAlbumItem>>((ref) async {
  final repo = ref.watch(photoAlbumRepositoryProvider);
  return repo.fetchAll();
});
