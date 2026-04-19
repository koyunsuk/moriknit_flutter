import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/photo_album_item.dart';
import '../../../providers/auth_provider.dart';

class PhotoAlbumRepository {
  final FirebaseFirestore _db;
  final String uid;

  PhotoAlbumRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  /// users/{uid}/projects 의 coverPhotoUrl + photoUrls 전부 수집
  Future<List<PhotoAlbumItem>> fetchProjectPhotos() async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .get();

    final result = <PhotoAlbumItem>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final projectName = (data['title'] as String?) ?? '';
      final createdAt = _parseDate(data['createdAt']);
      final cover = (data['coverPhotoUrl'] as String?) ?? '';
      final photoUrls = (data['photoUrls'] as List?)?.cast<String>() ?? [];

      final seen = <String>{};

      void add(String url) {
        if (url.isNotEmpty && seen.add(url)) {
          result.add(PhotoAlbumItem(
            imageUrl: url,
            sourceType: 'project',
            sourceName: projectName,
            sourceId: doc.id,
            createdAt: createdAt,
          ));
        }
      }

      if (cover.isNotEmpty) add(cover);
      for (final url in photoUrls) {
        add(url);
      }
    }
    return result;
  }

  /// users/{uid}/swatches 의 beforePhotoUrl / afterPhotoUrl 수집
  Future<List<PhotoAlbumItem>> fetchSwatchPhotos() async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('swatches')
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
            sourceId: doc.id,
            createdAt: createdAt,
          ));
        }
      }
    }
    return result;
  }

  /// users/{uid}/accessories 의 photoUrl 수집
  Future<List<PhotoAlbumItem>> fetchAccessoryPhotos() async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('myAccessories')
        .get();

    final result = <PhotoAlbumItem>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final url = (data['photoUrl'] as String?) ?? '';
      if (url.isNotEmpty) {
        result.add(PhotoAlbumItem(
          imageUrl: url,
          sourceType: 'accessory',
          sourceName: (data['name'] as String?) ?? '',
          sourceId: doc.id,
          createdAt: _parseDate(data['createdAt']),
        ));
      }
    }
    return result;
  }

  /// 전체 사진 수집 후 최신순 정렬
  Future<List<PhotoAlbumItem>> fetchAll() async {
    final results = await Future.wait([
      fetchProjectPhotos(),
      fetchSwatchPhotos(),
      fetchAccessoryPhotos(),
    ]);
    final all = [...results[0], ...results[1], ...results[2]];
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
