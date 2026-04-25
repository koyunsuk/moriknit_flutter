import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/app_config_provider.dart';
import 'landing_screen.dart' show MockProjectListScreen, MockSwatchScreen, MockMarketScreen, MockCommunityScreen, MockEncyclopediaScreen, MockRavelrySyncScreen, MockPatternEditorScreen, MockPatternEditorExtendedScreen, MockCounterScreen, MockMeasureToolScreen, MockRavelryYarnScreen;
import 'landing_scaffold.dart';
// LandingFeatureScaffold re-exported from landing_scaffold.dart

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
    id: 'ai-pattern-converter',
    icon: Icons.auto_awesome_rounded,
    title: 'AI 도안 변환기',
    tagline: 'PDF·이미지 도안을 단계별로 자동 변환 ✨',
    color: Color(0xFF818CF8),
    description: '종이 도안이나 PDF를 사진으로 찍으면 AI가 단계별 지시사항으로 바꿔드려요. '
        '복잡한 영문 도안도, 스캔된 오래된 도안도 모두 따라하기 쉬운 단계로 변환됩니다. '
        '변환된 도안은 나의 도안 라이브러리에 자동 저장돼요.',
    highlights: [
      'PDF·JPG·PNG 모두 지원',
      '한국어·영어 도안 모두 인식',
      '섹션별 단계로 자동 구조화',
      '나의 도안 라이브러리에 자동 저장',
    ],
    steps: [
      (Icons.upload_file_rounded, '도안 업로드', 'PDF 또는 이미지 도안 파일을 선택해요.'),
      (Icons.auto_fix_high_rounded, 'AI 자동 분석', 'AI가 도안을 읽고 단계별 지시사항으로 변환해요.'),
      (Icons.check_circle_outline_rounded, '라이브러리 저장', '변환된 도안이 나의 도안 라이브러리에 자동 저장돼요.'),
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
  FeatureInfo(
    id: 'pattern-editor',
    icon: Icons.grid_on_rounded,
    title: '도안 에디터',
    tagline: '그리드 도안을 직접 설계하고 디지털로 완성',
    color: Color(0xFFC084FC),
    description: '코 단위 그리드 위에서 색상과 기호를 배치해 나만의 도안을 만드세요. '
        '컬러차트 모드와 기호 모드를 전환하며 편집하고, 반복 구간·게이지·RS/WS 방향까지 설정할 수 있어요. '
        '완성된 도안은 PDF로 저장하거나 마켓에 바로 등록할 수 있습니다.',
    highlights: [
      '컬러차트 & 기호 모드 전환',
      '반복 구간(Repeat Region) 마커',
      '게이지 연동 치수 자동 계산',
      'RS/WS 독해 방향 가이드',
      'PDF 저장 & 마켓 등록',
    ],
    steps: [
      (Icons.grid_on_rounded, '그리드 설정', '코수·단수를 입력해 도안 그리드를 만들어요.'),
      (Icons.palette_rounded, '디자인', '색상과 기호를 배치해 패턴을 완성해요.'),
      (Icons.picture_as_pdf_rounded, '저장 & 공유', 'PDF로 저장하거나 마켓에 등록해요.'),
    ],
  ),
  FeatureInfo(
    id: 'counter',
    icon: Icons.track_changes_rounded,
    title: '카운터 & 트래커',
    tagline: '단수 카운터와 실시간 행 트래커로 진행 관리',
    color: Color(0xFF34D399),
    description: '뜨개 중 단수를 놓치지 않도록 카운터가 도와드려요. '
        '도안 위에 실시간으로 현재 행을 표시하는 트래커와 구간 측정 기능으로 '
        '어느 단계에 있는지 한눈에 확인할 수 있습니다.',
    highlights: [
      '단수 카운터 (+ / - 조작)',
      '도안 위 실시간 행 트래커',
      '구간별 단수 기록',
      '진행률 시각화',
    ],
    steps: [
      (Icons.add_circle_outline_rounded, '카운터 시작', '프로젝트에서 카운터를 열어요.'),
      (Icons.touch_app_rounded, '단수 기록', '한 단을 뜰 때마다 탭해서 카운트해요.'),
      (Icons.bar_chart_rounded, '진행 확인', '전체 진행률과 구간 기록을 확인해요.'),
    ],
  ),
  FeatureInfo(
    id: 'measure',
    icon: Icons.square_foot_rounded,
    title: '측정 도구',
    tagline: '구간 측정·목표 길이 계산·게이지 보정을 한 화면에서',
    color: Color(0xFFFB923C),
    description: '뜨개 중 치수를 정확하게 관리할 수 있도록 측정 도구를 제공해요. '
        '현재까지 뜬 길이, 목표까지 남은 단수, 게이지 보정 수치를 '
        '한 화면에서 실시간으로 계산합니다.',
    highlights: [
      '구간 측정 (시작~현재 단수 → cm 변환)',
      '목표 길이 역산 (몇 단 더 뜨면 되는지)',
      '게이지 보정 계산',
      '측정 기록 히스토리',
    ],
    steps: [
      (Icons.input_rounded, '게이지 입력', '10cm 기준 단수를 입력해요.'),
      (Icons.straighten_rounded, '구간 설정', '측정할 시작·끝 단수를 지정해요.'),
      (Icons.check_circle_outline_rounded, '결과 확인', '길이(cm)와 남은 단수가 즉시 계산돼요.'),
    ],
  ),
  FeatureInfo(
    id: 'ai-translator',
    icon: Icons.translate_rounded,
    title: 'AI 영문 도안 번역기',
    tagline: '영문 뜨개 도안을 한국어로 자동 번역 ✨',
    color: Color(0xFF38BDF8),
    description: 'k2tog, ssk, m1l, yo 같은 영문 뜨개 약어를 포함한 도안 전체를 '
        'AI가 뜨개 전문 용어로 정확하게 번역합니다. '
        '단순 번역이 아닌, 뜨개 문맥을 이해한 전문 번역이라 그대로 따라할 수 있어요.',
    highlights: [
      '뜨개 약어 자동 인식 (k2tog, ssk, yo 등)',
      '단계별 구조 유지 번역',
      '영문 → 한국어 전문 용어 매핑',
      '번역 결과 도안 라이브러리 저장',
    ],
    steps: [
      (Icons.upload_file_rounded, '도안 입력', '영문 도안 텍스트 또는 이미지를 붙여넣어요.'),
      (Icons.auto_fix_high_rounded, 'AI 번역', 'AI가 뜨개 전문 용어로 정확하게 번역해요.'),
      (Icons.save_alt_rounded, '저장 & 활용', '번역된 도안을 저장하고 바로 활용해요.'),
    ],
  ),
  FeatureInfo(
    id: 'cloud-sync',
    icon: Icons.cloud_sync_rounded,
    title: '클라우드 연결',
    tagline: 'Dropbox·Google Drive와 도안·파일 연동',
    color: Color(0xFF60A5FA),
    description: 'Dropbox 또는 Google Drive에 저장된 도안 파일을 모리니트 앱에서 바로 불러오세요. '
        '저장된 PDF 도안, 사진, 참고 파일을 클라우드에서 직접 연결해 '
        '프로젝트에 첨부할 수 있어요. 기기 간 파일 공유도 쉬워집니다.',
    highlights: [
      'Dropbox 파일 직접 연결',
      'Google Drive 파일 불러오기',
      '도안 PDF 클라우드 첨부',
      '기기 간 자동 동기화',
    ],
    steps: [
      (Icons.link_rounded, '클라우드 연결', 'Dropbox 또는 Google Drive 계정을 연동해요.'),
      (Icons.folder_open_rounded, '파일 선택', '클라우드에서 도안 파일을 선택해요.'),
      (Icons.attach_file_rounded, '프로젝트 첨부', '선택한 파일을 프로젝트에 바로 첨부해요.'),
    ],
  ),
  // ── #656 Wave 2 ─ 신규 기능 6종 ──────────────────────────────────────────────
  FeatureInfo(
    id: 'pattern-viewer',
    icon: Icons.menu_book_outlined,
    title: '도안 뷰어',
    tagline: '차트·서술형을 한 화면에서, 단계별 트래킹까지',
    color: Color(0xFF8B5CF6),
    description: '복잡한 도안을 차트와 서술형으로 함께 보며 따라할 수 있어요. '
        '현재 단을 자동 추적하는 트래킹바, 차트와 서술형을 동시에 보는 분할 모드, '
        '단별 메모와 표시까지 — 종이 도안에선 불가능한 디지털 도안 전용 경험을 제공해요.',
    highlights: [
      '차트 + 서술형 동시 보기 (분할 모드)',
      '실시간 단 트래킹바와 헤어라인 표시',
      '반복 구간(Repeat) 자동 인식 안내',
      '단별 메모·체크·즐겨찾기',
    ],
    steps: [
      (Icons.folder_open_rounded, '도안 선택', '라이브러리에서 보고 싶은 도안을 열어요.'),
      (Icons.swap_horiz_rounded, '뷰 모드 전환', '차트·서술형·분할 모드를 자유롭게 전환해요.'),
      (Icons.track_changes_rounded, '단 트래킹', '현재 단을 표시해 다음 단을 헷갈리지 않아요.'),
    ],
  ),
  FeatureInfo(
    id: 'pattern-library',
    icon: Icons.library_books_rounded,
    title: '도안 라이브러리',
    tagline: '내 도안을 한 곳에 보관·정리·Fork',
    color: Color(0xFF3B82F6),
    description: '직접 만든 도안, 마켓에서 구매한 도안, AI로 변환한 도안을 한 곳에 모아 관리하세요. '
        '카테고리·태그로 정리하고, 마음에 드는 도안은 Fork 해서 나만의 버전으로 수정할 수 있어요.',
    highlights: [
      '내 도안·구매 도안·AI 변환 도안 통합 보관',
      '카테고리·태그·즐겨찾기 정리',
      'Fork — 다른 도안을 내 버전으로 복제',
      '도안 상태(draft / complete) 관리',
    ],
    steps: [
      (Icons.add_circle_outline_rounded, '도안 등록', '파일·클라우드·에디터로 도안을 추가해요.'),
      (Icons.category_rounded, '분류 정리', '카테고리와 태그로 라이브러리를 정돈해요.'),
      (Icons.fork_right_rounded, 'Fork & 편집', '마음에 드는 도안을 복제해 내 버전으로 만들어요.'),
    ],
  ),
  FeatureInfo(
    id: 'yarn',
    icon: Icons.color_lens_rounded,
    title: '실 보관함',
    tagline: '브랜드·굵기·색상별로 내 실을 한눈에',
    color: Color(0xFFEF4444),
    description: '집에 쌓여있는 실(Stash)을 디지털로 정리하세요. '
        '브랜드, 굵기, 그램, 야드, 색상, 구매처를 기록하면 다음 프로젝트에 어떤 실을 쓸지 바로 결정할 수 있어요. '
        'Ravelry 스태시 동기화로 기존 데이터를 한 번에 옮길 수도 있습니다.',
    highlights: [
      '브랜드·굵기·색상·잔량 기록',
      '그램·야드 단위 자동 환산',
      '실 사진 갤러리',
      'Ravelry 스태시 자동 동기화',
    ],
    steps: [
      (Icons.add_a_photo_rounded, '실 등록', '실 사진과 라벨 정보를 입력해요.'),
      (Icons.sort_rounded, '정리', '브랜드·굵기·색상별로 분류해요.'),
      (Icons.link_rounded, '프로젝트 연결', '프로젝트에 사용한 실을 자동 연결해요.'),
    ],
  ),
  FeatureInfo(
    id: 'needle',
    icon: Icons.linear_scale_rounded,
    title: '바늘 보관함',
    tagline: '대바늘·코바늘을 사이즈·재질별로 관리',
    color: Color(0xFF6B7280),
    description: '집에 있는 대바늘과 코바늘을 디지털로 보관하세요. '
        '사이즈, 길이, 재질(나무·금속·대나무)별로 정리하면 다음 프로젝트에 필요한 바늘을 바로 찾을 수 있어요. '
        '중복 구매도 막아주는 똑똑한 도구함이에요.',
    highlights: [
      '대바늘·코바늘·줄바늘 통합 관리',
      '사이즈(mm)·길이·재질 기록',
      '바늘 사진 첨부',
      '프로젝트에 사용 중인 바늘 표시',
    ],
    steps: [
      (Icons.add_circle_outline_rounded, '바늘 등록', '바늘 사이즈와 재질, 사진을 입력해요.'),
      (Icons.straighten_rounded, '분류 보기', '사이즈별·재질별로 한눈에 정리해요.'),
      (Icons.check_circle_outline_rounded, '사용 중 표시', '프로젝트에 쓰고 있는 바늘을 표시해요.'),
    ],
  ),
  FeatureInfo(
    id: 'book',
    icon: Icons.auto_stories_rounded,
    title: '뜨개 도서',
    tagline: '뜨개 책과 잡지를 디지털 책장으로',
    color: Color(0xFF92400E),
    description: '소장 중인 뜨개 책, 잡지, 디지털 도서를 한 곳에 정리하세요. '
        '제목·저자·출판사·구매처를 기록하고 표지 사진을 첨부해 나만의 디지털 책장을 만들 수 있어요. '
        '책 속 도안을 직접 등록한 도안과 연결할 수도 있어요.',
    highlights: [
      '제목·저자·출판사·ISBN 기록',
      '표지 사진 갤러리',
      '책 속 도안 → 내 도안 연결',
      '카테고리(스웨터·소품·전통기법) 분류',
    ],
    steps: [
      (Icons.add_a_photo_rounded, '책 등록', '책 표지를 찍고 정보를 입력해요.'),
      (Icons.bookmark_add_rounded, '도안 연결', '책 속 도안을 라이브러리와 연결해요.'),
      (Icons.shelves, '책장 정리', '카테고리별로 디지털 책장을 정돈해요.'),
    ],
  ),
  FeatureInfo(
    id: 'accessory',
    icon: Icons.handyman_rounded,
    title: '악세서리',
    tagline: '마커·가위·게이지자 등 뜨개 도구를 모두 관리',
    color: Color(0xFFEC4899),
    description: '마커, 가위, 게이지자, 코바늘 보호캡, 줄자 등 뜨개에 필요한 자잘한 도구들을 한 곳에 정리하세요. '
        '어디에 두었는지, 몇 개 있는지 헷갈리지 않게 사진과 수량으로 관리할 수 있어요.',
    highlights: [
      '도구 종류·수량·보관 위치 기록',
      '도구 사진 첨부',
      '프로젝트별 사용 도구 표시',
      '필요 도구 체크리스트',
    ],
    steps: [
      (Icons.add_a_photo_rounded, '도구 등록', '도구 사진을 찍고 종류·수량을 입력해요.'),
      (Icons.inventory_2_rounded, '보관함 정리', '종류별로 모아 한눈에 확인해요.'),
      (Icons.checklist_rounded, '체크리스트', '프로젝트에 필요한 도구를 체크해요.'),
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

// ── 폰 목업 데모 위젯 ──────────────────────────────────────────────────────────
// #609 — 우선순위: 라이브 위젯(히어로와 동일) > Firestore 이미지 > 단계 카드 폴백
Widget? _liveMockupForFeature(String id) {
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
    // ── #656 Wave 2 ─ 신규 6종 라이브 매핑 (가능한 기존 위젯 재사용) ────────────
    'pattern-viewer' => const MockPatternEditorExtendedScreen(),
    'pattern-library' => const MockMarketScreen(),
    'yarn' => const MockRavelryYarnScreen(),
    // needle / book / accessory 는 라이브 위젯 없음 → 폴백 _PhoneMockupContent 사용
    _ => null,
  };
}

class _PhoneMockup extends ConsumerWidget {
  final FeatureInfo feature;
  const _PhoneMockup({required this.feature});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #609 — 라이브 위젯 우선 (사용자 요구: 히어로와 동일한 코드)
    final live = _liveMockupForFeature(feature.id);
    final mockupImages = ref.watch(mockupImagesProvider).valueOrNull ?? {};
    final imageUrl = mockupImages[feature.id] ?? '';

    final Widget inner = live ??
        (imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _PhoneMockupContent(feature: feature))
            : _PhoneMockupContent(feature: feature));

    return Center(
      child: Container(
        width: 240,
        height: 460,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 3),
          boxShadow: [
            BoxShadow(color: feature.color.withValues(alpha: 0.35), blurRadius: 48, spreadRadius: 4),
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(33),
          child: inner,
        ),
      ),
    );
  }
}

class _PhoneMockupContent extends StatelessWidget {
  final FeatureInfo feature;
  const _PhoneMockupContent({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Column(
            children: [
              // 상단 노치
              Container(
                height: 28,
                color: const Color(0xFF0D0D1A),
                alignment: Alignment.center,
                child: Container(
                  width: 64,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222233),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              // 앱 콘텐츠
              Expanded(
                child: Container(
                  color: const Color(0xFF12122A),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 앱 헤더 바
                      Row(children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: feature.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(feature.icon, color: feature.color, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature.title,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      // 단계별 데모 카드
                      ...feature.steps.asMap().entries.map((e) {
                        final i = e.key;
                        final (icon, title, desc) = e.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C38),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: feature.color.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: feature.color.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(child: Text('${i + 1}', style: TextStyle(color: feature.color, fontSize: 10, fontWeight: FontWeight.w800))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                    Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Spacer(),
                      // 하단 액션 버튼
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [feature.color.withValues(alpha: 0.85), feature.color]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('시작하기', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 홈 인디케이터
              Container(
                height: 24,
                color: const Color(0xFF0D0D1A),
                alignment: Alignment.center,
                child: Container(
                  width: 72,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
  }
}

class _FeatureDetailPage extends StatelessWidget {
  final FeatureInfo feature;
  const _FeatureDetailPage({required this.feature});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    const maxWidth = 1100.0;
    const contentMaxWidth = 860.0;
    final isWide = width >= 860;

    return LandingFeatureScaffold(
      backgroundColor: const Color(0xFFF9F5FF),
      slivers: [
          // ── 기능 타이틀 서브바 ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxWidth),
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
          // ── 히어로: 좌(설명) + 우(목업 데모) ─────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A1A2E),
              padding: EdgeInsets.fromLTRB(20, isWide ? 56 : 40, 20, isWide ? 64 : 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxWidth),
                  child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── 좌: 목업 + 설명 ──────────────────────────────────
                          Expanded(
                            flex: 4,
                            child: _PhoneMockup(feature: feature),
                          ),
                          const SizedBox(width: 56),
                          // ── 우: 기능 데모 (설명 + 하이라이트) ─────────────────
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: feature.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: feature.color.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(feature.tagline, style: TextStyle(color: feature.color, fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  feature.title,
                                  style: TextStyle(color: Colors.white, fontSize: width >= 1000 ? 38 : 28, fontWeight: FontWeight.w800, height: 1.2),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  feature.description,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 15, height: 1.75),
                                ),
                                const SizedBox(height: 28),
                                // 주요 기능 하이라이트 (우측 데모 패널 내)
                                ...feature.highlights.map((h) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: feature.color.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.check_rounded, color: feature.color, size: 13),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(h, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85), height: 1.5)),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // 내로우: 텍스트 먼저, 목업 아래
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
                          const SizedBox(height: 16),
                          Text(
                            feature.title,
                            style: TextStyle(color: Colors.white, fontSize: width >= 600 ? 30 : 24, fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feature.tagline,
                            style: TextStyle(color: feature.color, fontSize: 14, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            feature.description,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 14, height: 1.7),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 36),
                          _PhoneMockup(feature: feature),
                        ],
                      ),
                ),
              ),
            ),
          ),
          // ── 주요 기능 하이라이트 (내로우 전용 — 와이드는 히어로 우측에 포함) ────
          if (!isWide)
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
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
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
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
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
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
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
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
        ],
    );
  }
}
