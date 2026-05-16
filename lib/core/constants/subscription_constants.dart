// lib/core/constants/subscription_constants.dart

class SubscriptionConstants {
  // ── Free 플랜 한도 ─────────────────────────────────────────
  static const int maxFreeSwatches = 5;
  static const int maxFreeProjects = 3;
  static const int maxFreeCounters = 1;
  static const int maxFreePostsPerMonth = 5;
  static const int maxFreeEditorSaves = 0;
  // 이슈 #754 — Free 플랜 월간 AI 변환 횟수.
  static const int maxFreeAiConversionPerMonth = 3;
  // 이슈 #754 — Free 플랜 스토리지 추정 한도 (100MB = 100 * 1024 * 1024 bytes).
  static const int maxFreeStorageBytes = 100 * 1024 * 1024;

  // ── Starter 플랜 한도 ──────────────────────────────────────
  static const int maxStarterEditorSaves = 10;

  // ── 플랜 ID ────────────────────────────────────────────────
  static const String planFree = 'free';
  static const String planStarter = 'starter';
  static const String planPro = 'pro';
  static const String planBusiness = 'business';

  // ── 구독 상태 ──────────────────────────────────────────────
  static const String statusActive = 'active';
  static const String statusCancelled = 'cancelled';
  static const String statusExpired = 'expired';
  static const String statusTrial = 'trial';

  // ── Hive Box 이름 ──────────────────────────────────────────
  static const String boxSwatches = 'swatches';
  static const String boxProjects = 'projects';
  static const String boxCounters = 'counters';
  static const String boxNeedles = 'needles';
  static const String boxSyncQueue = 'sync_queue';
  static const String boxUser = 'user';
  static const String boxViewerState = 'viewer_state';

  // ── #685 영속 캐시 Box ────────────────────────────────────
  static const String boxCacheKnitSymbols = 'cache_knit_symbols';
  static const String boxCacheEncyclopedia = 'cache_encyclopedia';
  static const String boxCachePatternCharts = 'cache_pattern_charts';

  // ── 심볼 SVG 본문 영속 캐시 (오프라인 도안에디터 보장) ─────
  // 키: symbolId 또는 URL hash, 값: { 'svg': '<svg ...>...', 'fetchedAt': ms }
  static const String boxKnitSymbolSvgCache = 'knit_symbol_svg_cache';

  // 홈 즐겨찾기 — 사용자가 별표한 화면 카드 목록.
  // 키: screenId, 값: { title, iconCode, path, accent(int color), addedAt(ms) }
  static const String boxFavorites = 'favorites';

  // ── #704 Phase A-B: PatternSession Hive 폴백 캐시 ─────────
  static const String boxPatternSessionHiveCache = 'pattern_session_hive_cache';

  // ── #704 Phase 2: StepBlueprint Hive 폴백 캐시 ────────────
  // "종이 도안 대체성" — 오프라인에서 단계가 안 보이면 카운터/타이머 무의미.
  static const String boxStepBlueprintsHiveCache = 'step_blueprints_hive_cache';
  static const String boxStepBlueprintUnitsHiveCache =
      'step_blueprint_units_hive_cache';

  // ── Sync ───────────────────────────────────────────────────
  static const int syncIntervalMinutes = 30;
}
