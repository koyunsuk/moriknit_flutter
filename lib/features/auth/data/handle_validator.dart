import 'package:cloud_firestore/cloud_firestore.dart';

/// 이슈 #771 — 회원 닉네임(@핸들) 시스템.
///
/// 핸들 형식 검증 + 중복 체크 + reservation 트랜잭션 제공.
///
/// Firestore 구조:
/// - `handles/{normalized}` — 문서 ID = 소문자 normalized handle
///   - data: `{ userId, displayHandle, reservedAt }`
/// - `users/{uid}.handle` — 사용자 문서에 머지된 displayHandle
///
/// 정책:
/// - 형식: `^[a-z0-9_]{3,20}$` (소문자/숫자/언더스코어 3~20자)
/// - 변경 제한: 마이페이지에서 마지막 변경 후 30일 경과 시에만 허용
class HandleValidator {
  HandleValidator({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// 핸들 정규화 (소문자 + 양끝 공백 제거 + 선행 @ 제거).
  static String normalize(String raw) {
    var s = raw.trim().toLowerCase();
    while (s.startsWith('@')) {
      s = s.substring(1);
    }
    return s;
  }

  /// 핸들 형식 검증. `^[a-z0-9_]{3,20}$`.
  static bool isValidHandleFormat(String handle) {
    final normalized = normalize(handle);
    return RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(normalized);
  }

  /// `handles/{handle}` 문서가 존재하지 않으면 사용 가능.
  Future<bool> isHandleAvailable(String handle) async {
    final normalized = normalize(handle);
    if (!isValidHandleFormat(normalized)) return false;
    try {
      final doc = await _db.collection('handles').doc(normalized).get();
      return !doc.exists;
    } catch (_) {
      // 네트워크/권한 에러 시 안전하게 사용 불가로 간주.
      return false;
    }
  }

  /// 트랜잭션 reservation — race condition 방지.
  /// 1) handles/{handle}.exists 재확인 → 이미 있으면 예외.
  /// 2) handles/{handle} 신규 문서 생성.
  /// 3) users/{uid}.handle / handleUpdatedAt 머지.
  Future<void> reserveHandle({
    required String uid,
    required String handle,
  }) async {
    final normalized = normalize(handle);
    if (!isValidHandleFormat(normalized)) {
      throw Exception('Invalid handle format');
    }
    final handleRef = _db.collection('handles').doc(normalized);
    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(handleRef);
      if (snap.exists) {
        throw Exception('Handle already taken');
      }
      tx.set(handleRef, {
        'userId': uid,
        'displayHandle': normalized,
        'reservedAt': FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {
        'handle': normalized,
        'handleUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// 기존 핸들 해제 + 새 핸들 reservation. 마이페이지에서 변경 시 사용.
  /// 30일 변경 제한 검사는 호출자(UI)가 책임.
  Future<void> changeHandle({
    required String uid,
    required String oldHandle,
    required String newHandle,
  }) async {
    final oldNormalized = normalize(oldHandle);
    final newNormalized = normalize(newHandle);
    if (!isValidHandleFormat(newNormalized)) {
      throw Exception('Invalid handle format');
    }
    if (oldNormalized == newNormalized) return;
    final newRef = _db.collection('handles').doc(newNormalized);
    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(newRef);
      if (snap.exists) {
        throw Exception('Handle already taken');
      }
      tx.set(newRef, {
        'userId': uid,
        'displayHandle': newNormalized,
        'reservedAt': FieldValue.serverTimestamp(),
      });
      if (oldNormalized.isNotEmpty) {
        final oldRef = _db.collection('handles').doc(oldNormalized);
        tx.delete(oldRef);
      }
      tx.set(userRef, {
        'handle': newNormalized,
        'handleUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// 핸들로 사용자 uid 조회 (멘션 링크 등에 활용).
  Future<String?> resolveUidByHandle(String handle) async {
    final normalized = normalize(handle);
    if (!isValidHandleFormat(normalized)) return null;
    try {
      final doc = await _db.collection('handles').doc(normalized).get();
      if (!doc.exists) return null;
      return (doc.data()?['userId'] as String?);
    } catch (_) {
      return null;
    }
  }
}
