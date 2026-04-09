// lib/core/services/sync_service.dart

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../core/constants/subscription_constants.dart';
import '../../features/ravelry/data/ravelry_auth_provider.dart';
import '../../features/swatch/data/swatch_repository.dart';
import '../../features/project/data/project_repository.dart';
import '../../features/counter/data/counter_repository.dart';
import '../../features/my/data/needle_repository.dart';

// ── Sync 서비스 ──────────────────────────────────────────────
// 30분마다 + 포그라운드 진입 시 dirty 항목 Firestore sync
class SyncService with WidgetsBindingObserver {
  Timer? _timer;

  final SwatchRepository _swatchRepo;
  final ProjectRepository _projectRepo;
  final CounterRepository _counterRepo;
  final NeedleRepository _needleRepo;
  final RavelryAuthNotifier? _ravelryAuthNotifier;

  SyncService({
    required SwatchRepository swatchRepo,
    required ProjectRepository projectRepo,
    required CounterRepository counterRepo,
    required NeedleRepository needleRepo,
    RavelryAuthNotifier? ravelryAuthNotifier,
  })  : _swatchRepo = swatchRepo,
        _projectRepo = projectRepo,
        _counterRepo = counterRepo,
        _needleRepo = needleRepo,
        _ravelryAuthNotifier = ravelryAuthNotifier;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(minutes: SubscriptionConstants.syncIntervalMinutes),
      (_) => syncAll(),
    );
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncAll();
      // 포그라운드 복귀 시 Ravelry 세션 재검증 — 토큰 만료 조기 감지
      _ravelryAuthNotifier?.refreshSession();
    }
  }

  Future<void> syncAll() async {
    await Future.wait([
      _swatchRepo.syncDirtySwatches().catchError((_) {}),
      _projectRepo.syncDirtyProjects().catchError((_) {}),
      _counterRepo.syncDirtyCounters().catchError((_) {}),
      _needleRepo.syncDirtyNeedles().catchError((_) {}),
    ]);
  }
}
