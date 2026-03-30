import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class GaugeCalculatorScreen extends ConsumerStatefulWidget {
  const GaugeCalculatorScreen({super.key});

  @override
  ConsumerState<GaugeCalculatorScreen> createState() => _GaugeCalculatorScreenState();
}

class _GaugeCalculatorScreenState extends ConsumerState<GaugeCalculatorScreen> {
  final _stitchesCtrl = TextEditingController(text: '25');
  final _rowsCtrl = TextEditingController(text: '20');
  final _targetWidthCtrl = TextEditingController(text: '40');
  final _targetHeightCtrl = TextEditingController(text: '50');

  @override
  void initState() {
    super.initState();
    _stitchesCtrl.addListener(_rebuild);
    _rowsCtrl.addListener(_rebuild);
    _targetWidthCtrl.addListener(_rebuild);
    _targetHeightCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _stitchesCtrl.dispose();
    _rowsCtrl.dispose();
    _targetWidthCtrl.dispose();
    _targetHeightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final stitches = double.tryParse(_stitchesCtrl.text) ?? 0;
    final rows = double.tryParse(_rowsCtrl.text) ?? 0;
    final targetWidth = double.tryParse(_targetWidthCtrl.text) ?? 0;
    final targetHeight = double.tryParse(_targetHeightCtrl.text) ?? 0;
    final castOn = stitches == 0 ? 0 : ((stitches / 10) * targetWidth).round();
    final totalRows = rows == 0 ? 0 : ((rows / 10) * targetHeight).round();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        title: Text(t.gaugeCalculator, style: T.h3),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              MoriPageHeaderShell(
                padding: EdgeInsets.zero,
                child: MoriBrandHeader(subtitle: t.gaugeHeaderSubtitle),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.gaugeBaseGauge, style: T.bodyBold),
                    const SizedBox(height: 12),
                    _NumberField(
                      controller: _stitchesCtrl,
                      label: isKorean ? '10cm당 코수' : 'Stitches per 10cm',
                    ),
                    const SizedBox(height: 10),
                    _NumberField(
                      controller: _rowsCtrl,
                      label: isKorean ? '10cm당 단수' : 'Rows per 10cm',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.gaugeTargetSize, style: T.bodyBold),
                    const SizedBox(height: 12),
                    _NumberField(
                      controller: _targetWidthCtrl,
                      label: isKorean ? '가로 길이 (cm)' : 'Width (cm)',
                    ),
                    const SizedBox(height: 10),
                    _NumberField(
                      controller: _targetHeightCtrl,
                      label: isKorean ? '세로 길이 (cm)' : 'Height (cm)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.gaugeResult, style: T.bodyBold),
                    const SizedBox(height: 12),
                    _ResultRow(
                      label: isKorean ? '예상 시작 코수' : 'Suggested cast-on',
                      value: castOn == 0 ? '--' : '$castOn',
                    ),
                    const SizedBox(height: 8),
                    _ResultRow(
                      label: isKorean ? '예상 전체 단수' : 'Estimated total rows',
                      value: totalRows == 0 ? '--' : '$totalRows',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isKorean
                          ? '입력값은 빠른 계산용이며, 실제 도안에는 여유분과 패턴 반복 수를 함께 고려하세요.'
                          : 'Use this as a quick estimate and adjust for repeats or ease.',
                      style: T.caption.copyWith(color: C.mu),
                    ),
                  ],
                ),
              ),
            ],
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

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: T.body),
        Text(value, style: T.bodyBold.copyWith(color: C.lvD)),
      ],
    );
  }
}
