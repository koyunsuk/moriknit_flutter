import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

enum _GaugeMode { myGauge, patternConvert, bidirectional }

class GaugeCalculatorScreen extends ConsumerStatefulWidget {
  const GaugeCalculatorScreen({super.key});

  @override
  ConsumerState<GaugeCalculatorScreen> createState() => _GaugeCalculatorScreenState();
}

class _GaugeCalculatorScreenState extends ConsumerState<GaugeCalculatorScreen> {
  _GaugeMode _mode = _GaugeMode.myGauge;

  // ── 공통: 내 게이지 ──
  final _myStsCtrl = TextEditingController(text: '20');
  final _myRowsCtrl = TextEditingController(text: '28');

  // ── 모드 1: 크기 계산 ──
  final _widthCtrl = TextEditingController(text: '40');
  final _heightCtrl = TextEditingController(text: '50');

  // ── 모드 2: 도안 변환 ──
  final _patStsCtrl = TextEditingController(text: '16');
  final _patRowsCtrl = TextEditingController(text: '24');
  final _patStCountCtrl = TextEditingController(text: '80');
  final _patRowCountCtrl = TextEditingController(text: '120');

  // ── 모드 3: 양방향 ──
  final _stsToConvertCtrl = TextEditingController(text: '40');
  final _cmToConvertCtrl = TextEditingController(text: '20');
  final _rowsToConvertCtrl = TextEditingController(text: '60');
  final _cmHeightToConvertCtrl = TextEditingController(text: '25');

  @override
  void initState() {
    super.initState();
    for (final c in _allControllers) {
      c.addListener(_rebuild);
    }
  }

  List<TextEditingController> get _allControllers => [
        _myStsCtrl, _myRowsCtrl,
        _widthCtrl, _heightCtrl,
        _patStsCtrl, _patRowsCtrl, _patStCountCtrl, _patRowCountCtrl,
        _stsToConvertCtrl, _cmToConvertCtrl, _rowsToConvertCtrl, _cmHeightToConvertCtrl,
      ];

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t.gaugeCalculator, style: T.h3),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // 모드 선택
              _ModeSelector(
                mode: _mode,
                isKorean: isKorean,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 16),

              // 내 게이지 (항상 표시)
              _GaugeInputCard(
                title: isKorean ? '내 스와치 게이지' : 'My Swatch Gauge',
                subtitle: isKorean ? '10cm × 10cm 기준' : 'per 10cm × 10cm',
                stsCtrl: _myStsCtrl,
                rowsCtrl: _myRowsCtrl,
                stsLabel: isKorean ? '코수 (sts/10cm)' : 'Stitches per 10cm',
                rowsLabel: isKorean ? '단수 (rows/10cm)' : 'Rows per 10cm',
                color: C.lv,
              ),
              const SizedBox(height: 14),

              // 모드별 추가 입력 + 결과
              if (_mode == _GaugeMode.myGauge) ...[
                _buildModeMyGauge(isKorean),
              ] else if (_mode == _GaugeMode.patternConvert) ...[
                _buildModePatternConvert(isKorean),
              ] else ...[
                _buildModeBidirectional(isKorean),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Mode 1: 내 게이지로 크기 계산 ────────────────────────────
  Widget _buildModeMyGauge(bool isKorean) {
    final myS = _parse(_myStsCtrl);
    final myR = _parse(_myRowsCtrl);
    final w = _parse(_widthCtrl);
    final h = _parse(_heightCtrl);

    final castOn = myS > 0 && w > 0 ? (myS / 10 * w).round() : 0;
    final totalRows = myR > 0 && h > 0 ? (myR / 10 * h).round() : 0;

    return Column(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? '원하는 크기' : 'Target Size', style: T.bodyBold),
              const SizedBox(height: 12),
              _NumberField(controller: _widthCtrl, label: isKorean ? '가로 (cm)' : 'Width (cm)'),
              const SizedBox(height: 10),
              _NumberField(controller: _heightCtrl, label: isKorean ? '세로 (cm)' : 'Height (cm)'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ResultCard(
          isKorean: isKorean,
          rows: [
            _ResultItem(
              label: isKorean ? '시작 코수 (cast-on)' : 'Cast-on stitches',
              value: castOn == 0 ? '--' : '$castOn코',
              icon: Icons.horizontal_rule,
              color: C.lv,
            ),
            _ResultItem(
              label: isKorean ? '총 단수' : 'Total rows',
              value: totalRows == 0 ? '--' : '$totalRows단',
              icon: Icons.vertical_align_bottom,
              color: C.pk,
            ),
          ],
          tip: isKorean
              ? '패턴 반복 단위에 맞춰 코수를 조정하세요.\n예: 4코 반복이면 4의 배수로 올림/내림'
              : 'Adjust stitch count to match pattern repeats.',
        ),
      ],
    );
  }

  // ── Mode 2: 도안 게이지 → 내 게이지 변환 ─────────────────────
  Widget _buildModePatternConvert(bool isKorean) {
    final myS = _parse(_myStsCtrl);
    final myR = _parse(_myRowsCtrl);
    final patS = _parse(_patStsCtrl);
    final patR = _parse(_patRowsCtrl);
    final patStCount = _parse(_patStCountCtrl);
    final patRowCount = _parse(_patRowCountCtrl);

    final stsRatio = (myS > 0 && patS > 0) ? myS / patS : 0.0;
    final rowsRatio = (myR > 0 && patR > 0) ? myR / patR : 0.0;

    final adjustedSts = patStCount > 0 && stsRatio > 0 ? (patStCount * stsRatio).round() : 0;
    final adjustedRows = patRowCount > 0 && rowsRatio > 0 ? (patRowCount * rowsRatio).round() : 0;

    // 도안 코수 그대로 내 게이지로 뜰 경우 나오는 실제 치수
    final actualWidth = myS > 0 && patStCount > 0 ? patStCount / myS * 10 : 0.0;
    final actualHeight = myR > 0 && patRowCount > 0 ? patRowCount / myR * 10 : 0.0;
    // 도안이 의도한 치수
    final patternWidth = patS > 0 && patStCount > 0 ? patStCount / patS * 10 : 0.0;
    final patternHeight = patR > 0 && patRowCount > 0 ? patRowCount / patR * 10 : 0.0;

    final widthDiff = actualWidth - patternWidth;
    final heightDiff = actualHeight - patternHeight;

    String fmtCm(double v) => v == 0 ? '--' : '${v.toStringAsFixed(1)}cm';
    String fmtDiff(double d) {
      if (d == 0) return '';
      final sign = d > 0 ? '+' : '';
      return ' ($sign${d.toStringAsFixed(1)}cm)';
    }

    return Column(
      children: [
        // 도안 게이지 입력
        _GaugeInputCard(
          title: isKorean ? '도안 게이지' : 'Pattern Gauge',
          subtitle: isKorean ? '도안에 명시된 게이지' : 'Gauge stated in pattern',
          stsCtrl: _patStsCtrl,
          rowsCtrl: _patRowsCtrl,
          stsLabel: isKorean ? '도안 코수/10cm' : 'Pattern sts/10cm',
          rowsLabel: isKorean ? '도안 단수/10cm' : 'Pattern rows/10cm',
          color: C.og,
        ),
        const SizedBox(height: 14),
        // 도안 코수 입력
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? '도안 코수 / 단수' : 'Pattern Stitch & Row Count', style: T.bodyBold),
              const SizedBox(height: 4),
              Text(
                isKorean ? '도안에서 사용하는 코수와 단수를 입력하세요' : 'Enter the stitch and row counts from the pattern',
                style: T.caption.copyWith(color: C.mu),
              ),
              const SizedBox(height: 12),
              _NumberField(
                controller: _patStCountCtrl,
                label: isKorean ? '도안 코수 (sts)' : 'Pattern stitch count',
              ),
              const SizedBox(height: 10),
              _NumberField(
                controller: _patRowCountCtrl,
                label: isKorean ? '도안 단수 (rows)' : 'Pattern row count',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 결과
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate_outlined, color: C.lv, size: 18),
                  const SizedBox(width: 6),
                  Text(isKorean ? '계산 결과' : 'Result', style: T.bodyBold),
                ],
              ),
              const SizedBox(height: 14),
              // 조정 비율
              if (stsRatio > 0) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(isKorean ? '코수 조정비' : 'Stitch ratio', style: T.caption.copyWith(color: C.mu)),
                            const SizedBox(height: 2),
                            Text(
                              '×${stsRatio.toStringAsFixed(3)}',
                              style: T.bodyBold.copyWith(color: stsRatio > 1 ? C.og : stsRatio < 1 ? C.lv : C.tx),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 36, color: C.bd),
                      Expanded(
                        child: Column(
                          children: [
                            Text(isKorean ? '단수 조정비' : 'Row ratio', style: T.caption.copyWith(color: C.mu)),
                            const SizedBox(height: 2),
                            Text(
                              '×${rowsRatio.toStringAsFixed(3)}',
                              style: T.bodyBold.copyWith(color: rowsRatio > 1 ? C.og : rowsRatio < 1 ? C.lv : C.tx),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // 조정된 코수
              _ResultRow2(
                label: isKorean ? '내 게이지 조정 코수' : 'Adjusted stitch count',
                value: adjustedSts == 0 ? '--' : '$adjustedSts코',
                sub: isKorean ? '(도안 $patStCount → 내 게이지 기준)' : '(pattern ${patStCount.toInt()} → my gauge)',
                color: C.lv,
              ),
              const SizedBox(height: 10),
              _ResultRow2(
                label: isKorean ? '내 게이지 조정 단수' : 'Adjusted row count',
                value: adjustedRows == 0 ? '--' : '$adjustedRows단',
                sub: isKorean ? '(도안 $patRowCount → 내 게이지 기준)' : '(pattern ${patRowCount.toInt()} → my gauge)',
                color: C.pk,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              Text(
                isKorean ? '도안 코수 그대로 뜰 경우 예상 치수' : 'Size if using pattern count as-is',
                style: T.captionBold.copyWith(color: C.mu),
              ),
              const SizedBox(height: 8),
              _ResultRow2(
                label: isKorean ? '예상 가로' : 'Estimated width',
                value: fmtCm(actualWidth),
                sub: patternWidth > 0
                    ? '${isKorean ? "도안 의도" : "Pattern"}: ${fmtCm(patternWidth)}${fmtDiff(widthDiff)}'
                    : '',
                color: widthDiff.abs() > 1 ? C.og : C.mu,
              ),
              const SizedBox(height: 8),
              _ResultRow2(
                label: isKorean ? '예상 세로' : 'Estimated height',
                value: fmtCm(actualHeight),
                sub: patternHeight > 0
                    ? '${isKorean ? "도안 의도" : "Pattern"}: ${fmtCm(patternHeight)}${fmtDiff(heightDiff)}'
                    : '',
                color: heightDiff.abs() > 1 ? C.og : C.mu,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _TipCard(
          isKorean: isKorean,
          text: isKorean
              ? '조정비가 1.000에 가까울수록 도안 게이지와 내 게이지가 일치합니다.\n조정 코수는 패턴 반복 단위에 맞게 조금 올림/내림하세요.'
              : 'A ratio close to 1.000 means your gauge matches the pattern.\nRound adjusted counts to nearest stitch repeat.',
        ),
      ],
    );
  }

  // ── Mode 3: 양방향 코 ↔ cm ───────────────────────────────────
  Widget _buildModeBidirectional(bool isKorean) {
    final myS = _parse(_myStsCtrl);
    final myR = _parse(_myRowsCtrl);

    final stsInput = _parse(_stsToConvertCtrl);
    final cmWInput = _parse(_cmToConvertCtrl);
    final rowsInput = _parse(_rowsToConvertCtrl);
    final cmHInput = _parse(_cmHeightToConvertCtrl);

    // 코수 → cm
    final cmFromSts = myS > 0 && stsInput > 0 ? stsInput / myS * 10 : 0.0;
    // cm → 코수
    final stsFromCm = myS > 0 && cmWInput > 0 ? (cmWInput * myS / 10).round() : 0;
    // 단수 → cm
    final cmFromRows = myR > 0 && rowsInput > 0 ? rowsInput / myR * 10 : 0.0;
    // cm → 단수
    final rowsFromCm = myR > 0 && cmHInput > 0 ? (cmHInput * myR / 10).round() : 0;

    return Column(
      children: [
        // 가로 (코수 ↔ cm)
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: C.lv, size: 18),
                  const SizedBox(width: 6),
                  Text(isKorean ? '가로 (코수 ↔ cm)' : 'Width (stitches ↔ cm)', style: T.bodyBold),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _stsToConvertCtrl,
                      label: isKorean ? '코수' : 'Stitches',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_forward, color: C.mu, size: 16),
                        Text(
                          cmFromSts == 0 ? '--' : '${cmFromSts.toStringAsFixed(1)}cm',
                          style: T.bodyBold.copyWith(color: C.lvD, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _cmToConvertCtrl,
                      label: isKorean ? 'cm' : 'cm',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_forward, color: C.mu, size: 16),
                        Text(
                          stsFromCm == 0 ? '--' : '$stsFromCm코',
                          style: T.bodyBold.copyWith(color: C.lvD, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 세로 (단수 ↔ cm)
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_vert_rounded, color: C.pk, size: 18),
                  const SizedBox(width: 6),
                  Text(isKorean ? '세로 (단수 ↔ cm)' : 'Height (rows ↔ cm)', style: T.bodyBold),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _rowsToConvertCtrl,
                      label: isKorean ? '단수' : 'Rows',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_forward, color: C.mu, size: 16),
                        Text(
                          cmFromRows == 0 ? '--' : '${cmFromRows.toStringAsFixed(1)}cm',
                          style: T.bodyBold.copyWith(color: C.pkD, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _cmHeightToConvertCtrl,
                      label: isKorean ? 'cm' : 'cm',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_forward, color: C.mu, size: 16),
                        Text(
                          rowsFromCm == 0 ? '--' : '$rowsFromCm단',
                          style: T.bodyBold.copyWith(color: C.pkD, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _TipCard(
          isKorean: isKorean,
          text: isKorean
              ? '코수/단수를 입력하면 실제 cm로, cm를 입력하면 필요한 코수/단수로 즉시 변환됩니다.\n내 스와치 게이지 기준으로 계산됩니다.'
              : 'Enter stitches/rows to get cm, or enter cm to get the needed stitch/row count.\nBased on your swatch gauge above.',
        ),
      ],
    );
  }
}

// ── 위젯들 ────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final _GaugeMode mode;
  final bool isKorean;
  final ValueChanged<_GaugeMode> onChanged;

  const _ModeSelector({required this.mode, required this.isKorean, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      (_GaugeMode.myGauge, isKorean ? '크기 계산' : 'Size'),
      (_GaugeMode.patternConvert, isKorean ? '도안 변환' : 'Pattern'),
      (_GaugeMode.bidirectional, isKorean ? '코↔cm' : 'Sts↔cm'),
    ];
    return Row(
      children: items.map((item) {
        final selected = mode == item.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? C.lv : C.lvL,
                border: Border.all(
                  color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : C.lvD,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GaugeInputCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController stsCtrl;
  final TextEditingController rowsCtrl;
  final String stsLabel;
  final String rowsLabel;
  final Color color;

  const _GaugeInputCard({
    required this.title,
    required this.subtitle,
    required this.stsCtrl,
    required this.rowsCtrl,
    required this.stsLabel,
    required this.rowsLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: T.bodyBold),
                    Text(subtitle, style: T.caption.copyWith(color: C.mu)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NumberField(controller: stsCtrl, label: stsLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(controller: rowsCtrl, label: rowsLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final bool isKorean;
  final List<_ResultItem> rows;
  final String tip;

  const _ResultCard({required this.isKorean, required this.rows, required this.tip});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, color: C.lv, size: 18),
              const SizedBox(width: 6),
              Text(isKorean ? '계산 결과' : 'Result', style: T.bodyBold),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: item.color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.label, style: T.body)),
                    Text(item.value, style: T.bodyBold.copyWith(color: item.color, fontSize: 18)),
                  ],
                ),
              )),
          const Divider(height: 16),
          Text(tip, style: T.caption.copyWith(color: C.mu, height: 1.5)),
        ],
      ),
    );
  }
}

class _ResultItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ResultItem({required this.label, required this.value, required this.icon, required this.color});
}

class _ResultRow2 extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _ResultRow2({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: T.body),
              if (sub.isNotEmpty)
                Text(sub, style: T.caption.copyWith(color: C.mu)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: T.bodyBold.copyWith(color: color, fontSize: 16)),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  final bool isKorean;
  final String text;

  const _TipCard({required this.isKorean, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lv.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined, color: C.lv, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: T.caption.copyWith(color: C.lvD, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NumberField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}
