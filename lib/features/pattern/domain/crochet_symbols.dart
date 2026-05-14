/// 코바늘(crochet) 도안 기호 30종 — Firebase Storage SVG + Firestore encyclopedia 매핑
///
/// 데이터 출처
/// - Firestore: encyclopedia 컬렉션 (craftType='crochet', order 1001~1030)
/// - Storage:   gs://moriknit-ceea9.firebasestorage.app/crochet_symbols/{filename}.svg
///
/// 회귀 방지 — 검증 완료(2026-04-26)
/// - Firestore craftType=crochet 항목: 30개 확정
/// - Storage 실제 SVG 파일: 25개 확정 (5개 항목은 텍스트 약어로만 표시)
/// - 미보유 SVG 5종: trtr / 3ch_arch / 5ch_arch / bobble / inc / dec / ch_sp 중 일부 (firebaseUrl 빈값)
///
/// 도안 에디터 팔레트 즉시 사용 가능. 대바늘(KnitSymbol) 60종과 분리 운영.
library;

/// 코바늘 카테고리 — 도안 에디터 팔레트 그룹화에 사용
enum CrochetCategory {
  /// 기초코 (체인·빼뜨기·짧은뜨기·긴뜨기 계열)
  basic,

  /// 코 줄이기 (sc2tog, dc3tog 등)
  decrease,

  /// 코 늘리기 (inc 계열)
  increase,

  /// 특수·장식 코 (퍼프·셸·팝콘·교차·앞뒷기둥·앞뒷고리뜨기 등)
  special,

  /// 가장자리·공간 (사슬 아치·매직링·연결·사슬 공간)
  edge,
}

/// 코바늘 기호 1종을 표현. 도안 에디터 팔레트·서술형 변환·SVG 렌더링에 공통 사용
class CrochetSymbol {
  /// 내부 식별자 (snake_case, 예: 'ch', 'sl_st', 'sc2tog')
  final String id;

  /// 한글 라벨 (예: '사슬뜨기', '짧은뜨기')
  final String labelKo;

  /// 영어 라벨 (예: 'Chain', 'Single Crochet')
  final String labelEn;

  /// 약어 (Firestore의 abbreviation 필드와 일치, 예: 'ch', 'sc', 'sc2tog')
  final String abbreviation;

  /// Storage 내 SVG 파일명 (확장자 제외, 예: 'chain', 'sc2tog'). SVG가 없으면 빈 문자열
  final String svgFileName;

  /// Firebase Storage 다운로드 URL (전체). SVG가 없으면 빈 문자열
  final String firebaseUrl;

  /// 카테고리
  final CrochetCategory category;

  /// 자동 회전 가능 여부 (방향성 있는 기호만 true) — 현재 코바늘은 모두 false
  final bool rotatable;

  /// Firestore encyclopedia 문서 ID (검증 완료된 실제 docId)
  final String firestoreDocId;

  /// 정렬 순서 (Firestore order 필드와 일치, 1001~1030)
  final int order;

  const CrochetSymbol({
    required this.id,
    required this.labelKo,
    required this.labelEn,
    required this.abbreviation,
    required this.svgFileName,
    required this.firebaseUrl,
    required this.category,
    required this.firestoreDocId,
    required this.order,
    this.rotatable = false,
  });

  /// SVG가 Firebase Storage에 실제로 존재하는지 여부
  bool get hasSvg => firebaseUrl.isNotEmpty;
}

/// Firebase Storage URL 형식 (회귀 방지 — 형식 절대 변경 금지)
/// `https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2F{filename}.svg?alt=media`
///
/// 코바늘 기호 30종 — order 순(1001~1030) 정렬
const List<CrochetSymbol> kCrochetSymbols = [
  // ── BASIC (8종) ─────────────────────────────────────────────────────────
  CrochetSymbol(
    id: 'ch',
    labelKo: '사슬뜨기',
    labelEn: 'Chain',
    abbreviation: 'ch',
    svgFileName: 'chain',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fchain.svg?alt=media',
    category: CrochetCategory.basic,
    firestoreDocId: '88DE5AUxFXo74TEDjKIw',
    order: 1001,
  ),
  CrochetSymbol(
    id: 'sl_st',
    labelKo: '빼뜨기',
    labelEn: 'Slip Stitch',
    abbreviation: 'sl st',
    svgFileName: 'slipstitch',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fslipstitch.svg?alt=media',
    category: CrochetCategory.basic,
    firestoreDocId: 'k22rOFkrSBwqC7W0BGIP',
    order: 1002,
  ),
  CrochetSymbol(
    id: 'sc',
    labelKo: '짧은뜨기',
    labelEn: 'Single Crochet',
    abbreviation: 'sc',
    svgFileName: 'sc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fsc.svg?alt=media',
    category: CrochetCategory.basic,
    firestoreDocId: 'rFdd5nNSQteufCNKCdHm',
    order: 1003,
  ),
  CrochetSymbol(
    id: 'hdc',
    labelKo: '반 긴뜨기',
    labelEn: 'Half Double Crochet',
    abbreviation: 'hdc',
    svgFileName: 'hdc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fhdc.svg?alt=media',
    category: CrochetCategory.basic,
    firestoreDocId: 'lUQwkZPX2piJ8vQZVqWD',
    order: 1004,
  ),
  CrochetSymbol(
    id: 'dc',
    labelKo: '긴뜨기',
    labelEn: 'Double Crochet',
    abbreviation: 'dc',
    svgFileName: 'dc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fdc.svg?alt=media',
    category: CrochetCategory.basic,
    firestoreDocId: '05NQoyKUUPNDPpLgm37y',
    order: 1005,
  ),
  CrochetSymbol(
    id: 'tr',
    labelKo: '한길 긴뜨기',
    labelEn: 'Treble Crochet',
    abbreviation: 'tr',
    svgFileName: 'tr',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Ftr.svg?alt=media',
    category: CrochetCategory.basic,
    firestoreDocId: 'DKp5jqlCg2Q1s0MoiEir',
    order: 1006,
  ),
  CrochetSymbol(
    id: 'dtr',
    labelKo: '두길 긴뜨기',
    labelEn: 'Double Treble Crochet',
    abbreviation: 'dtr',
    svgFileName: 'dtr',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fdtr.svg?alt=media',
    category: CrochetCategory.basic,
    firestoreDocId: 'iS5VfzSuIRwaNtYmgPm1',
    order: 1007,
  ),
  // SVG 미보유 — 약어 텍스트로 표시
  CrochetSymbol(
    id: 'trtr',
    labelKo: '세길 긴뜨기',
    labelEn: 'Treble Treble Crochet',
    abbreviation: 'tr tr',
    svgFileName: '',
    firebaseUrl: '',
    category: CrochetCategory.basic,
    firestoreDocId: 'tgyvLnkOJJq1tQw8rbe1',
    order: 1008,
  ),

  // ── DECREASE (4종) ──────────────────────────────────────────────────────
  CrochetSymbol(
    id: 'sc2tog',
    labelKo: '짧은뜨기 2코 모아뜨기',
    labelEn: 'Single Crochet 2 Together',
    abbreviation: 'sc2tog',
    svgFileName: 'sc2tog',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fsc2tog.svg?alt=media',
    category: CrochetCategory.decrease,
    firestoreDocId: 'INk2Sm0UWndGB9yqOfIN',
    order: 1009,
  ),
  CrochetSymbol(
    id: 'sc3tog',
    labelKo: '짧은뜨기 3코 모아뜨기',
    labelEn: 'Single Crochet 3 Together',
    abbreviation: 'sc3tog',
    svgFileName: 'sc3tog',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fsc3tog.svg?alt=media',
    category: CrochetCategory.decrease,
    firestoreDocId: 'UmSwKnLR9yH4j7G7CB5n',
    order: 1010,
  ),
  CrochetSymbol(
    id: 'dc2tog',
    labelKo: '긴뜨기 2코 모아뜨기',
    labelEn: 'Double Crochet 2 Together',
    abbreviation: 'dc2tog',
    svgFileName: 'dc2tog',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fdc2tog.svg?alt=media',
    category: CrochetCategory.decrease,
    firestoreDocId: 'tv7STnytAQCg9sDMZKg4',
    order: 1011,
  ),
  CrochetSymbol(
    id: 'dc3tog',
    labelKo: '긴뜨기 3코 모아뜨기',
    labelEn: 'Double Crochet 3 Together',
    abbreviation: 'dc3tog',
    svgFileName: 'dc3tog',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fdc3tog.svg?alt=media',
    category: CrochetCategory.decrease,
    firestoreDocId: 'cVr1mAF4O87kgQrVxILo',
    order: 1012,
  ),

  // ── SPECIAL (11종) ──────────────────────────────────────────────────────
  CrochetSymbol(
    id: 'crossed_dc',
    labelKo: '긴뜨기 2코 교차',
    labelEn: '2 Crossed Double Crochet',
    abbreviation: 'crossed dc',
    svgFileName: 'crossed_dc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fcrossed_dc.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'MjONZyyXHZL9ZfID1QjN',
    order: 1013,
  ),
  CrochetSymbol(
    id: 'fpdc',
    labelKo: '앞기둥 긴뜨기',
    labelEn: 'Front Post Double Crochet',
    abbreviation: 'FPdc',
    svgFileName: 'fpdc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Ffpdc.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'EvU0X0NaC74Oij4jrFko',
    order: 1014,
  ),
  CrochetSymbol(
    id: 'bpdc',
    labelKo: '뒷기둥 긴뜨기',
    labelEn: 'Back Post Double Crochet',
    abbreviation: 'BPdc',
    svgFileName: 'bpdc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fbpdc.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'brKlXGZmNs9RNOQBytEG',
    order: 1015,
  ),
  CrochetSymbol(
    id: 'blo',
    labelKo: '뒷고리 뜨기',
    labelEn: 'Back Loop Only',
    abbreviation: 'BLO',
    svgFileName: 'blo',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fblo.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'LAcWERzxagcONnnyKybT',
    order: 1016,
  ),
  CrochetSymbol(
    id: 'flo',
    labelKo: '앞고리 뜨기',
    labelEn: 'Front Loop Only',
    abbreviation: 'FLO',
    svgFileName: 'flo',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fflo.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'hHnFOOLRtyziMu684aSl',
    order: 1017,
  ),
  CrochetSymbol(
    id: 'picot',
    labelKo: '피코',
    labelEn: 'Picot',
    abbreviation: 'picot',
    svgFileName: 'ch3_picot',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fch3_picot.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'vGioyOyt323LAZpaRweR',
    order: 1020,
  ),
  CrochetSymbol(
    id: '3dc_cluster',
    labelKo: '긴뜨기 클러스터',
    labelEn: '3 Double Crochet Cluster',
    abbreviation: '3dc-cl',
    svgFileName: 'cluster_dc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fcluster_dc.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'A8vBjrA7ts0YWG0yJevE',
    order: 1021,
  ),
  CrochetSymbol(
    id: 'puff',
    labelKo: '퍼프 스티치',
    labelEn: 'Puff Stitch',
    abbreviation: 'puff',
    svgFileName: 'puff_hdc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fpuff_hdc.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'CDncDHch2HpWRCPWHKaz',
    order: 1022,
  ),
  // SVG 미보유 — 약어 텍스트로 표시
  CrochetSymbol(
    id: 'bobble',
    labelKo: '버블 스티치',
    labelEn: 'Bobble Stitch',
    abbreviation: 'bobble',
    svgFileName: '',
    firebaseUrl: '',
    category: CrochetCategory.special,
    firestoreDocId: 'ImY7kQhE149MmdOhgDjG',
    order: 1023,
  ),
  CrochetSymbol(
    id: 'popcorn',
    labelKo: '팝콘 스티치',
    labelEn: 'Popcorn Stitch',
    abbreviation: 'pc',
    svgFileName: 'popcorn_dc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fpopcorn_dc.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'ckEeJKXLTIm5OlFY3sib',
    order: 1024,
  ),
  CrochetSymbol(
    id: 'shell',
    labelKo: '쉘 스티치',
    labelEn: 'Shell Stitch',
    abbreviation: 'sh',
    svgFileName: 'shell_dc',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fshell_dc.svg?alt=media',
    category: CrochetCategory.special,
    firestoreDocId: 'hwO3tHWXuwGRjFs2ws24',
    order: 1025,
  ),

  // ── EDGE (5종) — 가장자리·공간·연결 ─────────────────────────────────────
  // SVG 미보유 — 약어 텍스트로 표시
  CrochetSymbol(
    id: '3ch_arch',
    labelKo: '사슬 3코 아치',
    labelEn: '3 Chain Arch',
    abbreviation: 'ch-3 sp',
    svgFileName: '',
    firebaseUrl: '',
    category: CrochetCategory.edge,
    firestoreDocId: 'cDfCs45yamvSZWlLKWe2',
    order: 1018,
  ),
  CrochetSymbol(
    id: '5ch_arch',
    labelKo: '사슬 5코 아치',
    labelEn: '5 Chain Arch',
    abbreviation: 'ch-5 sp',
    svgFileName: '',
    firebaseUrl: '',
    category: CrochetCategory.edge,
    firestoreDocId: 'dfQvuORMRZvid915dRPK',
    order: 1019,
  ),
  CrochetSymbol(
    id: 'magic_ring',
    labelKo: '매직링',
    labelEn: 'Magic Ring',
    abbreviation: 'MR',
    svgFileName: 'magic_ring',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fmagic_ring.svg?alt=media',
    category: CrochetCategory.edge,
    firestoreDocId: 'NcnBQhrQw2UZ6UeX94X3',
    order: 1026,
  ),
  CrochetSymbol(
    id: 'join_rnd',
    labelKo: '원형 연결',
    labelEn: 'Joining Round',
    abbreviation: 'join',
    svgFileName: 'joining_bar',
    firebaseUrl:
        'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/crochet_symbols%2Fjoining_bar.svg?alt=media',
    category: CrochetCategory.edge,
    firestoreDocId: 'jmLmg0VvUo5EDd2H1IxQ',
    order: 1027,
  ),
  // SVG 미보유 — 약어 텍스트로 표시
  CrochetSymbol(
    id: 'ch_sp',
    labelKo: '사슬 공간',
    labelEn: 'Chain Space',
    abbreviation: 'ch-sp',
    svgFileName: '',
    firebaseUrl: '',
    category: CrochetCategory.edge,
    firestoreDocId: 'GSrncQAKoQLxADkOQYax',
    order: 1030,
  ),

  // ── INCREASE / DECREASE 일반 — SVG 미보유, 약어 텍스트로 표시 ───────────
  CrochetSymbol(
    id: 'inc',
    labelKo: '코 늘리기',
    labelEn: 'Increase',
    abbreviation: 'inc',
    svgFileName: '',
    firebaseUrl: '',
    category: CrochetCategory.increase,
    firestoreDocId: 'Br2LLkiWQAUXQWGLK9Tc',
    order: 1028,
  ),
  CrochetSymbol(
    id: 'dec',
    labelKo: '코 줄이기',
    labelEn: 'Decrease',
    abbreviation: 'dec',
    svgFileName: '',
    firebaseUrl: '',
    category: CrochetCategory.decrease,
    firestoreDocId: '5SbsOIFPCqWN9BvbK4yI',
    order: 1029,
  ),
];

/// 코바늘 기호 라이브러리 — 도안 에디터 팔레트·검색·매핑 헬퍼 모음
class CrochetSymbolLibrary {
  const CrochetSymbolLibrary._();

  /// 전체 30종
  static const List<CrochetSymbol> all = kCrochetSymbols;

  /// 카테고리별 필터링 (팔레트 그룹화에 사용)
  static List<CrochetSymbol> byCategory(CrochetCategory cat) =>
      all.where((s) => s.category == cat).toList();

  /// id로 단건 조회
  static CrochetSymbol? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 약어로 단건 조회 (대소문자 무시)
  static CrochetSymbol? byAbbreviation(String abbr) {
    final target = abbr.trim().toLowerCase();
    for (final s in all) {
      if (s.abbreviation.toLowerCase() == target) return s;
    }
    return null;
  }

  /// SVG 보유 여부 통계 (디버깅/검증용)
  static int get withSvgCount => all.where((s) => s.hasSvg).length;
  static int get withoutSvgCount => all.where((s) => !s.hasSvg).length;

  /// 카테고리 라벨 (한글) — 팔레트 헤더 표시용
  static String categoryLabelKo(CrochetCategory cat) {
    switch (cat) {
      case CrochetCategory.basic:
        return '기초';
      case CrochetCategory.decrease:
        return '줄임';
      case CrochetCategory.increase:
        return '늘림';
      case CrochetCategory.special:
        return '특수·장식';
      case CrochetCategory.edge:
        return '가장자리·공간';
    }
  }

  /// 카테고리 라벨 (영어)
  static String categoryLabelEn(CrochetCategory cat) {
    switch (cat) {
      case CrochetCategory.basic:
        return 'Basic';
      case CrochetCategory.decrease:
        return 'Decrease';
      case CrochetCategory.increase:
        return 'Increase';
      case CrochetCategory.special:
        return 'Special';
      case CrochetCategory.edge:
        return 'Edge & Space';
    }
  }
}
