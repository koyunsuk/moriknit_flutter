import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'landing_scaffold.dart';

const double _svcMaxWidth = 1160.0;

class LandingServiceScreen extends ConsumerWidget {
  const LandingServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LandingScaffold(
      slivers: [
        SliverToBoxAdapter(child: _HeroSection()),
        SliverToBoxAdapter(child: _FeaturesGrid()),
        SliverToBoxAdapter(child: _SubscribeSection()),
        SliverToBoxAdapter(child: _CtaBanner()),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [C.lv.withValues(alpha: 0.08), C.pk.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _svcMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('뜨개의 모든 것을', style: T.h1.copyWith(fontSize: 48, color: C.lv)),
              Text('기록하다', style: T.h1.copyWith(fontSize: 48, color: C.pk)),
              const SizedBox(height: 20),
              Text(
                '모리니트는 뜨개 메이커를 위한 올인원 기록·도구 플랫폼입니다.\n프로젝트 기록부터 도안 변환, AI 게이지 판독까지 한 곳에서.',
                style: T.body.copyWith(fontSize: 18, color: C.tx.withValues(alpha: 0.75), height: 1.7),
              ),
              const SizedBox(height: 36),
              Wrap(
                spacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: () => context.go('/signup?source=service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('무료로 시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/pricing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.lv,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      side: BorderSide(color: C.lv),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('요금제 보기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturesGrid extends StatelessWidget {
  static const _features = [
    (Icons.folder_open_rounded, '프로젝트 기록', '진행 중인 뜨개를 단계별로 기록하고 사진과 함께 관리해요.'),
    (Icons.colorize_rounded, '스와치 보관함', '게이지 스와치를 보관하고 실/바늘 정보를 함께 저장해요.'),
    (Icons.auto_stories_rounded, '도안 변환', '텍스트 도안을 구조화해서 단계별로 읽기 쉽게 변환해요.'),
    (Icons.straighten_rounded, '게이지 계산기', '내 게이지에 맞는 콧수를 자동으로 계산해 드려요.'),
    (Icons.menu_book_rounded, '뜨개백과', '뜨개 용어와 기법을 한국어·영어로 검색할 수 있어요.'),
    (Icons.psychology_rounded, 'AI 도안 판독', '도안 이미지를 AI가 분석해 편집 가능한 단계로 변환해요.'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cols = width > 900 ? 3 : width > 600 ? 2 : 1;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _svcMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('모리니트가 제공하는 기능', style: T.h2.copyWith(fontSize: 32)),
              const SizedBox(height: 8),
              Text('뜨개 메이커에게 꼭 필요한 도구를 모았어요.', style: T.body.copyWith(color: C.mu)),
              const SizedBox(height: 40),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.5,
                children: _features.map((f) => _FeatureCard(icon: f.$1, title: f.$2, desc: f.$3)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.desc});
  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.bd),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: C.lv, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: T.bodyBold.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(child: Text(desc, style: T.body.copyWith(color: C.mu, fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }
}

class _SubscribeSection extends StatefulWidget {
  @override
  State<_SubscribeSection> createState() => _SubscribeSectionState();
}

class _SubscribeSectionState extends State<_SubscribeSection> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    final email = _ctrl.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('landing_subscriptions').add({
        'email': email,
        'subscribedAt': DateTime.now().toIso8601String(),
        'source': 'service_page',
      });
      if (mounted) setState(() { _done = true; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      color: const Color(0xFFF3F0FF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Text('무료 뜨개 정보 구독', style: T.h2.copyWith(fontSize: 28)),
              const SizedBox(height: 10),
              Text('뜨개백과 업데이트, 클라스 소식을 이메일로 받아보세요.', style: T.body.copyWith(color: C.mu)),
              const SizedBox(height: 28),
              if (_done)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                  child: Text('✅ 구독 완료! 소식을 보내드릴게요.', style: T.bodyBold.copyWith(color: C.lv)),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: '이메일 주소 입력',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _loading ? null : _subscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.lv,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('구독하기', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CtaBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [C.lv, C.pk], begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
      child: Center(
        child: Column(
          children: [
            const Text('지금 무료로 시작해보세요', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 12),
            const Text('모든 기능을 무료로 체험할 수 있어요.', style: TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/signup?source=service-cta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: C.lv,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('무료 가입하기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
