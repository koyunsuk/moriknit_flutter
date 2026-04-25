// lib/features/tools/presentation/free_timer_screen.dart
//
// 도구함 독립 뜨개 타이머 화면 (Facade).
// 도안/프로젝트/스와치 통합 누적시간 구현 전에 독립적으로 작동.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/free_timer_repository.dart';

class FreeTimerScreen extends ConsumerStatefulWidget {
  const FreeTimerScreen({super.key});

  @override
  ConsumerState<FreeTimerScreen> createState() => _FreeTimerScreenState();
}

class _FreeTimerScreenState extends ConsumerState<FreeTimerScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _liveElapsed(FreeTimerState state) {
    if (state.currentSessionStart == null) return 0;
    final diff = _now.difference(state.currentSessionStart!).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  int _displayTotal(FreeTimerState state) {
    return state.totalSeconds + _liveElapsed(state);
  }

  String _formatHms(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatSession(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggle(FreeTimerState state) async {
    final repo = ref.read(freeTimerRepositoryProvider);
    if (state.isRunning) {
      await repo.pause(_liveElapsed(state));
    } else {
      await repo.start();
    }
  }

  Future<void> _confirmReset(BuildContext context, bool isKorean) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(isKorean ? '누적시간 초기화' : 'Reset Total Time', style: T.h3),
        content: Text(
          isKorean
              ? '지금까지 누적된 시간이 모두 사라져요. 계속할까요?'
              : 'All accumulated time will be reset. Continue?',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel', style: T.body.copyWith(color: C.mu)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '초기화' : 'Reset', style: T.body.copyWith(color: C.og, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(freeTimerRepositoryProvider).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final async = ref.watch(freeTimerStreamProvider);

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '뜨개 타이머' : 'Knitting Timer',
                subtitle: isKorean ? '뜨개 시간을 누적해서 기록해요' : 'Track total knitting time',
                trailing: [
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: C.tx),
                    onSelected: (value) {
                      if (value == 'reset') _confirmReset(context, isKorean);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'reset',
                        child: Text(
                          isKorean ? '누적시간 초기화' : 'Reset Total',
                          style: T.body.copyWith(color: C.og),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                error: (e, _) => Center(
                  child: Text(
                    isKorean ? '오류: $e' : 'Error: $e',
                    style: T.caption.copyWith(color: C.og),
                  ),
                ),
                data: (state) => _buildBody(state, isKorean),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTimerName(FreeTimerState state, bool isKorean) async {
    final ctrl = TextEditingController(text: state.timerName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(isKorean ? '타이머 이름' : 'Timer Name', style: T.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isKorean ? '예: 자유 타이머 2026-04-25 14:30' : 'e.g. Free Timer ...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKorean ? '취소' : 'Cancel', style: T.body.copyWith(color: C.mu)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(isKorean ? '저장' : 'Save', style: T.body.copyWith(color: C.lvD, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(freeTimerRepositoryProvider).updateTimerName(result);
    }
  }

  Widget _buildBody(FreeTimerState state, bool isKorean) {
    final total = _displayTotal(state);
    final session = _liveElapsed(state);
    final running = state.isRunning;
    final timerName = state.timerName ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // 이슈 #649 Phase 1 — 타이머 이름 (탭하여 편집)
          GestureDetector(
            onTap: () => _editTimerName(state, isKorean),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: C.gx,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.bd),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 16, color: C.mu),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timerName.isEmpty
                          ? (isKorean ? '타이머 이름 (시작하면 자동 생성)' : 'Timer name (auto-set on start)')
                          : timerName,
                      style: T.body.copyWith(
                        color: timerName.isEmpty ? C.mu : C.tx,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 누적시간 라벨
          Text(
            isKorean ? '총 누적시간' : 'Total Accumulated',
            style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          // 대형 누적시간 표시
          Text(
            _formatHms(total),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: C.tx,
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // 현재 세션
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: running ? C.lvL : C.gx,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: running ? C.lv : C.bd,
                width: running ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      running ? Icons.timer_rounded : Icons.timer_outlined,
                      color: running ? C.lvD : C.mu,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isKorean ? '이번 세션' : 'Current Session',
                      style: T.body.copyWith(
                        color: running ? C.lvD : C.mu,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatSession(session),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: running ? C.lvD : C.mu,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // 시작/정지 대형 버튼
          SizedBox(
            height: 64,
            child: ElevatedButton.icon(
              onPressed: () => _toggle(state),
              icon: Icon(
                running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 28,
              ),
              label: Text(
                running
                    ? (isKorean ? '정지' : 'Pause')
                    : (isKorean ? '시작' : 'Start'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: running ? C.og : C.lv,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 안내 문구
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: C.mu, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isKorean
                        ? '도안에 연결된 타이머는 도안 뷰어에서 ⏱️ 아이콘을 탭해서 사용하세요. 이곳은 도안과 무관한 전체 뜨개 시간을 쌓아두는 공간이에요.'
                        : 'For pattern-linked timer, tap the ⏱️ icon in the pattern viewer. This timer accumulates total knitting time independent of patterns.',
                    style: T.caption.copyWith(color: C.mu, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
