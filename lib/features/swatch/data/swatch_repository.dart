// lib/features/swatch/data/swatch_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import '../domain/swatch_model.dart';
import '../../../core/constants/subscription_constants.dart';

class SwatchRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _swatchesRef =>
      _db.collection('users').doc(_uid).collection('swatches');

  DocumentReference get _userRef =>
      _db.collection('users').doc(_uid);

  // ── CREATE ───────────────────────────────────────────────
  Future<SwatchModel> createSwatch(SwatchModel swatch) async {
    // 세션 체크
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    // 수축률 자동 계산
    final calculated = swatch.copyWith(
      shrinkageRate: swatch.calculateShrinkageRate(),
      updatedAt: DateTime.now(),
    );

    // Hive에 즉시 저장 (오프라인 안전)
    await _saveToHive(calculated);

    // Firestore에 저장 + usage.swatchCount +1 (트랜잭션)
    try {
      final docRef = swatch.id.isEmpty
          ? _swatchesRef.doc()
          : _swatchesRef.doc(swatch.id);

      await _db.runTransaction((transaction) async {
        transaction.set(docRef, {
          ...calculated.toJson(),
          'id': docRef.id,
          'uid': _uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isDirty': false,
        });
        // usage.swatchCount 증가
        transaction.update(_userRef, {
          'usage.swatchCount': FieldValue.increment(1),
        });
      });

      final saved = calculated.copyWith(id: docRef.id, isDirty: false);
      await _saveToHive(saved); // Hive 업데이트 (id 반영)
      return saved;
    } catch (e) {
      // Firestore 실패 시 Hive에 dirty 상태로 유지 → 나중에 sync
      await _saveToHive(calculated.copyWith(isDirty: true));
      return calculated.copyWith(isDirty: true);
    }
  }

  // ── DUPLICATE ────────────────────────────────────────────
  Future<SwatchModel> duplicateSwatch(SwatchModel original) async {
    final now = DateTime.now();
    final copy = original.copyWith(
      id: '',
      swatchName: original.swatchName.isEmpty
          ? ''
          : '${original.swatchName} (복사)',
      createdAt: now,
      updatedAt: now,
      isDirty: false,
    );
    return createSwatch(copy);
  }

  // ── READ (목록) ──────────────────────────────────────────
  Stream<List<SwatchModel>> watchSwatches() {
    if (_uid.isEmpty) return Stream.value([]);
    return _swatchesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SwatchModel.fromFirestore(doc))
            .toList());
  }

  // ── READ (단건, 스트림) ──────────────────────────────────
  Stream<SwatchModel?> watchSwatch(String swatchId) {
    if (_uid.isEmpty) return Stream.value(null);
    return _swatchesRef.doc(swatchId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SwatchModel.fromFirestore(doc);
    });
  }

  // ── READ (단건) ──────────────────────────────────────────
  Future<SwatchModel?> getSwatch(String swatchId) async {
    final doc = await _swatchesRef.doc(swatchId).get();
    if (!doc.exists) return null;
    return SwatchModel.fromFirestore(doc);
  }

  // ── UPDATE ───────────────────────────────────────────────
  Future<SwatchModel> updateSwatch(SwatchModel swatch) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final updated = swatch.copyWith(
      shrinkageRate: swatch.calculateShrinkageRate(),
      updatedAt: DateTime.now(),
    );

    await _saveToHive(updated);

    try {
      await _swatchesRef.doc(swatch.id).update({
        ...updated.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDirty': false,
      });
      return updated.copyWith(isDirty: false);
    } catch (e) {
      await _saveToHive(updated.copyWith(isDirty: true));
      return updated.copyWith(isDirty: true);
    }
  }

  // ── DELETE ───────────────────────────────────────────────
  Future<void> deleteSwatch(String swatchId) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    // Hive에서 제거
    await _removeFromHive(swatchId);

    // Firestore 삭제 + usage.swatchCount -1
    await _db.runTransaction((transaction) async {
      transaction.delete(_swatchesRef.doc(swatchId));
      transaction.update(_userRef, {
        'usage.swatchCount': FieldValue.increment(-1),
      });
    });
  }

  // ── Hive 로컬 저장 ───────────────────────────────────────
  Future<void> _saveToHive(SwatchModel swatch) async {
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxSwatches);
    await box.put(swatch.id.isEmpty ? 'temp_${DateTime.now().millisecondsSinceEpoch}' : swatch.id,
        swatch.toJson());
  }

  Future<void> _removeFromHive(String swatchId) async {
    if (kIsWeb) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxSwatches);
    await box.delete(swatchId);
  }

  // ── Dirty 항목 sync (30분마다 호출) ─────────────────────
  Future<void> syncDirtySwatches() async {
    if (kIsWeb || _uid.isEmpty) return;
    final box = Hive.box<Map>(SubscriptionConstants.boxSwatches);
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null && data['isDirty'] == true) {
        try {
          final swatch = SwatchModel.fromJson(Map<String, dynamic>.from(data));
          await updateSwatch(swatch);
        } catch (e) {
          // sync 실패 시 다음 타이머에 재시도
        }
      }
    }
  }
}
