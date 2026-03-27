// lib/core/constants/subscription_constants.dart

class SubscriptionConstants {
  // ── Free 플랜 한도 ─────────────────────────────────────────
  static const int maxFreeSwatches = 5;
  static const int maxFreeProjects = 3;
  static const int maxFreeCounters = 1;
  static const int maxFreePostsPerMonth = 5;
  static const int maxFreeEditorSaves = 0;

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

  // ── Sync ───────────────────────────────────────────────────
  static const int syncIntervalMinutes = 30;
}
