// 이슈 #704 Phase 0 — Firestore 호출 일괄 timeout 적용.
// 이슈 #803 — 기본 timeout 5초→15초 (느린 회선/대용량 청사진 저장 대응).
//
// 모든 Firestore Future 호출 끝에 `.withServerTimeout()` 를 붙이면
// 15초 내 응답 없거나 FirebaseException 발생 시
// ServerUnavailableException 으로 통일 throw.
//
// 사용 예:
//   await _col.doc(id).get().withServerTimeout(op: 'get_xxx');
//   await _col.doc(id).set(data).withServerTimeout(op: 'set_xxx');
//
// Stream(snapshots())에는 적용하지 않음 — Future 전용 extension.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'network_errors.dart';

extension FirestoreTimeoutX<T> on Future<T> {
  Future<T> withServerTimeout({
    Duration d = const Duration(seconds: 15),
    String? op,
  }) async {
    try {
      return await timeout(d);
    } on TimeoutException {
      throw ServerUnavailableException(op ?? 'firestore timeout');
    } on FirebaseException catch (e) {
      // 이슈 #803 — permission-denied 는 별도 분류해서 사용자에게
      // "권한 문제" 안내, 단순 네트워크 장애와 구분.
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException(op ?? e.code);
      }
      throw ServerUnavailableException('firestore: ${e.code}');
    }
  }
}
