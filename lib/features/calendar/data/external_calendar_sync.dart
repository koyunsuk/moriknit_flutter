import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/knitting_event.dart';
import 'google_calendar_service.dart';
import 'knitting_event_repository.dart';

/// 양방향 Google Calendar 동기화 오케스트레이터
/// #885 외부 캘린더 연동
class ExternalCalendarSync {
  final GoogleCalendarService _gcal;
  final KnittingEventRepository _repo;

  ExternalCalendarSync(this._gcal, this._repo);

  // ── 진입점 ───────────────────────────────────────────────────────────────────

  /// 로컬 ↔ Google Calendar 양방향 동기화를 수행합니다.
  ///
  /// 1. 로컬 이벤트 → GCal push (gcalEventId 없는 이벤트)
  /// 2. GCal 이벤트 → 로컬 pull (로컬에 없는 moriknit 이벤트)
  /// 3. 충돌 해소: lastSyncedAt 기준 최신 데이터 우선
  ///
  /// 반환값: 동기화 결과 요약 (pushed, pulled, skipped 건수)
  Future<SyncResult> syncGoogleCalendar(String userId) async {
    if (!_gcal.isSignedIn) {
      return const SyncResult(error: '구글 캘린더 로그인이 필요합니다.');
    }

    int pushed = 0;
    int pulled = 0;
    int skipped = 0;

    try {
      // ── 1단계: 로컬 → GCal push ─────────────────────────────────────────────
      final localEvents = await _fetchAllLocalEvents(userId);
      final now = DateTime.now();

      for (final event in localEvents) {
        try {
          final gcalId = await _gcal.pushEvent(event);
          if (gcalId != null) {
            // gcalEventId와 lastSyncedAt 저장
            final updated = event.copyWith(
              gcalEventId: gcalId,
              lastSyncedAt: now,
            );
            await _repo.save(updated);
            pushed++;
          } else {
            skipped++;
          }
        } catch (_) {
          skipped++;
        }
      }

      // ── 2단계: GCal → 로컬 pull ─────────────────────────────────────────────
      final gcalEvents = await _gcal.pullEvents();
      final localIdSet = localEvents.map((e) => e.id).toSet();
      // gcalEventId → 로컬 이벤트 맵 (충돌 해소용)
      final localByGcalId = {
        for (final e in localEvents)
          if (e.gcalEventId != null) e.gcalEventId!: e,
      };

      for (final gcalEvent in gcalEvents) {
        try {
          final props = _gcal.extractPrivateProps(gcalEvent);
          final moriknitId = props['moriknit_id'];
          final gcalEventId = gcalEvent['id'] as String?;

          // 로컬에 이미 존재하는 이벤트인지 확인
          final existsById = moriknitId != null && localIdSet.contains(moriknitId);
          final existsByGcalId =
              gcalEventId != null && localByGcalId.containsKey(gcalEventId);

          if (existsById || existsByGcalId) {
            // 충돌 해소: lastSyncedAt 기준 최신 우선
            final local = existsById
                ? localEvents.firstWhere((e) => e.id == moriknitId)
                : localByGcalId[gcalEventId]!;

            final gcalUpdated = _parseGCalUpdated(gcalEvent);
            final localSynced = local.lastSyncedAt;

            if (gcalUpdated != null &&
                (localSynced == null ||
                    gcalUpdated.isAfter(localSynced))) {
              // GCal이 더 최신 → 로컬 업데이트
              final merged = _mergeFromGCal(local, gcalEvent, gcalEventId);
              if (merged != null) {
                await _repo.save(merged);
                pulled++;
              }
            } else {
              skipped++;
            }
            continue;
          }

          // 로컬에 없는 새 이벤트 → 로컬 생성
          final newEvent = _buildFromGCal(userId, gcalEvent, props, gcalEventId);
          if (newEvent != null) {
            await _repo.save(newEvent);
            pulled++;
          } else {
            skipped++;
          }
        } catch (_) {
          skipped++;
        }
      }

      return SyncResult(pushed: pushed, pulled: pulled, skipped: skipped);
    } catch (e) {
      return SyncResult(
        pushed: pushed,
        pulled: pulled,
        skipped: skipped,
        error: '$e',
      );
    }
  }

  /// 로컬 이벤트를 GCal에서 삭제하고 로컬의 gcalEventId도 초기화합니다.
  Future<void> deleteFromGCal(KnittingEvent event) async {
    if (event.gcalEventId == null || event.gcalEventId!.isEmpty) return;
    await _gcal.deleteEvent(event.gcalEventId!);
    await _repo.save(event.copyWith(gcalEventId: ''));
  }

  // ── 내부 헬퍼 ────────────────────────────────────────────────────────────────

  Future<List<KnittingEvent>> _fetchAllLocalEvents(String userId) async {
    // watchAll()은 Stream이므로 first로 현재 목록 스냅샷
    return _repo.watchAll().first;
  }

  /// GCal 이벤트의 updatedTime 파싱
  DateTime? _parseGCalUpdated(Map<String, dynamic> gcalEvent) {
    try {
      final updated = gcalEvent['updated'] as String?;
      if (updated == null) return null;
      return DateTime.tryParse(updated);
    } catch (_) {
      return null;
    }
  }

  /// GCal 데이터로 기존 로컬 이벤트를 업데이트합니다 (충돌 해소: GCal 우선)
  KnittingEvent? _mergeFromGCal(
    KnittingEvent local,
    Map<String, dynamic> gcalEvent,
    String? gcalEventId,
  ) {
    try {
      final summary = gcalEvent['summary'] as String? ?? '';
      // summary 형식: "🧶 [MoriKnit] 제목" → 제목만 추출
      final title = _extractTitle(summary);
      final description = gcalEvent['description'] as String? ?? '';
      final note = _extractNote(description);
      final date = _gcal.extractDate(gcalEvent);

      return local.copyWith(
        title: title.isNotEmpty ? title : local.title,
        note: note,
        date: date ?? local.date,
        gcalEventId: gcalEventId ?? local.gcalEventId,
        lastSyncedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// GCal 이벤트로부터 새 KnittingEvent를 생성합니다
  KnittingEvent? _buildFromGCal(
    String userId,
    Map<String, dynamic> gcalEvent,
    Map<String, String> props,
    String? gcalEventId,
  ) {
    try {
      final summary = gcalEvent['summary'] as String? ?? '';
      final title = _extractTitle(summary);
      if (title.isEmpty) return null;

      final description = gcalEvent['description'] as String? ?? '';
      final note = _extractNote(description);
      final date = _gcal.extractDate(gcalEvent) ?? DateTime.now();
      final typeStr = props['moriknit_type'] ?? 'memo';
      final type = knittingEventTypeFromValue(typeStr);
      final id = props['moriknit_id'] ??
          FirebaseFirestore.instance.collection('_').doc().id;

      return KnittingEvent(
        id: id,
        userId: userId,
        type: type,
        title: title,
        note: note,
        date: date,
        createdAt: DateTime.now(),
        gcalEventId: gcalEventId,
        lastSyncedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// "🧶 [MoriKnit] 제목" → "제목" 추출
  String _extractTitle(String summary) {
    final marker = '[MoriKnit] ';
    final idx = summary.indexOf(marker);
    if (idx < 0) return summary.trim();
    return summary.substring(idx + marker.length).trim();
  }

  /// description에서 노트 부분만 추출 ("#moriknit #type" 태그 제거)
  String _extractNote(String description) {
    final lines = description.split('\n');
    final noteLines = lines.where((l) {
      final trimmed = l.trim();
      if (trimmed.isEmpty) return false;
      if (trimmed.startsWith('#moriknit') || trimmed.startsWith('#')) {
        return false;
      }
      return true;
    }).toList();
    return noteLines.join('\n').trim();
  }
}

// ── 결과 모델 ────────────────────────────────────────────────────────────────

class SyncResult {
  final int pushed;
  final int pulled;
  final int skipped;
  final String? error;

  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.skipped = 0,
    this.error,
  });

  bool get isSuccess => error == null;

  @override
  String toString() =>
      'SyncResult(pushed=$pushed, pulled=$pulled, skipped=$skipped, error=$error)';
}

// ── Providers ────────────────────────────────────────────────────────────────

final externalCalendarSyncProvider = Provider<ExternalCalendarSync>((ref) {
  final gcal = ref.watch(googleCalendarServiceProvider);
  final repo = ref.watch(knittingEventRepositoryProvider);
  return ExternalCalendarSync(gcal, repo);
});
