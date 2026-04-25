// lib/features/swatch/presentation/swatch_timer_screen.dart
//
// 스와치별 작업 시간 타이머 (이슈 #630).
// free_timer_screen 구조 공유 — 독립 타이머와 동일한 UX.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/swatch_timer_repository.dart';

class SwatchTimerScreen extends ConsumerStatefulWidget {
  final String swatchId;
  final String swatchName;

  const SwatchTimerScreen({
    super.key,
    required this.swatchId,
    required this.swatchName,
  });

  @override
  ConsumerState<SwatchTimerScreen> createState() => _SwatchTimerScreenState();
}

class _SwatchTimerScreenState extends ConsumerState<SwatchTimerScreen> {
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

  int _liveElapsed(SwatchTimerState state) {
    if (state.currentSessionStart == null) return 0;
    final diff = _now.difference(state.currentSessionStart!).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  int _displayTotal(SwatchTimerState state) {
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

  Future<void> _toggle(SwatchTimerState state) async {
    final repo = ref.read(swatchTimerRepositoryProvider);
    if (state.isRunning) {
      await repo.pause(widget.swatchId, _liveElapsed(state));
    } else {
      await repo.start(widget.swatchId);
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
              ? '이 스와치의 누적 시간이 모두 사라져요. 계속할까요?'
              : "This swatch's total time will be reset. Continue?",
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
      await ref.read(swatchTimerRepositoryProvider).reset(widget.swatchId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final async = ref.watch(swatchTimerStreamProvider(widget.swatchId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.swatchName.isEmpty
              ? (isKorean ? '스와치 타이머' : 'Swatch Timer')
              : widget.swatchName,
          style: T.h3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
      body: SafeArea(
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
    );
  }

  Widget _buildBody(SwatchTimerState state, bool isKorean) {
    final total = _displayTotal(state);
    final session = _liveElapsed(state);
    final running = state.isRunning;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            isKorean ? '이 스와치 누적시간' : 'Swatch Total Time',
            style: T.caption.copyWith(color: C.mu, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
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
                        ? '1작 완성은 스와치부터 시작이에요. 이 타이머로 스와치 작업 시간을 기록하면, 연결된 프로젝트의 전체 작업시간에 자동으로 합산됩니다.'
                        : 'Projects start with a swatch. Time tracked here is automatically added to linked project totals.',
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
