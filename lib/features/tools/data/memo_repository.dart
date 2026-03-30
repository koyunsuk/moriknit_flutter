import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../domain/memo_model.dart';

class MemoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _memosRef(String uid) =>
      _db.collection('users').doc(uid).collection('memos');

  // ── READ ──────────────────────────────────────────────────
  Stream<List<MemoModel>> watchMemos() {
    if (_uid.isEmpty) return Stream.value([]);
    return _memosRef(_uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(MemoModel.fromFirestore).toList());
  }

  // ── CREATE ────────────────────────────────────────────────
  Future<MemoModel> createMemo(MemoModel memo) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final docRef = _memosRef(_uid).doc();
    final data = {
      ...memo.copyWith(id: docRef.id, uid: _uid).toJson(),
      'id': docRef.id,
    };
    await docRef.set(data);
    return memo.copyWith(id: docRef.id, uid: _uid);
  }

  // ── UPDATE ────────────────────────────────────────────────
  Future<void> updateMemo(MemoModel memo) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _memosRef(_uid).doc(memo.id).update(memo.toUpdateJson());
  }

  // ── DELETE ────────────────────────────────────────────────
  Future<void> deleteMemo(String memoId) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _memosRef(_uid).doc(memoId).delete();
  }

  // ── IMAGES ────────────────────────────────────────────────

  /// bytes 리스트를 Storage에 업로드하고 URL 목록을 반환합니다.
  Future<List<String>> uploadImages(List<Uint8List> images) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      try {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ref = _storage.ref('memos/$_uid/${ts}_$i.jpg');
        await ref.putData(images[i], SettableMetadata(contentType: 'image/jpeg'));
        urls.add(await ref.getDownloadURL());
      } catch (e) {
        debugPrint('[MemoRepo] 이미지 업로드 실패 $i: $e');
      }
    }
    return urls;
  }

  // ── MIGRATION ─────────────────────────────────────────────

  /// Hive 데이터 맵을 Firestore로 마이그레이션합니다.
  /// [hiveItems]: Hive box에서 읽어온 Map 리스트
  Future<void> migrateFromHive(List<Map<String, dynamic>> hiveItems) async {
    if (_uid.isEmpty || hiveItems.isEmpty) return;
    final batch = _db.batch();
    for (final item in hiveItems) {
      final docRef = _memosRef(_uid).doc();
      final createdAt = _parseDateTime(item['createdAt']);
      final updatedAt = _parseDateTime(item['updatedAt']);
      batch.set(docRef, {
        'id': docRef.id,
        'uid': _uid,
        'content': item['content'] as String? ?? '',
        'imageUrls': const <String>[], // 로컬 파일 경로는 이전 불가 → 빈 배열
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });
    }
    await batch.commit();
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
