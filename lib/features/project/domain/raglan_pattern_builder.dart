// lib/features/project/domain/raglan_pattern_builder.dart
//
// 이슈 #637 — 래글런 탑다운 빌트인 템플릿을 완전한 PatternChart 객체로 빌드.
//
// Banul "메리노블렌드 DK 트위드 크롭 레글런 탑다운 스웨터" 도안의
// 사이즈별 수치를 PatternChart(서술형 블록 + AI 섹션 + 반복구간 + 래글런 늘림 차트)로
// 완벽히 디지털화합니다.
//
// 사용 예:
//   final chart = buildPatternChartFromRaglanTemplate(banulCropRaglanDk, 'XS');
//   // chart.isComplete == true, 도안에디터에서 열어 바로 편집 가능.
//
// 설계:
//   - 12개 AiSection (목코잡기 ~ 마무리) + 각 섹션에 연결된 NarrativeBlock 리스트
//   - 2×20 반복 단위 차트 (래글런 늘림 2단 패턴: 늘림단 + 평단)
//   - RepeatRegion 으로 raglanRepeat 횟수 표시
//   - ChartMode.symbol, KnittingDirection.inTheRound, GaugeInfo 21/29
//
// 중요: 호출자가 PatternChart.id 를 부여한 뒤 저장. 빌더는 id='' 상태로 반환.

import 'package:uuid/uuid.dart';

import '../../pattern/domain/ai_pattern_section.dart';
import '../../pattern/domain/narrative_block.dart';
import '../../pattern/domain/pattern_chart.dart';
import 'raglan_template.dart';

// ─────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────

/// 빌트인 레글런 템플릿 + 사이즈 → 완전한 PatternChart.
///
/// 반환 PatternChart.isComplete == true (섹션 12개 + 연결 블록).
/// 호출자가 id/createdAt/linkedProjectId 등을 copyWith 로 채워 저장.
PatternChart buildPatternChartFromRaglanTemplate(
  RaglanTopdownTemplate tmpl,
  String sizeName, {
  bool isKorean = true,
}) {
  final size = tmpl.sizes.firstWhere(
    (s) => s.name == sizeName,
    orElse: () => throw ArgumentError(
      'Size "$sizeName" not found in template "${tmpl.id}". '
      'Available: ${tmpl.sizes.map((s) => s.name).join(', ')}',
    ),
  );

  final sectionsBuilder = _SectionsBuilder(tmpl: tmpl, size: size);
  final sections = sectionsBuilder.buildSections();
  final blocks = sectionsBuilder.buildBlocks(sections);

  final repeatUnit = _buildRaglanRepeatChart();
  final repeatRegion = RepeatRegion.create(
    startRow: 0,
    startCol: 0,
    endRow: repeatUnit.rows - 1,
    endCol: repeatUnit.cols - 1,
    repeatCount: size.raglanRepeat,
    label: 'Raglan increase',
    labelKo: '래글런 늘림',
  );

  final title = '${tmpl.nameKo} — $sizeName 사이즈';

  return PatternChart(
    id: '',
    title: title,
    rows: repeatUnit.rows,
    cols: repeatUnit.cols,
    mode: ChartMode.symbol,
    grid: repeatUnit.grid,
    narrativeText: NarrativeBlock.toText(blocks),
    sourceType: PatternSourceType.editor,
    aiSections: sections,
    knittingDirection: KnittingDirection.inTheRound,
    gauge: GaugeInfo(
      stitchesPer10cm: tmpl.referenceStitchGauge,
      rowsPer10cm: tmpl.referenceRowGauge,
    ),
    repeatRegions: [repeatRegion],
    narrativeBlocks: blocks,
  );
}

/// XS 사이즈 빌드 결과를 요약 텍스트로 덤프 (디버깅용).
String dumpPatternChartSummary(PatternChart chart, bool isKorean) {
  final buf = StringBuffer();
  buf.writeln('═══ PatternChart Summary ═══');
  buf.writeln('Title: ${chart.title}');
  buf.writeln('Mode: ${chart.mode.name} / Direction: ${chart.knittingDirection.name}');
  buf.writeln('Grid: ${chart.rows} rows × ${chart.cols} cols');
  buf.writeln('Gauge: ${chart.gauge?.stitchesPer10cm} st/10cm × ${chart.gauge?.rowsPer10cm} rows/10cm');
  buf.writeln('SourceType: ${chart.sourceType.name}');
  buf.writeln('isComplete: ${chart.isComplete}  status: ${chart.status.name}');
  buf.writeln('');
  buf.writeln('AiSections: ${chart.aiSections?.length ?? 0}');
  for (final s in chart.aiSections ?? const <AiSection>[]) {
    final title = isKorean ? (s.titleKo ?? s.title) : s.title;
    final blockCount = chart.narrativeBlocks
        .where((b) => b.sectionId == s.id)
        .length;
    buf.writeln('  - $title  (blocks: $blockCount)');
  }
  buf.writeln('');
  buf.writeln('NarrativeBlocks: ${chart.narrativeBlocks.length} total');
  buf.writeln('RepeatRegions: ${chart.repeatRegions.length}');
  for (final r in chart.repeatRegions) {
    buf.writeln('  - [${r.labelKo ?? r.label}] '
        '(${r.startRow},${r.startCol})~(${r.endRow},${r.endCol}) × ${r.repeatCount}');
  }
  buf.writeln('');
  buf.writeln('─── First 10 narrative blocks ───');
  for (final b in chart.narrativeBlocks.take(10)) {
    buf.writeln('  [${b.order}] ${b.text}');
  }
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────
// Internal: Repeat-unit chart
// ─────────────────────────────────────────────────────────────

class _RepeatUnitChart {
  final int rows;
  final int cols;
  final List<List<CellData>> grid;
  const _RepeatUnitChart({required this.rows, required this.cols, required this.grid});
}

/// 래글런 늘림 2단 패턴 — 반복 1 단위 차트 (2행 × 20열).
///
/// 구조:
///   row 0 = 2단(안면, 원통이므로 겉뜨기) → 모든 셀 empty(=겉뜨기 의미)
///   row 1 = 1단(겉면, 늘림단) → M1R/k/k/M1L 패턴을 4개 래글런 지점에 배치
///
/// 레이아웃 (row 1, 20칸):
///   [k ×3] [M1R] [k k] [M1L] [k ×2] [M1R] [k k] [M1L] [k ×2] [M1R] [k k] [M1L] [k ×1]
///    0 1 2    3    4 5    6    7 8    9    10 11   12   13 14   15   16 17   18    19
///
/// (차트 하단 = 1행, 상단 = 2행 / 도안에디터는 row 0 을 맨 아래에 렌더)
_RepeatUnitChart _buildRaglanRepeatChart() {
  const int rows = 2;
  const int cols = 20;

  final grid = List.generate(
    rows,
    (_) => List.generate(cols, (_) => const CellData(symbolId: 'k')),
  );

  // row 1 (늘림단) — M1R/M1L 배치 지점
  // 래글런 4개 지점: 각각 k2 둘레에 M1R ... k k ... M1L
  const m1rCols = [3, 9, 15];
  const m1lCols = [6, 12, 18];

  // 4번째 래글런(시작/끝 마커 근처)은 차트에 담기 어려워
  // 대표 3개 래글런만 표시 (반복 패턴 학습용). 서술형에 전체 4회 지시 명시.
  for (final c in m1rCols) {
    grid[1][c] = const CellData(symbolId: 'm1r');
  }
  for (final c in m1lCols) {
    grid[1][c] = const CellData(symbolId: 'm1l');
  }

  // row 0 (평단) — 전부 겉뜨기
  // (이미 k로 초기화됨)

  return _RepeatUnitChart(rows: rows, cols: cols, grid: grid);
}

// ─────────────────────────────────────────────────────────────
// Internal: Sections / Blocks builder
// ─────────────────────────────────────────────────────────────

/// 섹션 ID 키 — 블록과의 연결용 상수.
class _SectionKey {
  final String key;
  final String ko;
  final String en;
  const _SectionKey(this.key, this.ko, this.en);
}

const _sec1 = _SectionKey('neck_cast_on', '섹션 1: 목둘레 코잡기', 'Section 1: Neck Cast-on');
const _sec2 = _SectionKey('neck_rib', '섹션 2: 목 고무단', 'Section 2: Neck Rib');
const _sec3 = _SectionKey('front_shaping', '섹션 3: 앞목 쉐이핑 & 래글런 늘림 1', 'Section 3: Front Neck Shaping & Raglan Inc 1');
const _sec4 = _SectionKey('raglan_inc2', '섹션 4: 래글런 늘림 2', 'Section 4: Raglan Inc 2');
const _sec5 = _SectionKey('extra_body', '섹션 5: 몸통 추가단 (XL+)', 'Section 5: Extra Body Rows (XL+)');
const _sec6 = _SectionKey('sleeve_separate', '섹션 6: 소매 분리 & 겨드랑이 감아코', 'Section 6: Sleeve Separation & Underarm CO');
const _sec7 = _SectionKey('body_stockinette', '섹션 7: 몸통 메리야스 뜨기', 'Section 7: Body Stockinette');
const _sec8 = _SectionKey('body_decrease', '섹션 8: 몸통 코줄임', 'Section 8: Body Decrease Row');
const _sec9 = _SectionKey('body_rib', '섹션 9: 몸통 고무단', 'Section 9: Body Rib');
const _sec10 = _SectionKey('body_bind_off', '섹션 10: 몸통 돗바늘 코막음', 'Section 10: Body Bind-off (Sewn)');
const _sec11 = _SectionKey('sleeve_knit', '섹션 11: 소매 뜨기', 'Section 11: Sleeve Knitting');
const _sec12 = _SectionKey('sleeve_finish', '섹션 12: 소매 고무단 & 마무리', 'Section 12: Sleeve Rib & Finishing');

const _allSectionKeys = <_SectionKey>[
  _sec1, _sec2, _sec3, _sec4, _sec5, _sec6,
  _sec7, _sec8, _sec9, _sec10, _sec11, _sec12,
];

class _SectionsBuilder {
  final RaglanTopdownTemplate tmpl;
  final RaglanSize size;
  final _uuid = const Uuid();

  _SectionsBuilder({required this.tmpl, required this.size});

  /// 12개 AiSection 생성. id는 uuid, 각 섹션의 _SectionKey.key 가 내부 매핑에 사용됨.
  List<AiSection> buildSections() {
    return _allSectionKeys
        .map((k) => AiSection(
              id: _uuid.v4(),
              title: k.en,
              titleKo: k.ko,
              steps: const [],
            ))
        .toList();
  }

  /// 각 섹션별 NarrativeBlock 생성 — sectionId로 연결.
  List<NarrativeBlock> buildBlocks(List<AiSection> sections) {
    final idByKey = <String, String>{};
    for (int i = 0; i < _allSectionKeys.length; i++) {
      idByKey[_allSectionKeys[i].key] = sections[i].id;
    }

    final blocks = <NarrativeBlock>[];
    int order = 0;

    void add(String secKey, String text) {
      blocks.add(NarrativeBlock.create(
        text: text,
        order: order++,
        sectionId: idByKey[secKey],
      ));
    }

    // 편의 변수
    final s1 = size.afterShaping1;
    final raglanBaseTotal = s1.total(raglanStitches: tmpl.common.totalRaglanStitches);
    final afterRaglan2 = size.afterRaglan2FinalFor(tmpl.common);
    final afterRaglan2Total = afterRaglan2.total(raglanStitches: tmpl.common.totalRaglanStitches);
    final bodyTotal = size.bodyTotalStitches(tmpl.common);

    // ── 섹션 1: 목둘레 코잡기 ────────────────────────────────
    add(_sec1.key, '3.5mm 대바늘에 40cm 케이블을 연결합니다.');
    add(_sec1.key, '${size.neckCastOn}코를 원형 코잡기로 시작하고, 라운드 시작 마커를 설치합니다.');
    add(_sec1.key, '꼬임 없이 원형으로 연결되어 있는지 반드시 확인합니다.');

    // ── 섹션 2: 목 고무단 ─────────────────────────────────────
    final neckRibRows =
        (tmpl.common.neckRibHeightCm * tmpl.referenceRowGauge / 10).round();
    add(_sec2.key, '1단(원통): [겉 1, 안 1]을 끝까지 반복합니다.');
    add(_sec2.key,
        '2~$neckRibRows단: 1단을 반복합니다. 총 ${tmpl.common.neckRibHeightCm.toStringAsFixed(0)}cm (약 $neckRibRows단).');
    add(_sec2.key,
        '$neckRibRows단 끝: 겹단 처리 — 코잡은 부분에서 같은 라인의 끝을 건져 올려 한 번에 겉뜨기로 정리합니다.');

    // ── 섹션 3: 앞목 쉐이핑 & 래글런 늘림 1 (11단) ──────────
    // 셋업단 각 구간 초기 코수 (afterShaping1 기준) — 쉐이핑 전이므로 수치는 참고용.
    final initBackEach = s1.rightBack; // 쉐이핑 후 양쪽 뒷판 콧수
    final initSleeveEach = s1.rightSleeve;
    final initFront = s1.front;

    add(_sec3.key, '4mm 대바늘로 교체합니다.');
    add(_sec3.key,
        '셋업단(겉면): 겉 $initBackEach(오른쪽 뒷판), 마커, 겉 2(레글런), 마커, '
        '겉 $initSleeveEach(오른쪽 소매), 마커, 겉 2(레글런), 마커, '
        '겉 $initFront(앞판), 마커, 겉 2(레글런), 마커, '
        '겉 $initSleeveEach(왼쪽 소매), 마커, 겉 2(레글런), 마커, '
        '겉 $initBackEach(왼쪽 뒷판).');
    add(_sec3.key,
        '※ 셋업단 이후 앞목 쉐이핑을 위해 독일식 짧은단(German Short Row, DS) 방식으로 ${tmpl.common.frontNeckShapingRows}단 작업합니다.');
    add(_sec3.key,
        '1단(겉면): 다음 마커까지 겉뜨기, [M1R, 마커 넘기기, 겉 2, 마커 넘기기, M1L]을 2회, '
        '다음 마커까지 겉뜨기, [M1R, 마커 넘기기, 겉 2, 마커 넘기기, M1L], 겉 2, 턴(독일식).');
    add(_sec3.key,
        '2단(안면): 시작 마커까지 안뜨기, [M1R(안), 마커 넘기기, 안 2, 마커 넘기기, M1L(안)]을 2회, '
        '시작 마커까지 안뜨기, [M1R(안), 마커 넘기기, 안 2, 마커 넘기기, M1L(안)], 안 2, 턴(독일식).');
    add(_sec3.key,
        '3단(겉면): 앞 턴 지점 2코 전까지 겉뜨기, [M1R, 마커 넘기기, 겉 2, 마커 넘기기, M1L]을 2회, '
        '앞 턴 지점 2코 전까지 겉뜨기, [M1R, 마커 넘기기, 겉 2, 마커 넘기기, M1L], 겉 2, 턴.');
    add(_sec3.key,
        '4단(안면): 앞 턴 지점 2코 전까지 안뜨기, [M1R(안), 마커 넘기기, 안 2, 마커 넘기기, M1L(안)]을 2회, '
        '앞 턴 지점 2코 전까지 안뜨기, [M1R(안), 마커 넘기기, 안 2, 마커 넘기기, M1L(안)], 안 2, 턴.');
    add(_sec3.key, '5~6단: 3~4단과 동일한 방식으로 앞 턴 지점 2코 전까지 늘림을 반복합니다.');
    add(_sec3.key, '7~8단: 5~6단과 동일. 턴 지점이 점점 바깥으로 이동합니다.');
    add(_sec3.key, '9~10단: 7~8단과 동일.');
    add(_sec3.key,
        '11단(겉면): 시작 마커까지 끝까지 겉뜨기로 진행, 중간에 만나는 턴 지점(DS)은 두 겹을 한 번에 겉뜨기로 풀어줍니다. '
        '라운드 시작 마커 복귀 시 원통뜨기로 전환.');
    add(_sec3.key,
        '※ 이 섹션 끝 = 앞목 쉐이핑 완료 + 래글런 늘림 1회(8코) 누적. '
        '구간별 콧수: 뒷판 ${s1.rightBack}/${s1.leftBack}, 소매 ${s1.rightSleeve}/${s1.leftSleeve}, '
        '앞판 ${s1.front}, 레글런 ${tmpl.common.totalRaglanStitches}. 총 $raglanBaseTotal코.');

    // ── 섹션 4: 래글런 늘림 2 (반복 raglanRepeat회) ──────────
    add(_sec4.key,
        '이제부터 원통뜨기로 진행합니다. 아래 2단 한 세트를 총 ${size.raglanRepeat}회 반복합니다.');
    add(_sec4.key,
        '1단(늘림단): 다음 마커까지 겉뜨기, [M1R, 마커 넘기기, 겉 2, 마커 넘기기, M1L]을 4회, '
        '시작 마커까지 겉뜨기. (이 단에서 총 8코 증가)');
    add(_sec4.key, '2단(평단): 시작 마커까지 끝까지 겉뜨기.');
    add(_sec4.key,
        '※ 1~2단을 ${size.raglanRepeat}회 반복 후 구간별 콧수: '
        '뒷판 ${afterRaglan2.rightBack}/${afterRaglan2.leftBack}, '
        '소매 ${afterRaglan2.rightSleeve}/${afterRaglan2.leftSleeve}, '
        '앞판 ${afterRaglan2.front}, 레글런 ${tmpl.common.totalRaglanStitches}. 총 $afterRaglan2Total코.');

    // ── 섹션 5: XL+ 몸통 추가단 ──────────────────────────────
    if (size.extraBodyOnlyRepeat > 0) {
      add(_sec5.key,
          '${size.name} 사이즈는 몸통 쪽(앞판·뒷판)만 늘리는 추가단을 ${size.extraBodyOnlyRepeat}회 수행합니다.');
      add(_sec5.key,
          '1단(몸통 늘림): 뒷판 마지막 2코 전까지 겉뜨기, M1R, 마커 넘기기, 겉 2(레글런), 마커 넘기기, '
          '소매 구간은 늘림 없이 겉뜨기로 통과, 다음 마커 전 2코 전에 M1L, 마커 넘기기, 겉 2, 마커 넘기기, '
          '앞판 진입 후 바로 M1R, 앞판 마지막 2코 전까지 겉뜨기, M1L, 마커 넘기기, 겉 2, 마커 넘기기, '
          '반대편 소매 통과, 뒷판 진입 시작 부분에 M1R, 시작 마커까지 겉뜨기. (몸통만 +4코)');
      add(_sec5.key, '2단(평단): 시작 마커까지 끝까지 겉뜨기.');
      add(_sec5.key, '※ 위 1~2단을 총 ${size.extraBodyOnlyRepeat}회 반복합니다.');
    } else {
      add(_sec5.key, '${size.name} 사이즈는 추가단 없이 섹션 6으로 진행합니다.');
    }

    // ── 섹션 6: 소매 분리 & 겨드랑이 감아코 ─────────────────
    final sleeveRest = size.sleeveRestedStitches;
    add(_sec6.key, '별도 실(잉여 털실/스크랩얀)과 돗바늘을 준비합니다.');
    add(_sec6.key,
        '시작 지점부터: 뒷판 ${afterRaglan2.rightBack}코 겉뜨기 → 레글런 2코 포함 소매 $sleeveRest코(레글런 2 + 소매 ${afterRaglan2.rightSleeve} + 레글런 2)를 '
        '별도 실에 옮겨 쉬게 둡니다.');
    add(_sec6.key,
        '겨드랑이에 ${size.underarmCastOn}코 감아코(backward loop cast-on)로 만듭니다.');
    add(_sec6.key,
        '앞판 ${afterRaglan2.front}코 겉뜨기 → 반대편 소매도 $sleeveRest코(레글런 2 + 소매 ${afterRaglan2.leftSleeve} + 레글런 2)를 별도 실에 쉬게 두기.');
    add(_sec6.key,
        '반대편 겨드랑이에도 ${size.underarmCastOn}코 감아코를 만듭니다.');
    add(_sec6.key,
        '남은 뒷판 ${afterRaglan2.leftBack}코 겉뜨기하여 시작 마커로 복귀. 총 몸통 콧수: $bodyTotal코.');
    add(_sec6.key,
        '새 시작 마커를 겨드랑이 중앙(가능하면 오른쪽 겨드랑이)에 꽂아 단수 표시링으로 삼습니다.');

    // ── 섹션 7: 몸통 메리야스 뜨기 ──────────────────────────
    final bodyRows =
        (size.bodyLengthBeforeRibCm * tmpl.referenceRowGauge / 10).round();
    add(_sec7.key,
        '단수 표시링 위치부터 원통으로 겉뜨기 메리야스. 목표 길이: ${size.bodyLengthBeforeRibCm.toStringAsFixed(0)}cm '
        '(약 $bodyRows단).');
    add(_sec7.key, '중간에 길이 측정 시 반드시 블로킹 상태가 아닌 자연스러운 드레이프 상태에서 잰다.');

    // ── 섹션 8: 몸통 코줄임 (1단) ──────────────────────────
    final N = size.bodyDecreaseKnitBetween;
    final M = size.bodyDecreaseRepeat;
    add(_sec8.key,
        '코줄임 1단: [겉 $N, 2코모아겉뜨기(k2tog)]를 $M회 반복, 남은 코는 끝까지 겉뜨기로 정리. (총 $M코 감소)');
    add(_sec8.key,
        '※ 감소 후 콧수는 템플릿 표의 "몸통 고무단 직전 콧수"(PDF 참조)를 기준으로 확인합니다. '
        '짝수로 맞추어야 고무단 [겉1·안1]이 맞물립니다.');

    // ── 섹션 9: 몸통 고무단 ─────────────────────────────────
    final bodyRibRows =
        (tmpl.common.bodyRibHeightCm * tmpl.referenceRowGauge / 10).round();
    add(_sec9.key, '3.5mm 대바늘로 교체합니다.');
    add(_sec9.key,
        '1단(원통): [겉 1, 안 1]을 끝까지 반복.');
    add(_sec9.key,
        '2~$bodyRibRows단: 1단 반복. 총 ${tmpl.common.bodyRibHeightCm.toStringAsFixed(0)}cm (약 $bodyRibRows단).');

    // ── 섹션 10: 몸통 돗바늘 코막음 ─────────────────────────
    add(_sec10.key,
        '몸통 끝: 돗바늘 코막음(sewn bind-off, 또는 Italian bind-off)으로 신축성 있게 마무리합니다.');
    add(_sec10.key,
        '작업사의 실 길이 = 남은 콧수 × 3배 + 여유 30cm. 실이 중간에 부족하지 않도록 넉넉히 잘라둡니다.');
    add(_sec10.key, '돗바늘 코막음 시 장력을 편안하게 유지 — 너무 조이면 밑단이 오그라듭니다.');

    // ── 섹션 11: 소매 뜨기 ──────────────────────────────────
    final sleeveTotalAfterPick =
        size.sleeveRestedStitches + size.sleevePickUpHalf * 2;
    final sleeveRows =
        (size.sleeveLengthCm * tmpl.referenceRowGauge / 10).round();
    add(_sec11.key,
        '쉬어둔 소매 ${size.sleeveRestedStitches}코를 4mm 대바늘에 다시 옮깁니다.');
    add(_sec11.key,
        '겨드랑이 감아코 영역에서 양쪽 각 ${size.sleevePickUpHalf}코씩 줍기(pick-up), '
        '총 ${size.sleevePickUpHalf * 2}코 추가. 소매 총 $sleeveTotalAfterPick코.');
    add(_sec11.key,
        '단 시작 마커는 겨드랑이 중앙에 꽂습니다. 원통으로 겉뜨기 메리야스 진행.');
    add(_sec11.key,
        '소매 코줄임: 마커 직후에 ssk, 마커 직전에 k2tog를 두어 한 단에서 2코 감소. '
        '약 ${size.sleeveDecreaseIntervalCm.toStringAsFixed(1)}cm 간격으로 ${size.sleeveDecreaseRepeat}회 반복.');
    add(_sec11.key,
        '※ 코줄임 사이는 평단(겉뜨기만). 코줄임 후 마지막 코줄임에서 고무단 직전 목표 콧수에 도달해야 합니다.');
    add(_sec11.key,
        '소매 전체 길이: ${size.sleeveLengthCm.toStringAsFixed(0)}cm (약 $sleeveRows단) 될 때까지 진행.');

    // ── 섹션 12: 소매 고무단 & 마무리 ──────────────────────
    final sleeveRibRows =
        (tmpl.common.sleeveRibHeightCm * tmpl.referenceRowGauge / 10).round();
    add(_sec12.key, '3.5mm 바늘(또는 DPN)로 교체합니다.');
    add(_sec12.key,
        '1단(원통): [겉 1, 안 1]을 끝까지 반복.');
    add(_sec12.key,
        '2~$sleeveRibRows단: 1단 반복. 총 ${tmpl.common.sleeveRibHeightCm.toStringAsFixed(0)}cm (약 $sleeveRibRows단).');
    add(_sec12.key, '소매 끝: 돗바늘 코막음으로 마무리.');
    add(_sec12.key, '반대편 소매도 동일하게 작업합니다.');
    add(_sec12.key, '실 정리 & 물세탁 블로킹 → 가슴둘레·소매 길이 최종 치수를 측정하여 완성 확인.');

    return blocks;
  }
}
