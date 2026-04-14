import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'landing_scaffold.dart';

const double _landingMaxWidth = 1160;
const Color _landingBg = kLandingBg;

class LandingPricingScreen extends StatelessWidget {
  const LandingPricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LandingScaffold(
      slivers: [
        SliverToBoxAdapter(child: _HeroSection()),
        SliverToBoxAdapter(child: _PlanCardsSection()),
        SliverToBoxAdapter(child: _FaqSection()),
        SliverToBoxAdapter(child: _CtaSection()),
      ],
    );
  }
}

// ── 히어로 ────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '✨ 심플한 요금제',
                  style: TextStyle(
                      color: Color(0xFFDDD6FE),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '요금제',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                '모리니트는 무료로 충분히 즐길 수 있어요.\n프로·비즈니스 플랜으로 판매까지 경험해보세요.',
                style: TextStyle(
                  color: Color(0xFFB0A8D8),
                  fontSize: 17,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 플랜 카드 ─────────────────────────────────────────────────────────────────

class _PlanCardsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Container(
      color: _landingBg,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: isMobile
              ? Column(
                  children: [
                    _FreePlanCard(),
                    const SizedBox(height: 20),
                    _ProPlanCard(),
                    const SizedBox(height: 20),
                    _BusinessPlanCard(),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _FreePlanCard()),
                      const SizedBox(width: 20),
                      Expanded(child: _ProPlanCard()),
                      const SizedBox(width: 20),
                      Expanded(child: _BusinessPlanCard()),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;
  final Color checkColor;
  final bool dark;

  const _FeatureItem({
    required this.text,
    required this.checkColor,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: checkColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: dark ? const Color(0xFFDDD6FE) : const Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreePlanCard extends StatelessWidget {
  static const _features = [
    '프로젝트 기록 (최대 5개)',
    '스와치 기록 (최대 10개)',
    '게이지 계산기',
    '커뮤니티 게시판',
    '공지사항 열람',
    '뜨개 도구 관리',
    '앱 테마 기본 제공',
  ];

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '무료 플랜',
              style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '₩0',
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B4B)),
          ),
          const SizedBox(height: 4),
          const Text('영구 무료',
              style:
                  TextStyle(fontSize: 14, color: Color(0xFF7C5CBF))),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFEEE8FF)),
          const SizedBox(height: 20),
          ..._features.map(
              (f) => _FeatureItem(text: f, checkColor: accentColor)),
        ],
      ),
    );
  }
}

class _ProPlanCard extends StatelessWidget {
  static const _features = [
    '프로젝트·스와치 무제한',
    'AI 게이지 판독기',
    '도안 에디터 마켓 판매',
    '단계로그 상품 구성 (필수)',
    '우선 고객 지원',
    '앱 프리미엄 테마',
    '광고 없는 경험',
    '베타 기능 조기 접근',
  ];

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFEC4899);
    const goldColor = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF2D1B4E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.20),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '프로 플랜',
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: goldColor.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  '준비 중',
                  style: TextStyle(
                      color: goldColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '₩9,900',
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text('/ 월',
              style:
                  TextStyle(fontSize: 14, color: Color(0xFFB0A8D8))),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 20),
          ..._features.map((f) => _FeatureItem(
                text: f,
                checkColor: accentColor,
                dark: true,
              )),
        ],
      ),
    );
  }
}

class _BusinessPlanCard extends StatelessWidget {
  static const _features = [
    '프로 플랜 기능 전체 포함',
    '도안 에디터 마켓 판매',
    'PDF 도안 마켓 판매 (추가)',
    '단계로그 상품 구성 (필수)',
    '수익 분석 대시보드 (예정)',
    '전담 고객 지원',
  ];

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF7C3AED);
    const goldColor = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B4E), Color(0xFF1A1A2E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '비즈니스 플랜',
                  style: TextStyle(
                      color: Color(0xFFDDD6FE),
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: goldColor.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  '준비 중',
                  style: TextStyle(
                      color: goldColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '₩19,900',
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text('/ 월',
              style:
                  TextStyle(fontSize: 14, color: Color(0xFFB0A8D8))),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 20),
          ..._features.map((f) => _FeatureItem(
                text: f,
                checkColor: const Color(0xFFA78BFA),
                dark: true,
              )),
        ],
      ),
    );
  }
}

// ── FAQ ───────────────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  static const _faqs = [
    (
      q: '무료에서 프로로 전환하면 데이터가 유지되나요?',
      a: '네, 물론이에요. 무료 플랜에서 기록한 모든 프로젝트, 스와치, 메모는 프로 플랜으로 전환 후에도 그대로 유지됩니다.',
    ),
    (
      q: '프로·비즈니스 플랜은 언제 출시되나요?',
      a: '현재 열심히 준비 중이에요! 출시 시 앱 내 공지 및 이메일로 먼저 알려드릴게요. 지금 무료로 시작하시면 혜택을 누구보다 빠르게 받으실 수 있어요.',
    ),
    (
      q: '구독을 중간에 해지할 수 있나요?',
      a: '네, 언제든지 해지할 수 있어요. 해지 후에는 남은 구독 기간 동안 프로 기능을 계속 사용할 수 있으며, 기간이 끝나면 무료 플랜으로 자동 전환됩니다.',
    ),
    (
      q: 'AI 게이지 판독기는 어떻게 동작하나요?',
      a: '뜨개 스와치 사진을 찍으면 AI가 게이지(10cm당 코수, 단수)를 자동으로 분석해줘요. 직접 세지 않아도 정확한 게이지 정보를 바로 얻을 수 있습니다.',
    ),
    (
      q: '비즈니스 플랜에서 PDF 도안 판매는 어떻게 하나요?',
      a: '내가 직접 제작한 PDF 도안을 모리니트 마켓에 등록할 수 있어요. 단계로그(단계별 가이드)를 필수로 구성해야 하며, 관리자 승인 후 공개됩니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0FF),
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              const Text(
                '자주 묻는 질문',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1B4B)),
              ),
              const SizedBox(height: 8),
              const Text(
                '궁금한 점이 있으시면 언제든지 문의해 주세요.',
                style: TextStyle(
                    fontSize: 15, color: Color(0xFF7C5CBF)),
              ),
              const SizedBox(height: 40),
              ..._faqs.map(
                  (e) => _FaqItem(question: e.q, answer: e.a)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFDDD6FE).withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1B4B)),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                Text(
                  widget.answer,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF4C3D8A)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── CTA ───────────────────────────────────────────────────────────────────────

class _CtaSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _landingBg,
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _landingMaxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text(
                  '지금 바로 시작해보세요',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  '신용카드 없이 무료로 시작할 수 있어요.',
                  style:
                      TextStyle(color: Color(0xFFEDE9FE), fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    elevation: 0,
                  ),
                  child: const Text('지금 무료로 시작하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

