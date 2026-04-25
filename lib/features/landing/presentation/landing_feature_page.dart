import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'feature_detail_screen.dart';
import 'landing_scaffold.dart';
import 'landing_screen.dart' show MockProjectListScreen, MockSwatchScreen, MockMarketScreen, MockCommunityScreen, MockEncyclopediaScreen, MockRavelrySyncScreen, MockPatternEditorScreen, MockPatternEditorExtendedScreen, MockCounterScreen, MockMeasureToolScreen, MockGaugeScreen, MockEtsyScreen, MockAiPatternConverterScreen, MockAiGaugeScreen, MockAiTranslatorScreen, MockCloudSyncScreen, MockRavelryYarnScreen;

// ── 공통 2단 레이아웃 기능 페이지 ─────────────────────────────────────────────────
// 좌: 폰 목업 + 기능 설명 (400px 고정)
// 우: 기능별 인터랙티브 데모 패널 (Expanded)
// ──────────────────────────────────────────────────────────────────────────────

const double _kDesktop = 900.0;

class LandingGenericFeaturePage extends StatelessWidget {
  final String featureId;
  const LandingGenericFeaturePage({super.key, required this.featureId});

  @override
  Widget build(BuildContext context) {
    final feature = findFeature(featureId);
    if (feature == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.go('/'))),
        body: const Center(child: Text('페이지를 찾을 수 없어요')),
      );
    }
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= _kDesktop;

    return LandingFeatureScaffold(
      slivers: [
        SliverToBoxAdapter(
          child: isDesktop
              ? _DesktopLayout(feature: feature)
              : _MobileLayout(feature: feature),
        ),
      ],
    );
  }
}

// ── 데스크탑: 2단 레이아웃 ──────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final FeatureInfo feature;
  const _DesktopLayout({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 좌: 기능 설명
              SizedBox(
                width: 400,
                child: _FeatureLeftPanel(feature: feature),
              ),
              const SizedBox(width: 32),
              // 우: 기능별 데모
              Expanded(
                child: _buildRightPanel(feature.id, feature.color, context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 모바일: 1단 레이아웃 ────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final FeatureInfo feature;
  const _MobileLayout({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeatureLeftPanel(feature: feature, compact: true),
          const SizedBox(height: 32),
          _buildRightPanel(feature.id, feature.color, context),
        ],
      ),
    );
  }
}

// ── 우단 패널 빌더 ─────────────────────────────────────────────────────────────
Widget _buildRightPanel(String featureId, Color color, BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 패널 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              Icon(_featureIcon(featureId), size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                _featurePanelTitle(featureId),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('라이브 데모', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // 패널 본문
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPanelBody(featureId, color, context),
        ),
      ],
    ),
  );
}

IconData _featureIcon(String featureId) {
  switch (featureId) {
    case 'project': return Icons.folder_special_rounded;
    case 'swatch': return Icons.grid_view_rounded;
    case 'market': return Icons.storefront_rounded;
    case 'community': return Icons.people_alt_rounded;
    case 'gauge': return Icons.calculate_rounded;
    case 'pattern-editor': return Icons.grid_on_rounded;
    case 'counter': return Icons.track_changes_rounded;
    case 'measure': return Icons.square_foot_rounded;
    case 'ravelry': return Icons.search_rounded;
    case 'etsy': return Icons.shopping_bag_rounded;
    case 'ai-gauge': return Icons.auto_awesome_rounded;
    case 'ai-pattern-converter': return Icons.auto_awesome_rounded;
    case 'ai-translator': return Icons.translate_rounded;
    case 'cloud-sync': return Icons.cloud_sync_rounded;
    // #656 Wave 2 — 신규 6종
    case 'pattern-viewer': return Icons.menu_book_outlined;
    case 'pattern-library': return Icons.library_books_rounded;
    case 'yarn': return Icons.color_lens_rounded;
    case 'needle': return Icons.linear_scale_rounded;
    case 'book': return Icons.auto_stories_rounded;
    case 'accessory': return Icons.handyman_rounded;
    default: return Icons.star_rounded;
  }
}

String _featurePanelTitle(String featureId) {
  switch (featureId) {
    case 'project': return '내 프로젝트';
    case 'swatch': return '스와치 보관함';
    case 'market': return '도안 마켓';
    case 'community': return '커뮤니티 피드';
    case 'gauge': return '게이지 계산기';
    case 'pattern-editor': return '도안 에디터';
    case 'counter': return '카운터 & 트래커';
    case 'measure': return '측정 도구';
    case 'ravelry': return 'Ravelry 검색';
    case 'etsy': return 'Etsy 판매';
    case 'ai-gauge': return 'AI 게이지 판독';
    case 'ai-pattern-converter': return 'AI 도안 변환';
    case 'ai-translator': return 'AI 번역기';
    case 'cloud-sync': return '클라우드 파일';
    // #656 Wave 2 — 신규 6종
    case 'pattern-viewer': return '도안 뷰어';
    case 'pattern-library': return '도안 라이브러리';
    case 'yarn': return '실 보관함';
    case 'needle': return '바늘 보관함';
    case 'book': return '뜨개 도서';
    case 'accessory': return '악세서리 보관함';
    default: return '기능 미리보기';
  }
}

Widget _buildPanelBody(String featureId, Color color, BuildContext context) {
  switch (featureId) {
    case 'project':
      return _ProjectPanel(color: color, context: context);
    case 'swatch':
      return _SwatchPanel(color: color);
    case 'market':
      return _MarketPanel(color: color);
    case 'community':
      return _CommunityPanel(color: color);
    case 'gauge':
      return _GaugePanel(color: color);
    case 'pattern-editor':
      return _PatternEditorPanel(color: color);
    case 'counter':
      return _CounterPanel(color: color);
    case 'measure':
      return _MeasurePanel(color: color);
    case 'ravelry':
      return _RavelryPanel(color: color);
    case 'etsy':
      return _EtsyPanel(color: color);
    case 'ai-gauge':
      return _AiGaugePanel(color: color);
    case 'ai-pattern-converter':
      return _AiPatternConverterPanel(color: color);
    case 'ai-translator':
      return _AiTranslatorPanel(color: color);
    case 'cloud-sync':
      return _CloudSyncPanel(color: color);
    default:
      return _DefaultPanel(featureId: featureId, color: color);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 좌단: 기능 설명 패널 (encyclopedia의 _FeaturePanel 동일 구조)
// ──────────────────────────────────────────────────────────────────────────────
class _FeatureLeftPanel extends StatelessWidget {
  final FeatureInfo feature;
  final bool compact;

  const _FeatureLeftPanel({required this.feature, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ① 히어로 목업
        _PhoneMockup(feature: feature, compact: compact),
        const SizedBox(height: 28),
        // ② 아이콘 + 제목
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: feature.color.withValues(alpha: 0.25)),
              ),
              child: Icon(feature.icon, color: feature.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    feature.tagline,
                    style: TextStyle(
                      fontSize: 13,
                      color: feature.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ③ 설명
        Text(
          feature.description,
          style: const TextStyle(
            fontSize: 14,
            height: 1.75,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 24),
        // ④ 하이라이트
        ...feature.highlights.map((h) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: feature.color, size: 12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  h,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF374151), height: 1.5),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 24),
        // ⑤ 사용 단계
        ...List.generate(feature.steps.length, (i) {
          final (icon, title, desc) = feature.steps[i];
          final isLast = i == feature.steps.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: feature.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: feature.color.withValues(alpha: 0.20)),
                      ),
                      child: Icon(icon, color: feature.color, size: 18),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 32,
                        color: feature.color.withValues(alpha: 0.18),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: feature.color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${i + 1}단계',
                                style: TextStyle(fontSize: 10, color: feature.color, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 28),
        // ⑥ CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/signup?source=${feature.id}'),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('무료로 시작하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: feature.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 폰 목업 외곽 컨테이너 ─────────────────────────────────────────────────────
class _PhoneMockup extends StatelessWidget {
  final FeatureInfo feature;
  final bool compact;

  const _PhoneMockup({required this.feature, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // #609 — 폰 프레임(200×420)이 잘리지 않도록 외곽 컨테이너 높이 확장
    final h = compact ? 460.0 : 480.0;

    return Container(
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            feature.color.withValues(alpha: 0.08),
            feature.color.withValues(alpha: 0.04),
            const Color(0xFFF8F6FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: feature.color.withValues(alpha: 0.15)),
      ),
      child: Center(
        child: _MockPhoneContent(feature: feature),
      ),
    );
  }
}

// ── 폰 내부 콘텐츠 (featureId 기반) ──────────────────────────────────────────
class _MockPhoneContent extends StatelessWidget {
  final FeatureInfo feature;
  const _MockPhoneContent({required this.feature});

  @override
  Widget build(BuildContext context) {
    // #609 — 히어로 섹션 _PhoneFrame과 동일한 비율 (200 × 420)
    const phoneW = 200.0;
    const phoneH = 420.0;
    final live = _liveMockup(feature.id);
    final hasLive = live != null;

    return Container(
      width: phoneW,
      height: phoneH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: feature.color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: feature.color.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            // 상단 노치 (히어로와 동일)
            Container(
              height: 26,
              color: const Color(0xFFF5F5F8),
              child: Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // 앱바 — 라이브 위젯 시 제거 (위젯 자체에 헤더 포함)
            if (!hasLive)
              Container(
                height: 38,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(feature.icon, size: 14, color: feature.color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        feature.title,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // 콘텐츠 영역
            Expanded(
              child: Container(
                color: hasLive ? Colors.white : feature.color.withValues(alpha: 0.05),
                child: hasLive ? live : _buildPhoneContent(feature),
              ),
            ),
            // 하단 인디케이터 (히어로와 동일)
            Container(
              height: 20,
              color: Colors.white,
              child: Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// #609 — 히어로 섹션의 라이브 Mock 위젯 매핑 (전체 15개 features)
  Widget? _liveMockup(String id) {
    return switch (id) {
      'project' => const MockProjectListScreen(),
      'swatch' => const MockSwatchScreen(),
      'market' => const MockMarketScreen(),
      'community' => const MockCommunityScreen(),
      'encyclopedia' => const MockEncyclopediaScreen(),
      'ravelry' => const MockRavelrySyncScreen(),
      'pattern-editor' => const MockPatternEditorScreen(),
      'counter' => const MockCounterScreen(),
      'measure' => const MockMeasureToolScreen(),
      // #609 신규 추가 — 6개 미매핑 위젯
      'gauge' => const MockGaugeScreen(),
      'etsy' => const MockEtsyScreen(),
      'ai-pattern-converter' => const MockAiPatternConverterScreen(),
      'ai-gauge' => const MockAiGaugeScreen(),
      'ai-translator' => const MockAiTranslatorScreen(),
      'cloud-sync' => const MockCloudSyncScreen(),
      // #656 Wave 2 — 신규 6종 (가능한 기존 위젯 재사용, 나머지는 _buildPhoneContent 폴백)
      'pattern-viewer' => const MockPatternEditorExtendedScreen(),
      'pattern-library' => const MockMarketScreen(),
      'yarn' => const MockRavelryYarnScreen(),
      _ => null,
    };
  }

  Widget _buildPhoneContent(FeatureInfo feature) {
    switch (feature.id) {
      case 'project':
        return ListView(
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _miniProjectCard('탑다운 스웨터', 0.8, feature.color),
            _miniProjectCard('손모아 장갑', 1.0, feature.color),
            _miniProjectCard('케이블 목도리', 0.0, feature.color),
          ],
        );
      case 'swatch':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _miniSwatchCard('메리야스', '20×28', feature.color),
              _miniSwatchCard('고무단', '22×30', feature.color),
              _miniSwatchCard('넥스트 스텝', '18×24', feature.color),
              _miniSwatchCard('에코 울', '21×29', feature.color),
            ],
          ),
        );
      case 'market':
        return ListView(
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _miniMarketCard('탑다운 스웨터', '₩3,500', feature.color),
            _miniMarketCard('손모아 장갑', '₩2,500', feature.color),
            _miniMarketCard('케이블 목도리', '₩2,000', feature.color),
          ],
        );
      case 'gauge':
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _miniInputRow('코수', '20', feature.color),
              const SizedBox(height: 6),
              _miniInputRow('단수', '28', feature.color),
              const SizedBox(height: 6),
              _miniInputRow('너비', '45cm', feature.color),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: feature.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('계산', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('결과', style: TextStyle(fontSize: 9, color: feature.color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text('90코', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'counter':
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('47단', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: feature.color)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniCounterBtn('-', feature.color),
                  const SizedBox(width: 12),
                  _miniCounterBtn('+', feature.color),
                ],
              ),
              const SizedBox(height: 10),
              _miniProgressBar(0.6, feature.color),
              const SizedBox(height: 4),
              Text('60% 완료', style: TextStyle(fontSize: 8, color: feature.color)),
            ],
          ),
        );
      case 'pattern-editor':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(child: _miniColorGrid(feature.color)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _miniColorDot(feature.color),
                  _miniColorDot(feature.color.withValues(alpha: 0.5)),
                  _miniColorDot(const Color(0xFFECFCFD)),
                  _miniColorDot(const Color(0xFF1A1A2E).withValues(alpha: 0.7)),
                ],
              ),
            ],
          ),
        );
      case 'measure':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _miniMeasureCard('현재', '47단', '15.7cm', feature.color),
              const SizedBox(height: 6),
              _miniMeasureCard('목표', '60단', '20.0cm', feature.color.withValues(alpha: 0.6)),
              const SizedBox(height: 6),
              _miniMeasureCard('남은', '13단', '4.3cm', Colors.grey),
            ],
          ),
        );
      case 'ravelry':
        return ListView(
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _miniRavelryCard('Drops Merino', 'Fingering', feature.color),
            _miniRavelryCard('Rowan Felted', 'DK', feature.color),
            _miniRavelryCard('Cascade 220', 'Worsted', feature.color),
          ],
        );
      case 'etsy':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _miniEtsyCard('탑다운 스웨터 도안', '\$4.50', feature.color),
              const SizedBox(height: 6),
              _miniEtsyCard('손모아 장갑 도안', '\$3.20', feature.color),
            ],
          ),
        );
      case 'ai-gauge':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined, color: Colors.grey.shade400, size: 20),
                        const SizedBox(height: 4),
                        Text('스와치 사진', style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(children: [
                      Text('코수', style: TextStyle(fontSize: 7, color: feature.color, fontWeight: FontWeight.w700)),
                      const Text('24', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                    ]),
                    Container(width: 1, height: 24, color: Colors.grey.shade200),
                    Column(children: [
                      Text('단수', style: TextStyle(fontSize: 7, color: feature.color, fontWeight: FontWeight.w700)),
                      const Text('32', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'ai-pattern-converter':
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('원본', style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: const Text('CO 80 sts. Work in k2,p2 rib...', style: TextStyle(fontSize: 7.5, color: Color(0xFF374151), height: 1.4)),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.auto_fix_high_rounded, size: 10, color: feature.color),
                const SizedBox(width: 4),
                Text('AI 변환', style: TextStyle(fontSize: 8, color: feature.color, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: feature.color.withValues(alpha: 0.2)),
                ),
                child: Text('80코 잡기. 2코 겉뜨기, 2코 안뜨기 고무단...', style: TextStyle(fontSize: 7.5, color: feature.color.withValues(alpha: 0.8), height: 1.4)),
              ),
            ],
          ),
        );
      case 'ai-translator':
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('영문', style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: const Text('k2tog, ssk, yo, m1l, pm...', style: TextStyle(fontSize: 7.5, color: Color(0xFF374151))),
              ),
              const SizedBox(height: 6),
              Icon(Icons.swap_vert_rounded, size: 14, color: feature.color),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: feature.color.withValues(alpha: 0.2)),
                ),
                child: Text('2코 모아 겉뜨기, 왼코 줄임, 걸기코...', style: TextStyle(fontSize: 7.5, color: feature.color.withValues(alpha: 0.8))),
              ),
            ],
          ),
        );
      case 'cloud-sync':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.cloud_rounded, size: 12, color: Color(0xFF0061FF)),
                const SizedBox(width: 4),
                Text('Dropbox', style: TextStyle(fontSize: 8, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              _miniFileCard('스웨터도안.pdf', Icons.picture_as_pdf_rounded, const Color(0xFFEF4444), feature.color),
              const SizedBox(height: 5),
              _miniFileCard('장갑패턴.pdf', Icons.picture_as_pdf_rounded, const Color(0xFFEF4444), feature.color),
              const SizedBox(height: 5),
              _miniFileCard('게이지사진.jpg', Icons.image_rounded, const Color(0xFF3B82F6), feature.color),
            ],
          ),
        );
      case 'community':
        return ListView(
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _miniCommunityCard('완성했어요! 탑다운 스웨터', 32, 8, feature.color),
            _miniCommunityCard('게이지 맞추기 팁 공유', 18, 5, feature.color),
          ],
        );
      default:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, color: feature.color, size: 36),
              const SizedBox(height: 8),
              Text('기능 미리보기', style: TextStyle(fontSize: 12, color: feature.color, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    }
  }

  // ── 폰 내부 공통 헬퍼 ────────────────────────────────────────────────────────
  Widget _miniProjectCard(String title, double progress, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          _miniProgressBar(progress, color),
          const SizedBox(height: 2),
          Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 7, color: color)),
        ],
      ),
    );
  }

  Widget _miniSwatchCard(String name, String gauge, Color color) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_view_rounded, size: 14, color: color),
          const SizedBox(height: 3),
          Text(name, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center),
          Text(gauge, style: TextStyle(fontSize: 7, color: color)),
        ],
      ),
    );
  }

  Widget _miniMarketCard(String title, String price, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Row(
        children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
              child: Icon(Icons.description_rounded, size: 12, color: color)),
          const SizedBox(width: 6),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)))),
          Text(price, style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _miniInputRow(String label, String val, Color color) {
    return Row(
      children: [
        SizedBox(width: 30, child: Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF6B7280)))),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Text(val, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _miniCounterBtn(String label, Color color) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
    );
  }

  Widget _miniColorGrid(Color color) {
    final colors = [color, color.withValues(alpha: 0.5), const Color(0xFFECFCFD), color, const Color(0xFFECFCFD), color.withValues(alpha: 0.5)];
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, mainAxisSpacing: 1.5, crossAxisSpacing: 1.5),
      itemCount: 50,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: colors[i % colors.length],
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _miniColorDot(Color color) {
    return Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200)));
  }

  Widget _miniMeasureCard(String label, String rows, String cm, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF6B7280))),
          const Spacer(),
          Text(rows, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text('= $cm', style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _miniRavelryCard(String name, String weight, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Row(
        children: [
          Container(width: 22, height: 22, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.search_rounded, size: 11, color: color)),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(weight, style: TextStyle(fontSize: 7, color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _miniEtsyCard(String title, String price, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Row(
        children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFF96914).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.shopping_bag_rounded, size: 14, color: Color(0xFFF96914))),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)))),
          Text(price, style: const TextStyle(fontSize: 9, color: Color(0xFFF96914), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _miniFileCard(String name, IconData icon, Color iconColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Row(
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 8, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis)),
          Icon(Icons.download_rounded, size: 10, color: accentColor.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _miniCommunityCard(String text, int likes, int comments, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 30, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
              child: Center(child: Icon(Icons.image_rounded, size: 14, color: color.withValues(alpha: 0.4)))),
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.favorite_rounded, size: 9, color: color),
            const SizedBox(width: 2),
            Text('$likes', style: TextStyle(fontSize: 7.5, color: color)),
            const SizedBox(width: 6),
            Icon(Icons.chat_bubble_outline_rounded, size: 9, color: Colors.grey.shade400),
            const SizedBox(width: 2),
            Text('$comments', style: TextStyle(fontSize: 7.5, color: Colors.grey.shade400)),
          ]),
        ],
      ),
    );
  }

  Widget _miniProgressBar(double value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 우단 패널 위젯들
// ──────────────────────────────────────────────────────────────────────────────

// ── 프로젝트 패널 ─────────────────────────────────────────────────────────────
class _ProjectPanel extends StatelessWidget {
  final Color color;
  final BuildContext context;
  const _ProjectPanel({required this.color, required this.context});

  @override
  Widget build(BuildContext outerCtx) {
    final items = [
      ('탑다운 스웨터', '진행 중', 0.8, '메리노울'),
      ('손모아 장갑', '완성', 1.0, '알파카'),
      ('케이블 목도리', '구상 중', 0.0, '아크릴'),
      ('래글런 가디건', '진행 중', 0.35, '램스울'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.map((item) {
          final (title, status, progress, yarn) = item;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)))),
                    _tag(status, color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(yarn, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                _progressBar(progress, color),
                const SizedBox(height: 4),
                Text('${(progress * 100).toInt()}% 완료', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.add_rounded, size: 16, color: color),
            label: Text('새 프로젝트 만들기', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 스와치 패널 ───────────────────────────────────────────────────────────────
class _SwatchPanel extends StatelessWidget {
  final Color color;
  const _SwatchPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('메리야스뜨기', '20코 × 28단', '메리노울 4ply', '2.5mm'),
      ('1코 고무단', '22코 × 30단', '알파카 DK', '3.5mm'),
      ('넥스트 스텝', '18코 × 24단', '에코 울', '4.0mm'),
      ('에코 울 스와치', '21코 × 29단', '에코 울 worsted', '5.0mm'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: items.map((item) {
        final (name, gauge, yarn, needle) = item;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.grid_view_rounded, size: 16, color: color),
              ),
              const SizedBox(height: 8),
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text(gauge, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              Text(needle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── 도안 마켓 패널 ────────────────────────────────────────────────────────────
class _MarketPanel extends StatelessWidget {
  final Color color;
  const _MarketPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('탑다운 스웨터', '₩3,500', 4.8, 42),
      ('손모아 장갑', '₩2,500', 4.6, 28),
      ('케이블 목도리', '₩2,000', 4.9, 67),
      ('아란 조끼', '₩4,500', 4.7, 19),
      ('래글런 가디건', '₩3,000', 4.5, 35),
      ('버블 스웨터', '₩2,800', 4.8, 23),
    ];
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.85,
      children: items.map((item) {
        final (title, price, rating, cnt) = item;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 70,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Center(child: Icon(Icons.description_rounded, size: 28, color: color.withValues(alpha: 0.5))),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(price, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
                    Row(children: [
                      Icon(Icons.star_rounded, size: 9, color: Colors.amber.shade400),
                      Text(' $rating ($cnt)', style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── 커뮤니티 패널 ─────────────────────────────────────────────────────────────
class _CommunityPanel extends StatelessWidget {
  final Color color;
  const _CommunityPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('완성했어요! 탑다운 스웨터', '첫 스웨터 완성! 너무 뿌듯해요 🧶', 'knitter_somi', 84, 12),
      ('게이지 맞추기 팁 공유합니다', '처음엔 항상 게이지가 안 맞았는데 이렇게 하니...', 'wool_fairy', 51, 7),
      ('알파카 실 추천해주세요', '보들보들한 알파카 실 써보신 분 계신가요?', 'yarn_lover', 29, 15),
    ];
    return Column(
      children: items.map((item) {
        final (title, body, author, likes, comments) = item;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                ),
                child: Center(child: Icon(Icons.image_rounded, size: 32, color: color.withValues(alpha: 0.3))),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 4),
                    Text(body, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.person_rounded, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(author, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const Spacer(),
                      Icon(Icons.favorite_rounded, size: 12, color: color),
                      const SizedBox(width: 3),
                      Text('$likes', style: TextStyle(fontSize: 11, color: color)),
                      const SizedBox(width: 8),
                      Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text('$comments', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── 게이지 계산기 패널 ────────────────────────────────────────────────────────
class _GaugePanel extends StatelessWidget {
  final Color color;
  const _GaugePanel({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('게이지 입력', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        _inputCard('10cm 기준 코수', '20', color),
        const SizedBox(height: 8),
        _inputCard('10cm 기준 단수', '28', color),
        const SizedBox(height: 16),
        Text('목표 치수', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        _inputCard('목표 너비 (cm)', '45', color),
        const SizedBox(height: 8),
        _inputCard('목표 길이 (cm)', '60', color),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calculate_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('계산하기', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _resultBlock('필요 코수', '90코', color),
              Container(width: 1, height: 48, color: color.withValues(alpha: 0.2)),
              _resultBlock('필요 단수', '168단', color),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inputCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          Text(value, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _resultBlock(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

// ── 도안 에디터 패널 ──────────────────────────────────────────────────────────
class _PatternEditorPanel extends StatelessWidget {
  final Color color;
  const _PatternEditorPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    final gridColors = [
      color,
      color.withValues(alpha: 0.5),
      const Color(0xFFECFCFD),
      color,
      const Color(0xFFECFCFD),
      color.withValues(alpha: 0.5),
      const Color(0xFFECFCFD),
      color,
      color.withValues(alpha: 0.5),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(10),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 15,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: 150,
            itemBuilder: (_, i) => Container(
              decoration: BoxDecoration(
                color: gridColors[i % gridColors.length],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('색상 팔레트', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Row(
          children: [
            _colorChip(color, '주 색상', true),
            const SizedBox(width: 8),
            _colorChip(color.withValues(alpha: 0.5), '보조 색상', false),
            const SizedBox(width: 8),
            _colorChip(const Color(0xFFECFCFD), '배경 색상', false),
            const SizedBox(width: 8),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded, size: 16, color: Colors.grey.shade400),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('기호 패널', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ['겉뜨기', '안뜨기', '모아뜨기', '걸기코', '꼬아뜨기'].map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(s, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _colorChip(Color chipColor, String label, bool selected) {
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFF1A1A2E) : Colors.grey.shade200, width: selected ? 2 : 1),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
      ],
    );
  }
}

// ── 카운터 패널 ───────────────────────────────────────────────────────────────
class _CounterPanel extends StatelessWidget {
  final Color color;
  const _CounterPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Text('현재 단수', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              Text('47', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: color, height: 1)),
              Text('단', style: TextStyle(fontSize: 18, color: color.withValues(alpha: 0.7))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _counterButton('-', color, large: true),
                  const SizedBox(width: 24),
                  _counterButton('+', color, large: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _progressBar(0.6, color),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('47 / 80단', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text('60% 완료', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        Text('구간 기록', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        ...[(1, 20, '소매 시작'), (21, 35, '몸통'), (36, 47, '넥라인')].map((rec) {
          final (from, to, label) = rec;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const Spacer(),
                Text('$from ~ $to단', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(width: 6),
                _tag('${to - from + 1}단', color),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _counterButton(String label, Color color, {bool large = false}) {
    return Container(
      width: large ? 56 : 40,
      height: large ? 56 : 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Text(label, style: TextStyle(color: Colors.white, fontSize: large ? 24 : 18, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── 측정 도구 패널 ────────────────────────────────────────────────────────────
class _MeasurePanel extends StatelessWidget {
  final Color color;
  const _MeasurePanel({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('게이지 설정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _settingChip('단수/10cm', '28단', color),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              _settingChip('코수/10cm', '20코', color),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('측정 결과', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        _measureCard('현재까지', '47단', '16.8cm', color, isHighlight: true),
        const SizedBox(height: 8),
        _measureCard('목표', '60단', '21.4cm', Colors.grey.shade400),
        const SizedBox(height: 8),
        _measureCard('남은 단수', '13단', '4.6cm', Colors.blue.shade300),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('진행률', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              _progressBar(47 / 60, color),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('47단 완료', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  Text('78%', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _measureCard(String label, String rows, String cm, Color color, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight ? color.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHighlight ? color.withValues(alpha: 0.25) : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          Text(rows, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 6),
          Text('= $cm', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// ── Ravelry 패널 ──────────────────────────────────────────────────────────────
class _RavelryPanel extends StatelessWidget {
  final Color color;
  const _RavelryPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Drops Merino Extra Fine', 'Drops Design', 'Fingering', 4.7, '₩12,000/100g'),
      ('Rowan Felted Tweed DK', 'Rowan', 'DK', 4.5, '₩22,000/50g'),
      ('Cascade 220', 'Cascade Yarns', 'Worsted', 4.9, '₩18,000/100g'),
    ];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text('실 이름, 브랜드, 굵기로 검색', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            ],
          ),
        ),
        ...items.map((item) {
          final (name, brand, weight, rating, price) = item;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.circle_rounded, size: 24, color: color.withValues(alpha: 0.4)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(brand, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _tag(weight, color),
                        const SizedBox(width: 6),
                        Icon(Icons.star_rounded, size: 11, color: Colors.amber.shade400),
                        Text(' $rating', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: const Text('추가', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Etsy 패널 ─────────────────────────────────────────────────────────────────
class _EtsyPanel extends StatelessWidget {
  final Color color;
  const _EtsyPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    const etsyOrange = Color(0xFFF96914);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_bag_rounded, color: etsyOrange, size: 20),
            const SizedBox(width: 8),
            const Text('Etsy 판매 현황', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _statCard('총 판매', '127건', etsyOrange)),
            const SizedBox(width: 8),
            Expanded(child: _statCard('이번 달', '23건', etsyOrange)),
            const SizedBox(width: 8),
            Expanded(child: _statCard('수익', '\$312', etsyOrange)),
          ],
        ),
        const SizedBox(height: 16),
        Text('내 리스팅', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        _etsyListing('탑다운 스웨터 도안', '\$4.50', '67 판매', etsyOrange),
        const SizedBox(height: 8),
        _etsyListing('손모아 장갑 도안', '\$3.20', '34 판매', etsyOrange),
        const SizedBox(height: 8),
        _etsyListing('케이블 목도리 도안', '\$2.80', '26 판매', etsyOrange),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('새 리스팅 등록'),
            style: ElevatedButton.styleFrom(
              backgroundColor: etsyOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _etsyListing(String title, String price, String sales, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.description_rounded, size: 22, color: Color(0xFFF96914)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                Text(sales, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(price, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ── AI 게이지 판독기 패널 ─────────────────────────────────────────────────────
class _AiGaugePanel extends StatelessWidget {
  final Color color;
  const _AiGaugePanel({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('스와치 사진 분석', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('스와치 사진', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high_rounded, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text('분석 중...', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  Text('AI 분석 결과', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  _aiResultBlock('코수', '24', '10cm 기준', color),
                  const SizedBox(height: 10),
                  _aiResultBlock('단수', '32', '10cm 기준', color),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('스와치에 저장', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI가 코와 단을 자동으로 감지했어요. 10cm 기준으로 정확히 환산됩니다.',
                  style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aiResultBlock(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ── AI 도안 변환기 패널 ───────────────────────────────────────────────────────
class _AiPatternConverterPanel extends StatelessWidget {
  final Color color;
  const _AiPatternConverterPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('원본 도안', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Text(
            'CO 80 sts. Join to work in the round, being careful not to twist. Work in k2, p2 rib for 2 inches. Change to stockinette st and work even until piece measures 14" from CO edge.',
            style: TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.6, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  const Text('AI 변환', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('변환 결과', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepRow(1, '80코 잡기', '원형으로 연결하여 코가 꼬이지 않게 주의', color),
              const SizedBox(height: 8),
              _stepRow(2, '2코 고무단 5cm', '2코 겉뜨기, 2코 안뜨기 반복', color),
              const SizedBox(height: 8),
              _stepRow(3, '메리야스뜨기', '35cm 될 때까지 평뜨기', color),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepRow(int step, String title, String desc, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AI 번역기 패널 ────────────────────────────────────────────────────────────
class _AiTranslatorPanel extends StatelessWidget {
  final Color color;
  const _AiTranslatorPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('영문 도안 입력', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Text(
            'Row 1 (RS): k2tog, *ssk, k4, yo, k1, yo, k4, k2tog; rep from * to last 2 sts, ssk.',
            style: TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.6),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_vert_rounded, color: color, size: 24),
            const SizedBox(width: 8),
            Text('AI 번역 중...', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 14),
        Text('한국어 번역', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            '1행 (겉면): 2코 모아 겉뜨기, *왼코 줄임, 겉뜨기 4코, 걸기코, 겉뜨기 1코, 걸기코, 겉뜨기 4코, 2코 모아 겉뜨기; 마지막 2코까지 *에서 반복, 왼코 줄임.',
            style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.85), height: 1.65),
          ),
        ),
        const SizedBox(height: 16),
        Text('용어 대조표', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        ...[
          ('k2tog', '2코 모아 겉뜨기'),
          ('ssk', '왼코 줄임'),
          ('yo', '걸기코'),
        ].map((pair) {
          final (en, ko) = pair;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(en, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFD1D5DB)),
                const SizedBox(width: 10),
                Text(ko, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── 클라우드 연결 패널 ────────────────────────────────────────────────────────
class _CloudSyncPanel extends StatelessWidget {
  final Color color;
  const _CloudSyncPanel({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0061FF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0061FF).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_rounded, color: Color(0xFF0061FF), size: 18),
                  const SizedBox(width: 6),
                  const Text('Dropbox 연결됨', style: TextStyle(color: Color(0xFF0061FF), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 14),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('Google Drive', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('파일 목록', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        ...[
          ('스웨터도안.pdf', Icons.picture_as_pdf_rounded, const Color(0xFFEF4444), '2.1 MB', '오늘'),
          ('장갑패턴.pdf', Icons.picture_as_pdf_rounded, const Color(0xFFEF4444), '842 KB', '어제'),
          ('게이지사진.jpg', Icons.image_rounded, const Color(0xFF3B82F6), '3.4 MB', '2일 전'),
          ('목도리_도안.pdf', Icons.picture_as_pdf_rounded, const Color(0xFFEF4444), '1.2 MB', '3일 전'),
          ('스와치_참고.png', Icons.image_rounded, const Color(0xFF3B82F6), '2.8 MB', '1주 전'),
        ].map((file) {
          final (name, icon, iconColor, size, date) = file;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                      Text('$size  · $date', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                Icon(Icons.download_rounded, size: 18, color: color.withValues(alpha: 0.5)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── 기본 패널 (featureId 매핑 없는 경우) ─────────────────────────────────────
class _DefaultPanel extends StatelessWidget {
  final String featureId;
  final Color color;
  const _DefaultPanel({required this.featureId, required this.color});

  @override
  Widget build(BuildContext context) {
    final feature = findFeature(featureId);
    final highlights = feature?.highlights ?? [];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: highlights.map((h) => Container(
        padding: const EdgeInsets.all(14),
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.check_rounded, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            Text(h, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4)),
          ],
        ),
      )).toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 공통 헬퍼 함수
// ──────────────────────────────────────────────────────────────────────────────

Widget _tag(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

Widget _progressBar(double value, Color color) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 6,
      backgroundColor: color.withValues(alpha: 0.15),
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  );
}
