import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// #650 — 사용자가 입력한 브랜드명을 공용 마스터 컬렉션에 자동 누적.
///
/// - yarn_brands / needle_brands 컬렉션에 동일 이름 없으면 create
/// - 이미 있으면 skip (멱등성)
/// - firestore.rules: read/create는 isLoggedIn, update/delete는 isAdmin
class PublicBrandRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> upsertYarnBrand(String name) =>
      _upsert('yarn_brands', name);

  Future<void> upsertNeedleBrand(String name) =>
      _upsert('needle_brands', name);

  Future<void> _upsert(String collection, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      // 동일 이름 존재 여부 확인
      final existing = await _db
          .collection(collection)
          .where('name', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return; // 이미 등록됨
      await _db.collection(collection).add({
        'name': trimmed,
        'nameLower': trimmed.toLowerCase(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // 무음 — 사용자 본 작업(바늘/실 저장)에 영향 X
    }
  }
}

final publicBrandRepositoryProvider =
    Provider<PublicBrandRepository>((ref) => PublicBrandRepository());
