// lib/features/blueprint/data/migration_guard.dart
//
// 이슈 #687 — 앱 시작 시 자동 마이그레이션 트리거 가드.
//
// 목적: BlueprintMigration(uid).migrateAll() 을 사용자별 1회만 자동 실행한다.
//       사용자가 어드민 화면에 진입해 수동으로 누르는 절차 없이, 로그인 후
//       홈 화면 진입 시 백그라운드에서 비동기로 1회 실행한다.
//
// 멱등성:
//   1) users/{uid}/migration_meta/blueprint 문서에 v687_completed 플래그 저장.
//   2) BlueprintMigration 자체도 migrationVersion 필드로 문서별 멱등.
//   3) 두 겹의 멱등성 — 플래그가 없어도 마이그레이션은 안전하게 재실행 가능.
//
// 실패 처리:
//   - 사용자에게 알리지 않는다 (백그라운드).
//   - 디버그 로그만 출력.
//   - 다음 앱 실행 시 자동 재시도 (멱등성 덕분에 안전).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blueprint_migration.dart';

/// 마이그레이션 완료 플래그 키.
/// 신규 마이그레이션이 추가되면 키를 늘려 재실행 유도.
const String _kMigrationFlagKey = 'v687_completed';

/// 시도 횟수 누적 카운터 키 — 영구 실패 루프 차단용.
/// 일정 횟수 초과 시 강제 완료 마킹 (BlueprintMigration 자체가 멱등이라 안전).
const String _kMigrationAttemptKey = 'v687_attempts';
const int _kMaxMigrationAttempts = 3;

/// 사용자별 1회 자동 실행을 보장하는 가드.
class MigrationGuard {
  MigrationGuard({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// 동일 프로세스에서 동시 실행 방지 (홈 재진입 시 중복 발사 차단).
  final Set<String> _inFlight = <String>{};

  DocumentReference<Map<String, dynamic>> _metaDoc(String uid) =>
      _db.collection('users').doc(uid).collection('migration_meta').doc('blueprint');

  /// 플래그 조회 — 이미 마이그레이션 완료 여부 확인.
  Future<bool> hasCompletedMigration(String uid) async {
    try {
      final doc = await _metaDoc(uid).get();
      return doc.exists && (doc.data()?[_kMigrationFlagKey] == true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MigrationGuard] hasCompletedMigration error: $e');
      }
      // 조회 실패 시 보수적으로 false (재시도). BlueprintMigration 자체가 멱등이므로 안전.
      return false;
    }
  }

  /// 완료 마크 저장 — 에러 0건일 때만.
  Future<void> markCompleted(String uid) async {
    try {
      await _metaDoc(uid).set({
        _kMigrationFlagKey: true,
        'completedAt': FieldValue.serverTimestamp(),
        'migrationVersion': kBlueprintMigrationVersion,
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MigrationGuard] markCompleted error: $e');
      }
    }
  }

  /// 시도 횟수 조회 (영구 실패 루프 차단용).
  Future<int> _readAttempts(String uid) async {
    try {
      final doc = await _metaDoc(uid).get();
      return (doc.data()?[_kMigrationAttemptKey] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 시도 횟수 +1 누적.
  Future<void> _bumpAttempts(String uid, int current) async {
    try {
      await _metaDoc(uid).set({
        _kMigrationAttemptKey: current + 1,
        'lastAttemptAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // 누적 실패는 무음 — 다음 세션에서 재시도.
    }
  }

  /// 필요 시 마이그레이션 실행 (비동기, 백그라운드 fire-and-forget 안전).
  /// - 이미 완료된 사용자는 즉시 return.
  /// - 동시 실행 중인 동일 uid 호출은 중복 발사하지 않음.
  /// - 모든 결과 errors == 0 → markCompleted.
  /// - migrated == 0 이면서 skipped 만 있으면 → markCompleted (멱등성: 더 할 일 없음).
  /// - 최대 시도 횟수(_kMaxMigrationAttempts) 초과 → 강제 markCompleted
  ///   (BlueprintMigration 자체가 migrationVersion 체크로 멱등이므로 안전).
  Future<void> runIfNeeded(String uid) async {
    if (_inFlight.contains(uid)) return;
    _inFlight.add(uid);
    try {
      if (await hasCompletedMigration(uid)) {
        if (kDebugMode) {
          debugPrint('[MigrationGuard] already completed for $uid — skip.');
        }
        return;
      }
      final attempts = await _readAttempts(uid);
      if (attempts >= _kMaxMigrationAttempts) {
        // 영구 실패 루프 차단 — 강제 완료 마킹.
        // migration 자체는 멱등이므로 어드민이 수동으로 다시 돌릴 수 있음.
        if (kDebugMode) {
          debugPrint(
              '[MigrationGuard] attempts $attempts >= $_kMaxMigrationAttempts — force mark completed.');
        }
        await markCompleted(uid);
        return;
      }
      if (kDebugMode) {
        debugPrint(
            '[MigrationGuard] starting auto migration for $uid (attempt ${attempts + 1})');
      }
      await _bumpAttempts(uid, attempts);
      final migration = BlueprintMigration(uid: uid, db: _db);
      final result = await migration.migrateAll();
      final allOk = result.values.every((r) => r.errors == 0);
      final nothingMigrated =
          result.values.every((r) => r.migrated == 0 && r.errors == 0);

      if (kDebugMode) {
        result.forEach((k, v) {
          debugPrint('[MigrationGuard] $k → ${v.summary}');
          for (final m in v.errorMessages) {
            debugPrint('[MigrationGuard]   err: $m');
          }
        });
      }

      if (allOk || nothingMigrated) {
        await markCompleted(uid);
        if (kDebugMode) {
          debugPrint(
              '[MigrationGuard] completed flag saved for $uid (allOk=$allOk, nothingMigrated=$nothingMigrated)');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              '[MigrationGuard] partial failures — flag NOT saved, will retry next session.');
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MigrationGuard] runIfNeeded fatal: $e');
        debugPrint('$st');
      }
      // 실패 시 사용자 안내 없음. 다음 실행에서 멱등 재시도.
    } finally {
      _inFlight.remove(uid);
    }
  }
}

/// 전역 단일 인스턴스 — 동일 세션 내 동시 발사 차단을 위해 싱글톤.
final migrationGuardProvider = Provider<MigrationGuard>((ref) {
  return MigrationGuard();
});
