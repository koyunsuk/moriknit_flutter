// 이슈 — 랜딩 CMS Repository.
//
// 3-Layer Fallback:
//   1) Firestore landing_pages/{pageId}  (실시간 stream)
//   2) Hive 'landing_cms_cache' box     (5분 TTL — 오프라인/초기렌더)
//   3) 호출자가 코드 fallback 위젯 사용  (CmsAwareWrapper에서 처리)
//
// 어드민(write) 동작은 Firestore에 직접 기록. 캐시는 read 안정성용.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../domain/landing_page.dart';

class LandingCmsRepository {
  static const _collection = 'landing_pages';
  static const _boxName = 'landing_cms_cache';
  static const Duration _cacheTtl = Duration(minutes: 5);

  final FirebaseFirestore _db;

  LandingCmsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Hive cache helpers ────────────────────────────────────────────────────
  Future<Box<Map>?> _openBox() async {
    if (kIsWeb) return null; // 웹은 Hive Path 미사용 — 캐시 스킵.
    try {
      return await Hive.openBox<Map>(_boxName);
    } catch (_) {
      return null;
    }
  }

  Future<LandingPage?> _readCache(String pageId) async {
    final box = await _openBox();
    if (box == null) return null;
    try {
      final raw = box.get(pageId);
      if (raw == null) return null;
      final cachedAt = raw['cachedAt'];
      if (cachedAt is int) {
        final ts = DateTime.fromMillisecondsSinceEpoch(cachedAt);
        if (DateTime.now().difference(ts) > _cacheTtl) {
          // TTL 만료 — 캐시 항목 유지(완전 무효화 X). 호출자가 신규 데이터를 받으면 덮어씀.
          // 오프라인 시 stale fallback 가능.
        }
      }
      final pageRaw = raw['page'];
      if (pageRaw is Map) {
        return LandingPage.fromMap(pageId, pageRaw);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(LandingPage page) async {
    final box = await _openBox();
    if (box == null) return;
    try {
      await box.put(page.id, {
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'page': page.toMap(),
      });
    } catch (_) {
      // 캐시 실패는 무시.
    }
  }

  // ── Firestore reads ───────────────────────────────────────────────────────

  /// 페이지 단건 stream. Firestore 데이터가 있으면 그것을 반환,
  /// 첫 emit 전까지 Hive 캐시가 있으면 캐시값을 즉시 emit (off-line 첫 그림).
  Stream<LandingPage?> watchPage(String pageId) {
    final controller = StreamController<LandingPage?>();
    bool cacheEmitted = false;
    bool firestoreEmitted = false;

    // 캐시 선반환.
    _readCache(pageId).then((cached) {
      if (!firestoreEmitted && cached != null && !controller.isClosed) {
        cacheEmitted = true;
        controller.add(cached);
      }
    });

    final sub = _db.collection(_collection).doc(pageId).snapshots().listen(
      (snap) {
        firestoreEmitted = true;
        if (!snap.exists) {
          // Firestore 데이터 없음 — null 반환 (호출자 fallback).
          if (controller.isClosed) return;
          controller.add(null);
          return;
        }
        final data = snap.data();
        if (data == null) {
          if (controller.isClosed) return;
          controller.add(null);
          return;
        }
        final page = LandingPage.fromMap(pageId, data);
        if (!controller.isClosed) controller.add(page);
        _writeCache(page);
      },
      onError: (error, stack) {
        // Firestore 실패 — 캐시 시도 후 null fallback.
        if (!cacheEmitted) {
          _readCache(pageId).then((cached) {
            if (!controller.isClosed) controller.add(cached);
          });
        }
      },
    );

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// 페이지 1회성 fetch (관리자 편집기 초기 로드용).
  Future<LandingPage?> fetchPage(String pageId) async {
    try {
      final snap = await _db.collection(_collection).doc(pageId).get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final page = LandingPage.fromMap(pageId, data);
      _writeCache(page);
      return page;
    } catch (_) {
      return _readCache(pageId);
    }
  }

  /// 모든 페이지 목록(어드민용).
  Future<List<LandingPage>> listPages() async {
    try {
      final snap = await _db.collection(_collection).get();
      return snap.docs
          .map((d) => LandingPage.fromMap(d.id, d.data()))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  // ── Firestore writes ──────────────────────────────────────────────────────

  /// 페이지 저장(merge=false — 전체 덮어쓰기). 저장과 동시에 캐시 갱신.
  Future<void> savePage(LandingPage page) async {
    await _db.collection(_collection).doc(page.id).set(page.toFirestore());
    await _writeCache(page.copyWith(updatedAt: DateTime.now()));
  }

  /// 발행: status='published'
  Future<void> publishPage(String pageId) async {
    await _db.collection(_collection).doc(pageId).set({
      'status': PublishStatus.published.raw,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 초안 되돌리기: status='draft'
  Future<void> revertToDraft(String pageId) async {
    await _db.collection(_collection).doc(pageId).set({
      'status': PublishStatus.draft.raw,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

// ── Riverpod providers ──────────────────────────────────────────────────────

final landingCmsRepositoryProvider = Provider<LandingCmsRepository>((ref) {
  return LandingCmsRepository();
});

/// 페이지 stream provider (UI에서 ref.watch).
final landingCmsPageProvider =
    StreamProvider.family<LandingPage?, String>((ref, pageId) {
  final repo = ref.watch(landingCmsRepositoryProvider);
  return repo.watchPage(pageId);
});

/// 어드민 페이지 목록 provider.
final landingCmsPageListProvider = FutureProvider<List<LandingPage>>((ref) {
  final repo = ref.watch(landingCmsRepositoryProvider);
  return repo.listPages();
});
