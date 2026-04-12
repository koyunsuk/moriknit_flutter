import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import 'landing_top_bar.dart';

// ── 기능 데이터 ────────────────────────────────────────────────────────────────
class FeatureInfo {
  final String id;
  final IconData icon;
  final String title;
  final String tagline;
  final Color color;
  final String description;
  final List<String> highlights;
  final List<(IconData, String, String)> steps; // (icon, title, desc)

  const FeatureInfo({
    required this.id,
    required this.icon,
    required this.title,
    required this.tagline,
    required this.color,
    required this.description,
    required this.highlights,
    required this.steps,
  });
}

const List<FeatureInfo> featureList = [
  FeatureInfo(
    id: 'project',
    icon: Icons.folder_special_rounded,
    title: '프로젝트 기록',
    tagline: '진행 중인 뜨개를 체계적으로 관리',
    color: Color(0xFFC084FC),
    description: '캐스트온부터 바인드오프까지, 내 뜨개 프로젝트의 모든 과정을 기록하세요. '
        '실 정보, 코바늘·대바늘 사이즈, 진행 상태, 사진까지 한 곳에 담을 수 있어요.',
    highlights: [
      '진행 상태 단계별 관리 (구상 → 진행 중 → 완성)',
      '실 정보 & 도구 자동 연결',
      '완성 사진 갤러리',
      '도안 직접 첨부 또는 연결',
    ],
    steps: [
      (Icons.add_circle_outline_rounded, '프로젝트 생성', '프로젝트 이름, 상태, 실 정보를 입력하세요.'),
      (Icons.photo_library_rounded, '사진 기록', '진행 단계마다 사진을 찍어 기록해요.'),
      (Icons.check_circle_outline_rounded, '완성 & 공유', '완성된 작품을 커뮤니티에 공유할 수 있어요.'),
    ],
  ),
  FeatureInfo(
    id: 'swatch',
    icon: Icons.grid_view_rounded,
    title: '스와치 보관함',
    tagline: '게이지 기록과 실 정보를 저장',
    color: Color(0xFF22D3EE),
    description: '뜨개 전 반드시 필요한 게이지 스와치를 체계적으로 보관하세요. '
        '실 종류별, 바늘 굵기별로 분류하면 나만의 게이지 데이터베이스가 만들어집니다.',
    highlights: [
      '10cm × 10cm 표준 게이지 기록',
      '실 브랜드·색상·굵기 태그',
      '바늘/코바늘 사이즈 연동',
      'AI 게이지 판독기와 연결',
    ],
    steps: [
      (Icons.straighten_rounded, '스와치 제작', '10cm 스와치를 뜨고 코수·단수를 측정하세요.'),
      (Icons.save_alt_rounded, '정보 저장', '실 정보와 바늘 사이즈를 함께 기록해요.'),
      (Icons.calculate_rounded, '게이지 계산', '저장된 게이지로 도안 변환 계산이 바로 돼요.'),
    ],
  ),
  FeatureInfo(
    id: 'market',
    icon: Icons.storefront_rounded,
    title: '도안 마켓',
    tagline: '도안을 구매하거나 직접 판매',
    color: Color(0xFFF472B6),
    description: '검증된 뜨개 도안을 구매하거나, 직접 만든 도안을 판매해보세요. '
        '에디터로 만든 도안은 PDF로 다운로드·공유·판매까지 가능합니다.',
    highlights: [
      '에디터 도안 PDF 다운로드',
      '도안 미리보기 & 평점',
      '크레딧 기반 결제 시스템',
      '"나도 하기" Fork 기능',
    ],
    steps: [
      (Icons.search_rounded, '도안 검색', '카테고리·난이도·실 종류로 원하는 도안을 찾아요.'),
      (Icons.download_rounded, '구매·다운로드', '크레딧으로 도안을 구매하고 바로 다운받아요.'),
      (Icons.upload_rounded, '내 도안 판매', '에디터로 만든 도안을 마켓에 등록해 수익을 얻어요.'),
    ],
  ),
  FeatureInfo(
    id: 'community',
    icon: Icons.people_alt_rounded,
    title: '커뮤니티',
    tagline: '뜨개인들과 작업물을 나누고 소통',
    color: Color(0xFFA3E635),
    description: '완성된 작품을 공유하고, 다른 메이커들의 작업을 구경해보세요. '
        '질문·팁·영감을 나누는 활발한 뜨개 커뮤니티가 기다리고 있어요.',
    highlights: [
      '작품 사진 갤러리 공유',
      '댓글 & 반응',
      '프로젝트 공개 갤러리',
      '"나도 하기" 도안 연결',
    ],
    steps: [
      (Icons.camera_alt_rounded, '작품 촬영', '완성된 뜨개 작품 사진을 찍어요.'),
      (Icons.post_add_rounded, '게시글 작성', '제목, 설명, 사용한 실·도안 정보를 함께 올려요.'),
      (Icons.favorite_rounded, '반응 & 소통', '다른 메이커들의 반응과 팁을 주고받아요.'),
    ],
  ),
  FeatureInfo(
    id: 'encyclopedia',
    icon: Icons.menu_book_rounded,
    title: '뜨개백과사전',
    tagline: '뜨개 용어와 기법을 언제든 검색',
    color: Color(0xFFFB923C),
    description: '코잡기, 코늘리기, 줄이기 등 뜨개 용어와 기법을 언제든 찾아보세요. '
        '한국어·영어 용어 대조, 동영상 링크, 단계별 설명이 함께 제공됩니다.',
    highlights: [
      '한국어 ↔ 영어 용어 대조',
      '기법별 카테고리 분류',
      '동영상·이미지 연결',
      '즐겨찾기 저장',
    ],
    steps: [
      (Icons.search_rounded, '용어 검색', '한국어 또는 영어로 뜨개 용어를 검색하세요.'),
      (Icons.menu_book_rounded, '기법 학습', '단계별 설명과 사진으로 기법을 익혀요.'),
      (Icons.bookmark_rounded, '즐겨찾기', '자주 쓰는 용어는 즐겨찾기로 바로 접근해요.'),
    ],
  ),
  FeatureInfo(
    id: 'gauge',
    icon: Icons.calculate_rounded,
    title: '게이지 계산기',
    tagline: '게이지에 맞는 코수·단수를 계산',
    color: Color(0xFF34D399),
    description: '내 게이지 수치를 입력하면 원하는 치수에 맞는 코수와 단수를 자동으로 계산해줍니다. '
        '도안 변환, 사이즈 조정에 필수적인 도구예요.',
    highlights: [
      '게이지 → 코수/단수 변환',
      '사이즈별 자동 계산',
      '저장된 스와치 데이터 자동 불러오기',
      'cm ↔ inch 단위 전환',
    ],
    steps: [
      (Icons.input_rounded, '게이지 입력', '10cm 기준 코수·단수를 입력해요.'),
      (Icons.tune_rounded, '치수 설정', '만들고 싶은 완성 치수(cm)를 입력해요.'),
      (Icons.calculate_rounded, '결과 확인', '필요한 코수·단수가 즉시 계산돼요.'),
    ],
  ),
  FeatureInfo(
    id: 'ravelry',
    icon: Icons.search_rounded,
    title: 'Ravelry 연동',
    tagline: 'Ravelry 실·도안을 앱 안에서 검색',
    color: Color(0xFF60A5FA),
    description: '세계 최대 뜨개 커뮤니티 Ravelry의 방대한 실·도안 데이터베이스를 '
        '모리니트 앱 안에서 바로 검색할 수 있어요. 검색 결과를 내 프로젝트에 바로 연결하세요.',
    highlights: [
      '실·도안 통합 검색',
      '검색 결과 내 프로젝트 연결',
      '색상·굵기·브랜드 필터',
      '즐겨찾기 저장',
    ],
    steps: [
      (Icons.search_rounded, 'Ravelry 검색', '실 이름, 도안명, 브랜드로 검색해요.'),
      (Icons.visibility_rounded, '상세 보기', '색상, 굵기, 가격 정보를 확인해요.'),
      (Icons.link_rounded, '프로젝트 연결', '마음에 드는 실을 내 프로젝트에 바로 추가해요.'),
    ],
  ),
  FeatureInfo(
    id: 'etsy',
    icon: Icons.shopping_bag_rounded,
    title: 'Etsy 연동',
    tagline: 'Etsy 마켓에 내 도안을 손쉽게 등록·판매',
    color: Color(0xFFFF8C00),
    description: '에디터로 만든 도안을 Etsy 마켓에 바로 등록해 전 세계 뜨개 팬들에게 판매하세요. '
        '모리니트 앱 하나로 도안 제작부터 글로벌 판매까지 완결됩니다.',
    highlights: [
      '도안 PDF Etsy 자동 등록',
      '가격·재고 설정',
      '판매 현황 확인',
      '글로벌 뜨개 마켓 도달',
    ],
    steps: [
      (Icons.edit_rounded, '도안 제작', '에디터로 뜨개 도안을 완성해요.'),
      (Icons.shopping_bag_rounded, 'Etsy 연결', 'Etsy 계정을 연동하고 상품 정보를 입력해요.'),
      (Icons.sell_rounded, '판매 시작', '도안이 Etsy에 등록되고 전 세계에서 판매돼요.'),
    ],
  ),
  FeatureInfo(
    id: 'ai-gauge',
    icon: Icons.auto_awesome_rounded,
    title: 'AI 게이지 판독기',
    tagline: '실 사진으로 게이지를 자동 측정 ✨',
    color: Color(0xFF818CF8),
    description: '스와치 사진 한 장이면 충분해요. '
        'AI가 코와 단을 자동으로 세어 10cm 기준 게이지 수치를 즉시 알려드립니다. '
        '손으로 세던 시간을 아끼세요.',
    highlights: [
      '사진 한 장으로 자동 분석',
      '10cm 영역 지정 측정',
      '코수·단수 즉시 결과',
      '스와치 보관함에 자동 저장',
    ],
    steps: [
      (Icons.photo_camera_outlined, '스와치 사진 촬영', '편평하게 편 스와치 사진을 찍어요.'),
      (Icons.touch_app_outlined, '10cm 영역 선택', '측정할 10cm 구간의 두 점을 터치해요.'),
      (Icons.auto_fix_high_rounded, 'AI 자동 분석', 'AI가 코와 단을 자동으로 계산해요.'),
      (Icons.check_circle_outline_rounded, '결과 저장', '코수·단수를 스와치 보관함에 바로 저장해요.'),
    ],
  ),
];

FeatureInfo? findFeature(String id) {
  try {
    return featureList.firstWhere((f) => f.id == id);
  } catch (_) {
    return null;
  }
}

// ── Feature Detail Screen ──────────────────────────────────────────────────────
class FeatureDetailScreen extends StatelessWidget {
  final String featureId;
  const FeatureDetailScreen({super.key, required this.featureId});

  @override
  Widget build(BuildContext context) {
    final feature = findFeature(featureId);
    if (feature == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.go('/'))),
        body: const Center(child: Text('페이지를 찾을 수 없어요')),
      );
    }
    return _FeatureDetailPage(feature: feature);
  }
}

class _FeatureDetailPage extends StatelessWidget {
  final FeatureInfo feature;
  const _FeatureDetailPage({required this.feature});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    const maxWidth = 860.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FF),
      body: CustomScrollView(
        slivers: [
          // ── 공통 탑바 ────────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: LandingTopBar()),
          // ── 기능 타이틀 서브바 ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Row(
                    children: [
                      Icon(feature.icon, color: feature.color, size: 18),
                      const SizedBox(width: 8),
                      Text(feature.title, style: T.h3.copyWith(color: Colors.white, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── 히어로 ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: feature.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: feature.color.withValues(alpha: 0.3)),
                        ),
                        child: Icon(feature.icon, color: feature.color, size: 36),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        feature.title,
                        style: TextStyle(color: Colors.white, fontSize: width >= 600 ? 34 : 26, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        feature.tagline,
                        style: TextStyle(color: feature.color, fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        feature.description,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 15, height: 1.7),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── 주요 기능 하이라이트 ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('주요 기능', style: T.h2.copyWith(fontSize: 20, color: const Color(0xFF1A1A2E))),
                      const SizedBox(height: 20),
                      ...feature.highlights.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: feature.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded, color: feature.color, size: 14),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(h, style: const TextStyle(fontSize: 15, color: Color(0xFF374151), height: 1.5)),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── 사용 단계 ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('이렇게 사용해요', style: T.h2.copyWith(fontSize: 20, color: const Color(0xFF1A1A2E))),
                      const SizedBox(height: 24),
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
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: feature.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: feature.color.withValues(alpha: 0.25)),
                                    ),
                                    child: Icon(icon, color: feature.color, size: 20),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 40,
                                      color: feature.color.withValues(alpha: 0.2),
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: feature.color.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('${i + 1}단계', style: TextStyle(fontSize: 11, color: feature.color, fontWeight: FontWeight.w700)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── 다른 기능 둘러보기 ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('다른 기능도 살펴보세요', style: T.h2.copyWith(fontSize: 20, color: const Color(0xFF1A1A2E))),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: featureList
                            .where((f) => f.id != feature.id)
                            .map((f) => InkWell(
                              onTap: () => context.go('/features/${f.id}'),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: f.color.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(f.icon, color: f.color, size: 16),
                                    const SizedBox(width: 8),
                                    Text(f.title, style: TextStyle(fontSize: 13, color: f.color, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── CTA ─────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 48, 20, 48),
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [feature.color.withValues(alpha: 0.85), feature.color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: feature.color.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    children: [
                      Text('지금 무료로 시작해보세요', style: T.h2.copyWith(color: Colors.white, fontSize: 22)),
                      const SizedBox(height: 10),
                      Text('${feature.title}을 포함한 모든 기능을 무료로 사용할 수 있어요.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.6), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('무료 계정 만들기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1A2E),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── 푸터 ─────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    const MoriKnitTitle(fontSize: 18),
                    const SizedBox(height: 8),
                    Text('뜨개 기록의 모든 것', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text('랜딩 페이지로 돌아가기', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
