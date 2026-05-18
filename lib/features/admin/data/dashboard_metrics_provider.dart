// 이슈 #814 — 어드민 대시보드 풍부화: 지표 데이터 수집 Provider 모음.
//
// 핵심 원칙:
// 1. 모든 Provider는 실패 시 null 또는 빈 값을 반환 (절대 throw 금지).
// 2. 데이터 소스가 없는 지표(Hosting/Storage/AI 토큰 등)는 항상 null 반환 — UI가
//    플레이스홀더로 처리한다.
// 3. Cloud Functions 연동이 필요한 지표는 향후 Functions에서 집계 결과를
//    `app_config/dashboard_metrics` 문서 등에 적재하면 자동으로 표시되도록
//    fallback 경로를 마련.
//
// 데이터 클래스는 immutable. 화면에서는 `.when(loading/error/data)` 사용.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── 공통 도우미 ───────────────────────────────────────────────────────────────

DateTime _daysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
}

DateTime? _readTimestamp(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  return null;
}

num? _readNum(Object? raw) {
  if (raw is num) return raw;
  if (raw is String) return num.tryParse(raw);
  return null;
}

/// 모든 지표 Provider 공통 fallback. 어떤 예외든 null/zero 로 흡수.
Future<T?> _safe<T>(Future<T> Function() task, {String? tag}) async {
  try {
    return await task();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[dashboard_metrics${tag != null ? '/$tag' : ''}] $e\n$st');
    }
    return null;
  }
}

// ── 운영 지표 (Firestore 직접 카운트) ──────────────────────────────────────────

/// 미해결 버그리포트 수. 최근 500건 한도 (Firestore count 미사용으로 비용 절감).
final bugReportsCountProvider = FutureProvider<int?>((ref) async {
  return _safe<int>(() async {
    final snap = await FirebaseFirestore.instance
        .collection('bug_reports')
        .where('isResolved', isEqualTo: false)
        .limit(500)
        .get();
    return snap.size;
  }, tag: 'bugReportsCount');
});

/// 미응답 1:1 문의 수.
final inquiriesCountProvider = FutureProvider<int?>((ref) async {
  return _safe<int>(() async {
    final snap = await FirebaseFirestore.instance
        .collection('landing_boards')
        .doc('qa')
        .collection('posts')
        .where('isResolved', isEqualTo: false)
        .limit(500)
        .get();
    return snap.size;
  }, tag: 'inquiriesCount');
});

/// 미검수 도안 수 (마켓 pending + 백과 draft/submitted/pending).
final pendingPatternsCountProvider = FutureProvider<int?>((ref) async {
  return _safe<int>(() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db
          .collection('market_items')
          .where('status', isEqualTo: 'pending')
          .limit(500)
          .get(),
      db
          .collection('encyclopedia')
          .where('status', whereIn: ['draft', 'submitted', 'pending'])
          .limit(500)
          .get(),
    ]);
    return results.fold<int>(0, (acc, snap) => acc + snap.size);
  }, tag: 'pendingPatterns');
});

// ── 트래픽 지표 ───────────────────────────────────────────────────────────────

@immutable
class ActiveUsersMetric {
  final int weekly;
  final int monthly;
  const ActiveUsersMetric({required this.weekly, required this.monthly});
}

/// 7일/30일 활성 사용자.
///
/// 우선순위:
/// 1. `users.lastSeenAt` 필드가 채워져 있으면 그것으로 집계.
/// 2. 필드가 없으면 null 반환 → UI는 "데이터 수집 중" 플레이스홀더 표시.
final dailyActiveUsersProvider =
    FutureProvider<ActiveUsersMetric?>((ref) async {
  return _safe<ActiveUsersMetric?>(() async {
    final db = FirebaseFirestore.instance;
    final monthAgo = _daysAgo(30);
    final weekAgo = _daysAgo(7);
    final snap = await db
        .collection('users')
        .where('lastSeenAt', isGreaterThan: Timestamp.fromDate(monthAgo))
        .limit(2000)
        .get();
    if (snap.docs.isEmpty) {
      // lastSeenAt 필드가 한 건도 없으면 데이터 미수집 상태로 간주 → null 반환.
      return null;
    }
    int weekly = 0;
    int monthly = 0;
    for (final doc in snap.docs) {
      final dt = _readTimestamp(doc.data()['lastSeenAt']);
      if (dt == null) continue;
      monthly++;
      if (!dt.isBefore(weekAgo)) weekly++;
    }
    return ActiveUsersMetric(weekly: weekly, monthly: monthly);
  }, tag: 'dau').then((v) => v);
});

@immutable
class SignupsMetric {
  final int weekly;
  final int monthly;
  final int total;
  const SignupsMetric({
    required this.weekly,
    required this.monthly,
    required this.total,
  });
}

/// 7일/30일 신규 가입.
final newSignupsProvider = FutureProvider<SignupsMetric?>((ref) async {
  return _safe<SignupsMetric>(() async {
    final db = FirebaseFirestore.instance;
    final monthAgo = _daysAgo(30);
    final weekAgo = _daysAgo(7);
    final snap = await db
        .collection('users')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(monthAgo))
        .orderBy('createdAt', descending: true)
        .limit(2000)
        .get();
    int weekly = 0;
    for (final doc in snap.docs) {
      final dt = _readTimestamp(doc.data()['createdAt']);
      if (dt == null) continue;
      if (!dt.isBefore(weekAgo)) weekly++;
    }
    return SignupsMetric(
      weekly: weekly,
      monthly: snap.size,
      total: snap.size, // 정확한 전체 수는 Functions 집계 필요 — 최대 추정치.
    );
  }, tag: 'signups');
});

// ── 마켓 거래 지표 ────────────────────────────────────────────────────────────

@immutable
class MarketTxMetric {
  /// 거래 건수 (일/주/월).
  final int daily;
  final int weekly;
  final int monthly;

  /// 거래 금액 (일/주/월). 통화는 KRW 가정.
  final num dailyAmount;
  final num weeklyAmount;
  final num monthlyAmount;

  const MarketTxMetric({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.dailyAmount,
    required this.weeklyAmount,
    required this.monthlyAmount,
  });
}

/// 마켓 거래량: `collectionGroup('market_purchases')` 최근 30일 집계.
/// collectionGroup 인덱스 없으면 catch에서 null 반환.
final marketTransactionsProvider =
    FutureProvider<MarketTxMetric?>((ref) async {
  return _safe<MarketTxMetric>(() async {
    final db = FirebaseFirestore.instance;
    final monthAgo = _daysAgo(30);
    final weekAgo = _daysAgo(7);
    final dayAgo = _daysAgo(1);
    final snap = await db
        .collectionGroup('market_purchases')
        .where('purchasedAt', isGreaterThan: Timestamp.fromDate(monthAgo))
        .limit(2000)
        .get();
    int daily = 0, weekly = 0;
    num dailyAmount = 0, weeklyAmount = 0, monthlyAmount = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final dt = _readTimestamp(data['purchasedAt']);
      if (dt == null) continue;
      final price = _readNum(data['price']) ?? 0;
      monthlyAmount += price;
      if (!dt.isBefore(weekAgo)) {
        weekly++;
        weeklyAmount += price;
      }
      if (!dt.isBefore(dayAgo)) {
        daily++;
        dailyAmount += price;
      }
    }
    return MarketTxMetric(
      daily: daily,
      weekly: weekly,
      monthly: snap.size,
      dailyAmount: dailyAmount,
      weeklyAmount: weeklyAmount,
      monthlyAmount: monthlyAmount,
    );
  }, tag: 'marketTx');
});

// ── Firebase 인프라 지표 (Cloud Functions 집계 결과 읽기) ─────────────────────

/// Cloud Functions가 적재한 집계 문서. 없으면 null.
Future<Map<String, dynamic>?> _readMetricsDoc(String docId) async {
  return _safe<Map<String, dynamic>?>(() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc(docId)
        .get();
    final data = doc.data();
    if (data == null || data.isEmpty) return null;
    return data;
  }, tag: 'metricsDoc/$docId').then((v) => v);
}

@immutable
class FirestoreUsageMetric {
  final int? dailyReads;
  final int? dailyWrites;
  final int? dailyDeletes;
  final DateTime? collectedAt;
  const FirestoreUsageMetric({
    this.dailyReads,
    this.dailyWrites,
    this.dailyDeletes,
    this.collectedAt,
  });

  bool get hasData =>
      dailyReads != null || dailyWrites != null || dailyDeletes != null;
}

/// Firestore 일별 read/write. 집계 문서가 없거나 비면 null 반환.
final firestoreUsageProvider =
    FutureProvider<FirestoreUsageMetric?>((ref) async {
  final data = await _readMetricsDoc('firestore_usage');
  if (data == null) return null;
  return FirestoreUsageMetric(
    dailyReads: (data['dailyReads'] as num?)?.toInt(),
    dailyWrites: (data['dailyWrites'] as num?)?.toInt(),
    dailyDeletes: (data['dailyDeletes'] as num?)?.toInt(),
    collectedAt: _readTimestamp(data['collectedAt']),
  );
});

@immutable
class AiTokenMetric {
  final int? totalTokens;
  final int? promptTokens;
  final int? completionTokens;
  final int? callCount;
  final num? estimatedCost;
  final DateTime? collectedAt;
  const AiTokenMetric({
    this.totalTokens,
    this.promptTokens,
    this.completionTokens,
    this.callCount,
    this.estimatedCost,
    this.collectedAt,
  });

  bool get hasData =>
      totalTokens != null || callCount != null || estimatedCost != null;
}

/// AI 토큰 사용량.
///
/// 1순위: `ai_usage_logs` 컬렉션 최근 30일 합산.
/// 2순위: `app_config/ai_token_usage` 집계 문서 (Functions가 적재).
/// 둘 다 없으면 null.
final aiTokenUsageProvider = FutureProvider<AiTokenMetric?>((ref) async {
  // 1순위 — ai_usage_logs 컬렉션 직접 집계 시도.
  final fromLogs = await _safe<AiTokenMetric?>(() async {
    final monthAgo = _daysAgo(30);
    final snap = await FirebaseFirestore.instance
        .collection('ai_usage_logs')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(monthAgo))
        .limit(2000)
        .get();
    if (snap.docs.isEmpty) return null;
    int total = 0, prompt = 0, completion = 0;
    num cost = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      total += (_readNum(data['totalTokens']) ?? 0).toInt();
      prompt += (_readNum(data['promptTokens']) ?? 0).toInt();
      completion += (_readNum(data['completionTokens']) ?? 0).toInt();
      cost += _readNum(data['cost']) ?? 0;
    }
    return AiTokenMetric(
      totalTokens: total,
      promptTokens: prompt,
      completionTokens: completion,
      callCount: snap.size,
      estimatedCost: cost,
      collectedAt: DateTime.now(),
    );
  }, tag: 'aiTokens/logs');
  if (fromLogs != null && fromLogs.hasData) return fromLogs;

  // 2순위 — Functions 집계 문서.
  final data = await _readMetricsDoc('ai_token_usage');
  if (data == null) return null;
  return AiTokenMetric(
    totalTokens: (data['totalTokens'] as num?)?.toInt(),
    promptTokens: (data['promptTokens'] as num?)?.toInt(),
    completionTokens: (data['completionTokens'] as num?)?.toInt(),
    callCount: (data['callCount'] as num?)?.toInt(),
    estimatedCost: data['estimatedCost'] as num?,
    collectedAt: _readTimestamp(data['collectedAt']),
  );
});

@immutable
class HostingTrafficMetric {
  final int? dailyVisits;
  final int? monthlyVisits;
  final num? dailyBandwidthMb;
  final num? monthlyBandwidthMb;
  final DateTime? collectedAt;
  const HostingTrafficMetric({
    this.dailyVisits,
    this.monthlyVisits,
    this.dailyBandwidthMb,
    this.monthlyBandwidthMb,
    this.collectedAt,
  });

  bool get hasData =>
      dailyVisits != null ||
      monthlyVisits != null ||
      dailyBandwidthMb != null ||
      monthlyBandwidthMb != null;
}

/// Firebase Hosting 트래픽. 집계 문서가 없으면 null.
final hostingTrafficProvider =
    FutureProvider<HostingTrafficMetric?>((ref) async {
  final data = await _readMetricsDoc('hosting_traffic');
  if (data == null) return null;
  return HostingTrafficMetric(
    dailyVisits: (data['dailyVisits'] as num?)?.toInt(),
    monthlyVisits: (data['monthlyVisits'] as num?)?.toInt(),
    dailyBandwidthMb: data['dailyBandwidthMb'] as num?,
    monthlyBandwidthMb: data['monthlyBandwidthMb'] as num?,
    collectedAt: _readTimestamp(data['collectedAt']),
  );
});

@immutable
class StorageUsageMetric {
  final num? totalBytes;
  final num? monthlyEgressBytes;
  final int? objectCount;
  final DateTime? collectedAt;
  const StorageUsageMetric({
    this.totalBytes,
    this.monthlyEgressBytes,
    this.objectCount,
    this.collectedAt,
  });

  bool get hasData =>
      totalBytes != null || monthlyEgressBytes != null || objectCount != null;
}

/// Firebase Storage 사용량. 집계 문서가 없으면 null.
final storageUsageProvider = FutureProvider<StorageUsageMetric?>((ref) async {
  final data = await _readMetricsDoc('storage_usage');
  if (data == null) return null;
  return StorageUsageMetric(
    totalBytes: data['totalBytes'] as num?,
    monthlyEgressBytes: data['monthlyEgressBytes'] as num?,
    objectCount: (data['objectCount'] as num?)?.toInt(),
    collectedAt: _readTimestamp(data['collectedAt']),
  );
});
