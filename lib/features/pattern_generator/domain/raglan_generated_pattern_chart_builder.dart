// lib/features/pattern_generator/domain/raglan_generated_pattern_chart_builder.dart
//
// 이슈 #638 Phase 4 — 치수+게이지 기반으로 생성된 RaglanGeneratedPattern 을
// 완전한 PatternChart 로 변환합니다.
//
// 설계 원칙 (#637 raglan_pattern_builder.dart 와 동일):
//   • 12개 AiSection (목코잡기 ~ 마무리) + 각 섹션에 연결된 NarrativeBlock 리스트
//   • 2×20 래글런 늘림 반복 단위 차트 (늘림단 + 평단)
//   • RepeatRegion 으로 raglanRepeat 횟수 표시
//   • ChartMode.symbol, KnittingDirection.inTheRound, GaugeInfo (사용자 게이지)
//
// 반환 PatternChart.isComplete == true  → #627 "AI 도안에서 시작" 시트 필터 통과.
// 호출자가 id/createdAt/linkedProjectId 등을 copyWith 로 채워 저장합니다.
//
// 사용 예:
//   final gen = RaglanPatternGenerator(measurements: ..., gauge: ...).generate();
//   final chart = buildPatternChartFromGenerated(gen, isKorean: true);
//   final saved = await repo.save(chart);  // id 발급
//   // → PatternEditorScreen(patternId: saved.id) 진입

import 'package:uuid/uuid.dart';

import '../../pattern/domain/ai_pattern_section.dart';
import '../../pattern/domain/narrative_block.dart';
import '../../pattern/domain/pattern_chart.dart';
import 'raglan_generated_pattern.dart';

// ─────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────

/// 생성된 래글런 도안 스펙 → 완전한 PatternChart.
///
/// [gen] : RaglanPatternGenerator.generate() 결과.
/// [isKorean] : 섹션 제목·블록 텍스트 언어 (기본 한국어).
/// [title] : null 이면 치수 요약으로 자동 생성
///          예: "치수 기반 래글런 도안 — 가슴 90cm · 목 36cm".
///
/// 반환 PatternChart:
///   • id = '' (저장 시 채워짐)
///   • rows = 2, cols = 20, mode = ChartMode.symbol
///   • gauge = 사용자 게이지
///   • knittingDirection = inTheRound
///   • sourceType = PatternSourceType.editor
///   • aiSections = 12개, narrativeBlocks 연결 완료
///   • repeatRegions = 래글런 늘림 반복 1개 (repeatCount = gen.raglanRepeat)
///   • isComplete = true (섹션 + 연결 블록 보장)
PatternChart buildPatternChartFromGenerated(
  RaglanGeneratedPattern gen, {
  bool isKorean = true,
  String? title,
}) {
  final sectionsBuilder = _GeneratedSectionsBuilder(gen: gen, isKorean: isKorean);
  final sections = sectionsBuilder.buildSections();
  final blocks = sectionsBuilder.buildBlocks(sections);

  final repeatUnit = _buildRaglanRepeatChart();
  final repeatRegion = RepeatRegion.create(
    startRow: 0,
    startCol: 0,
    endRow: repeatUnit.rows - 1,
    endCol: repeatUnit.cols - 1,
    repeatCount: gen.raglanRepeat,
    label: 'Raglan increase',
    labelKo: '래글런 늘림',
  );

  final meas = gen.measurements;
  final autoTitle = isKorean
      ? '치수 기반 래글런 도안 — 가슴 ${_fmt(meas.chestCm)}cm · 목 ${_fmt(meas.neckCm)}cm'
      : 'Custom Raglan Pattern — chest ${_fmt(meas.chestCm)}cm · neck ${_fmt(meas.neckCm)}cm';
  final finalTitle = (title != null && title.isNotEmpty) ? title : autoTitle;

  return PatternChart(
    id: '',
    title: finalTitle,
    rows: repeatUnit.rows,
    cols: repeatUnit.cols,
    mode: ChartMode.symbol,
    grid: repeatUnit.grid,
    narrativeText: NarrativeBlock.toText(blocks),
    sourceType: PatternSourceType.editor,
    aiSections: sections,
    knittingDirection: KnittingDirection.inTheRound,
    gauge: GaugeInfo(
      stitchesPer10cm: gen.gauge.stitchesPer10cm,
      rowsPer10cm: gen.gauge.rowsPer10cm,
    ),
    repeatRegions: [repeatRegion],
    narrativeBlocks: blocks,
  );
}

/// 테스트/디버깅용: 빌드 결과 PatternChart 요약 덤프.
String dumpGeneratedPatternChartSummary(PatternChart chart, bool isKorean) {
  final buf = StringBuffer();
  buf.writeln('═══ Generated PatternChart Summary ═══');
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

/// 소수점 최대 1자리 포맷 (정수일 때 .0 생략).
String _fmt(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────────
// Internal: Repeat-unit chart (2 × 20)
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
///   row 0 = 1단(늘림단) → M1R/k/k/M1L 패턴 3세트 배치
///   row 1 = 2단(평단)   → 전부 겉뜨기
///
/// row 0 레이아웃 (20칸):
///   [k ×3] [M1R] [k k] [M1L] [k ×2] [M1R] [k k] [M1L] [k ×2] [M1R] [k k] [M1L] [k ×1]
///    0 1 2    3    4 5    6    7 8    9    10 11   12   13 14   15   16 17   18    19
///
/// (4번째 래글런은 반복 단위 밖 — 서술형에 "4회" 명시)
_RepeatUnitChart _buildRaglanRepeatChart() {
  const int rows = 2;
  const int cols = 20;

  final grid = List.generate(
    rows,
    (_) => List.generate(cols, (_) => const CellData(symbolId: 'k')),
  );

  // row 0 (늘림단) — M1R/M1L 배치 (대표 3개 래글런)
  const m1rCols = [3, 9, 15];
  const m1lCols = [6, 12, 18];
  for (final c in m1rCols) {
    grid[0][c] = const CellData(symbolId: 'm1r');
  }
  for (final c in m1lCols) {
    grid[0][c] = const CellData(symbolId: 'm1l');
  }

  // row 1 (평단) — 전부 겉뜨기 (이미 k로 초기화됨)

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
const _sec3 = _SectionKey('front_shaping', '섹션 3: 셋업단 & 앞목 쉐이핑', 'Section 3: Setup Round & Front Neck Shaping');
const _sec4 = _SectionKey('raglan_inc', '섹션 4: 래글런 늘림 반복', 'Section 4: Raglan Increase Repeat');
const _sec5 = _SectionKey('raglan_check', '섹션 5: 래글런 끝 콧수 확인', 'Section 5: After-Raglan Stitch Check');
const _sec6 = _SectionKey('sleeve_separate', '섹션 6: 소매 분리 & 겨드랑이 감아코', 'Section 6: Sleeve Separation & Underarm CO');
const _sec7 = _SectionKey('body_stockinette', '섹션 7: 몸통 메리야스 뜨기', 'Section 7: Body Stockinette');
const _sec8 = _SectionKey('body_rib', '섹션 8: 몸통 고무단', 'Section 8: Body Rib');
const _sec9 = _SectionKey('body_bind_off', '섹션 9: 몸통 돗바늘 코막음', 'Section 9: Body Bind-off');
const _sec10 = _SectionKey('sleeve_pickup', '섹션 10: 소매 코 줍기', 'Section 10: Sleeve Pick-up');
const _sec11 = _SectionKey('sleeve_knit', '섹션 11: 소매 뜨기 + 코줄임', 'Section 11: Sleeve + Decrease');
const _sec12 = _SectionKey('sleeve_finish', '섹션 12: 소매 마무리', 'Section 12: Sleeve Finishing');

const _allSectionKeys = <_SectionKey>[
  _sec1, _sec2, _sec3, _sec4, _sec5, _sec6,
  _sec7, _sec8, _sec9, _sec10, _sec11, _sec12,
];

class _GeneratedSectionsBuilder {
  final RaglanGeneratedPattern gen;
  final bool isKorean;
  final _uuid = const Uuid();

  _GeneratedSectionsBuilder({required this.gen, required this.isKorean});

  /// 12개 AiSection 생성 (uuid 고유 ID).
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

  /// 각 섹션별 NarrativeBlock 생성 — sectionId 로 연결.
  ///
  /// toNarrativeSteps(12단계) 를 기반 소스로 사용하되, 각 단계마다
  /// 상세 수치·팁·검증 블록을 추가해 1~3개 블록으로 확장.
  /// 경고가 있으면 마지막 섹션에 "⚠ 경고" 블록 추가.
  List<NarrativeBlock> buildBlocks(List<AiSection> sections) {
    final idByKey = <String, String>{};
    for (int i = 0; i < _allSectionKeys.length; i++) {
      idByKey[_allSectionKeys[i].key] = sections[i].id;
    }

    // 12단계 기준 텍스트
    final steps = gen.toNarrativeSteps(isKorean: isKorean);

    final blocks = <NarrativeBlock>[];
    int order = 0;

    void add(String secKey, String text) {
      blocks.add(NarrativeBlock.create(
        text: text,
        order: order++,
        sectionId: idByKey[secKey],
      ));
    }

    // 섹션 키 순서대로 12단계 매핑
    final sectionOrder = <String>[
      _sec1.key, _sec2.key, _sec3.key, _sec4.key, _sec5.key, _sec6.key,
      _sec7.key, _sec8.key, _sec9.key, _sec10.key, _sec11.key, _sec12.key,
    ];

    // 각 섹션에 기본 단계 텍스트 추가 (가드: steps 길이 12 가정)
    for (int i = 0; i < sectionOrder.length && i < steps.length; i++) {
      add(sectionOrder[i], steps[i]);
    }

    // ── 섹션별 상세 보조 블록 추가 ──
    final m = gen.measurements;
    final g = gen.gauge;

    // 섹션 1: 목 코잡기 — 목 여유 + 실제 cm
    final neckActualCm = gen.neckCastOn * 10 / g.stitchesPer10cm;
    add(_sec1.key,
        isKorean
            ? '※ 목 실측 ${_fmt(m.neckCm)}cm + 여유 ${_fmt(gen.ease.neckEaseCm)}cm → 실제 코잡기 기준 약 ${_fmt(neckActualCm)}cm.'
            : '※ Neck ${_fmt(m.neckCm)}cm + ease ${_fmt(gen.ease.neckEaseCm)}cm → actual ~${_fmt(neckActualCm)}cm.');
    add(_sec1.key,
        isKorean
            ? '꼬임 없이 원형으로 연결되어 있는지 반드시 확인합니다.'
            : 'Ensure the cast-on is joined in the round without twisting.');

    // 섹션 2: 목 고무단 — 겹단 팁
    add(_sec2.key,
        isKorean
            ? '※ 고무단 6cm 완료 후 겹단 처리 — 코잡은 부분의 같은 라인 끝을 건져 올려 한 번에 겉뜨기로 정리합니다.'
            : '※ After 6cm rib, fold hem: pick up each stitch of the cast-on edge and knit together.');

    // 섹션 3: 셋업단 & 앞목 쉐이핑
    add(_sec3.key,
        isKorean
            ? '셋업단: 겉 ${gen.initBackEach}(우뒷판), 마커, 겉 2(레글런), 마커, 겉 ${gen.initSleeveEach}(우소매), 마커, 겉 2(레글런), 마커, '
              '겉 ${gen.initFront}(앞판), 마커, 겉 2(레글런), 마커, 겉 ${gen.initSleeveEach}(좌소매), 마커, 겉 2(레글런), 마커, 겉 ${gen.initBackEach}(좌뒷판).'
            : 'Setup: k${gen.initBackEach} (R back), m, k2, m, k${gen.initSleeveEach} (R sleeve), m, k2, m, '
              'k${gen.initFront} (front), m, k2, m, k${gen.initSleeveEach} (L sleeve), m, k2, m, k${gen.initBackEach} (L back).');
    add(_sec3.key,
        isKorean
            ? '※ 앞목 쉐이핑은 독일식 짧은단(German Short Row)으로 ${gen.frontNeckShapingRows}단 진행. 턴 지점이 앞판 중심에서 점차 바깥으로 이동합니다.'
            : '※ Front-neck shaping: German short rows for ${gen.frontNeckShapingRows} rows, turn points moving outward from front center.');

    // 섹션 4: 래글런 늘림 반복
    add(_sec4.key,
        isKorean
            ? '1단(늘림단): 다음 마커까지 겉뜨기, [M1R, 마커 넘기기, 겉 2, 마커 넘기기, M1L]을 4회, 시작 마커까지 겉뜨기. (한 세트에 +8코)'
            : 'Row 1 (inc): knit to m, [M1R, sm, k2, sm, M1L] × 4, knit to BOR. (+8 sts per set)');
    add(_sec4.key,
        isKorean
            ? '2단(평단): 시작 마커까지 끝까지 겉뜨기.'
            : 'Row 2 (plain): knit to BOR.');
    add(_sec4.key,
        isKorean
            ? '※ 1~2단을 ${gen.raglanRepeat}회 반복 → 총 ${gen.raglanRepeat * 8}코 증가 (2단×${gen.raglanRepeat} = ${gen.raglanRepeat * 2}단 소요).'
            : '※ Repeat rows 1~2 × ${gen.raglanRepeat} → +${gen.raglanRepeat * 8} sts total (${gen.raglanRepeat * 2} rows).');

    // 섹션 5: 래글런 끝 콧수 확인
    final afterRaglanTotal =
        gen.finalFront + gen.finalBackEach * 2 + gen.finalSleeveEach * 2 + gen.raglanStitches;
    add(_sec5.key,
        isKorean
            ? '※ 확인: 앞 ${gen.finalFront} + 뒷 ${gen.finalBackEach}×2 + 소매 ${gen.finalSleeveEach}×2 + 레글런 ${gen.raglanStitches} = 총 $afterRaglanTotal코.'
            : '※ Verify: front ${gen.finalFront} + back ${gen.finalBackEach}×2 + sleeve ${gen.finalSleeveEach}×2 + raglan ${gen.raglanStitches} = $afterRaglanTotal sts.');

    // 섹션 6: 소매 분리 & 겨드랑이 감아코
    add(_sec6.key,
        isKorean
            ? '별도 실(자투리 털실)과 돗바늘 준비. 한쪽 소매 ${gen.finalSleeveEach}코(+레글런 2코 포함 가능)를 자투리 실에 옮겨 쉬게 둡니다.'
            : 'Prepare waste yarn. Slip ${gen.finalSleeveEach} sleeve sts (optionally + raglan 2 sts each side) onto waste yarn.');
    add(_sec6.key,
        isKorean
            ? '겨드랑이에 ${gen.underarmCastOn}코 감아코(backward loop cast-on). 앞판·뒷판 통과 후 반대편 소매도 동일하게 쉬게 두고 ${gen.underarmCastOn}코 감아코. '
              '총 몸통 콧수 = ${gen.bodyTotalStitches}코.'
            : 'Cast on ${gen.underarmCastOn} underarm sts (backward loop). Repeat for other side. Body total = ${gen.bodyTotalStitches} sts.');

    // 섹션 7: 몸통 메리야스
    final bodyActualCm = gen.bodyRows * 10 / g.rowsPer10cm;
    add(_sec7.key,
        isKorean
            ? '※ 약 ${_fmt(bodyActualCm)}cm. 측정 시 블로킹 전 자연 드레이프 상태에서 재세요 — 당겨지지 않게.'
            : '※ About ${_fmt(bodyActualCm)}cm. Measure without stretching, before blocking.');

    // 섹션 8: 몸통 고무단
    add(_sec8.key,
        isKorean
            ? '3.5mm 대바늘로 교체. [겉 1, 안 1]을 ${gen.bodyRibRows}단 반복.'
            : 'Switch to 3.5mm. [k1, p1] for ${gen.bodyRibRows} rows.');

    // 섹션 9: 몸통 돗바늘 코막음
    add(_sec9.key,
        isKorean
            ? '실 길이 = 남은 콧수 × 3배 + 여유 30cm. 장력을 편안하게 유지 (너무 조이면 밑단이 오그라듭니다).'
            : 'Tail length = remaining sts × 3 + 30cm extra. Keep tension relaxed to avoid tight hem.');

    // 섹션 10: 소매 코 줍기
    add(_sec10.key,
        isKorean
            ? '쉬어둔 소매 ${gen.finalSleeveEach}코를 4mm 대바늘로 옮김. 겨드랑이 감아코 영역에서 좌우 총 ${gen.underarmCastOn}코 줍기. 총 ${gen.sleeveTotalStitches}코.'
            : 'Slip ${gen.finalSleeveEach} sleeve sts to 4mm. Pick up ${gen.underarmCastOn} sts total from underarm. Total ${gen.sleeveTotalStitches} sts.');
    add(_sec10.key,
        isKorean
            ? '단 시작 마커는 겨드랑이 중앙에 꽂습니다. 원통 메리야스 진행.'
            : 'Place BOR marker at underarm center. Knit in the round.');

    // 섹션 11: 소매 뜨기 + 코줄임
    final sleeveActualCm = gen.sleeveRows * 10 / g.rowsPer10cm;
    if (gen.sleeveDecreaseCount > 0) {
      add(_sec11.key,
          isKorean
              ? '코줄임: 마커 직후 ssk, 마커 직전 k2tog → 한 단에 2코 감소. ${gen.sleeveDecreaseIntervalRows}단마다 반복 × ${gen.sleeveDecreaseCount}회.'
              : 'Decrease: after BOR marker ssk, before BOR marker k2tog (-2 sts/row). Every ${gen.sleeveDecreaseIntervalRows} rows × ${gen.sleeveDecreaseCount}.');
    } else {
      add(_sec11.key,
          isKorean
              ? '이 사이즈는 코줄임이 필요 없습니다 — 원통 메리야스만 진행.'
              : 'No decrease needed for this size — knit stockinette in the round.');
    }
    add(_sec11.key,
        isKorean
            ? '※ 소매 길이 약 ${_fmt(sleeveActualCm)}cm. 고무단 직전까지 ${gen.sleeveRows}단.'
            : '※ Sleeve length about ${_fmt(sleeveActualCm)}cm. ${gen.sleeveRows} rows before rib.');

    // 섹션 12: 소매 마무리
    add(_sec12.key,
        isKorean
            ? '3.5mm로 교체, [겉 1, 안 1]을 ${gen.sleeveRibRows}단 반복 후 돗바늘 코막음.'
            : 'Switch to 3.5mm, [k1, p1] × ${gen.sleeveRibRows} rows, then sewn bind-off.');
    add(_sec12.key,
        isKorean
            ? '반대편 소매 동일 작업 → 실 정리 + 겨드랑이 봉합 → 물세탁 블로킹으로 최종 치수 확인.'
            : 'Repeat for other sleeve → weave in ends + sew underarm → wet-block and verify measurements.');

    // 섹션 12 끝에 경고 블록
    if (gen.warnings.isNotEmpty) {
      final warnPrefix = isKorean ? '⚠ 경고' : '⚠ Warnings';
      final joined = gen.warnings.map((w) => '• $w').join('\n');
      add(_sec12.key, '$warnPrefix\n$joined');
    }

    return blocks;
  }
}
