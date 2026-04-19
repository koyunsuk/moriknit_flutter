import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import 'landing_top_bar.dart';

// ── 최근 가입자 스트림 ─────────────────────────────────────────────────────────
final landingRecentUsersProvider = StreamProvider<List<String>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(8)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final name = (doc.data()['displayName'] as String?)?.trim() ?? '';
            return name.isNotEmpty ? name : '새 메이커';
          }).toList());
});

// ── 활동 스트립 ─────────────────────────────────────────────────────────────────
class LandingActivityStrip extends ConsumerStatefulWidget {
  const LandingActivityStrip({super.key});

  @override
  ConsumerState<LandingActivityStrip> createState() =>
      _LandingActivityStripState();
}

class _LandingActivityStripState extends ConsumerState<LandingActivityStrip> {
  int _index = 0;
  Timer? _timer;
  static const _fallback = ['뜨개 메이커', '새 메이커', '아리뜨개', '코바늘러', '대바늘장인'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(landingRecentUsersProvider);
    final names = usersAsync.valueOrNull ?? _fallback;
    final items = [
      ...names.map((n) => '✨ $n님이 모리니트에 합류했어요!'),
      '🧶 오늘도 뜨개를 사랑하는 메이커들이 함께해요',
      '📁 새 프로젝트를 시작하고 기록해 보세요',
    ];
    final current = items.isEmpty ? '' : items[_index % items.length];

    return Container(
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [C.lv.withValues(alpha: 0.10), C.pk.withValues(alpha: 0.08)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border:
            Border(bottom: BorderSide(color: C.lv.withValues(alpha: 0.12))),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            current,
            key: ValueKey(current),
            style: TextStyle(
                fontSize: 12, color: C.lvD, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// ── 프로모 배너 ─────────────────────────────────────────────────────────────────
class LandingPromoBanner extends ConsumerWidget {
  const LandingPromoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user != null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go('/signup?source=promo'),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [C.pk, C.pkD],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉 지금 가입하면 3개월 Pro 무료 사용!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('무료로 시작하기',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 공통 헤더 (TopBar + 활동스트립 + 프로모배너) ──────────────────────────────
class LandingHeader extends StatelessWidget {
  const LandingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LandingActivityStrip(),
        LandingTopBar(),
        LandingPromoBanner(),
      ],
    );
  }
}
