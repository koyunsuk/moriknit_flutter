// lib/features/pattern_generator/presentation/pattern_generator_screen.dart
//
// 이슈 #664 — 패턴 생성기 (래글런 + SVG 도식 + 단계별 도식 + 출판용 PDF).
//
// Phase 1: 신규 화면 + 도구함 카드 진입
// Phase 2: 입력 카드 (사이즈 프리셋 / 치수 / 게이지 / 핏 / 컬러)
// Phase 3: 결과 카드 (12단계 텍스트 + 액션)
// Phase 4: 전체 옷 SVG 도식 (RaglanSchematicView)
// Phase 6: 단계별 동적 도식 (step_diagrams 9개)
// Phase 7: 출판용 PDF 내보내기 (RaglanPdfExporter)

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/raglan_pdf_exporter.dart';
import '../domain/body_measurement.dart';
import '../domain/doll_presets.dart';
import '../domain/raglan_generated_pattern.dart';
import '../domain/raglan_pattern_generator.dart';
import '../domain/standard_size_presets.dart';
import 'widgets/raglan_schematic_view.dart';
import 'widgets/step_diagrams/step_diagrams.dart';

enum _SizePresetTab { women, men, doll }

enum _EasePreset { doll, slim, adultStandard, loose, oversizedCrop }

class PatternGeneratorScreen extends ConsumerStatefulWidget {
  const PatternGeneratorScreen({super.key});

  @override
  ConsumerState<PatternGeneratorScreen> createState() => _PatternGeneratorScreenState();
}

class _PatternGeneratorScreenState extends ConsumerState<PatternGeneratorScreen> {
  // ── 게이지 ─────────────────────
  final _stsCtrl = TextEditingController(text: '20');
  final _rowsCtrl = TextEditingController(text: '28');

  // ── 인체 치수 ───────────────────
  final _chestCtrl = TextEditingController(text: '90');
  final _neckCtrl = TextEditingController(text: '36');
  final _bodyLenCtrl = TextEditingController(text: '55');
  final _sleeveLenCtrl = TextEditingController(text: '52');
  final _upperArmCtrl = TextEditingController();
  final _wristCtrl = TextEditingController();
  final _shoulderCtrl = TextEditingController();
  final _armholeDepthCtrl = TextEditingController();
  bool _optionalExpanded = false;

  // ── 빠른 사이즈 프리셋 ───────────
  _SizePresetTab _sizePresetTab = _SizePresetTab.women;
  String? _selectedPresetKey;

  // ── 핏 + 컬러 ──────────────────
  _EasePreset _easePreset = _EasePreset.adultStandard;
  Color _yarnColor = const Color(0xFF8B7AB8);

  // ── 결과 ───────────────────────
  RaglanGeneratedPattern? _generated;
  String? _genError;

  // ── 도식 캡처용 GlobalKey (PDF 임베드) ───────────
  // 표지/전체 도식: RaglanSchematicView 1개
  final GlobalKey _schematicKey = GlobalKey();
  // 단계별 도식: 1~12 (10번은 도식 없음 — _diagramForStep 참조)
  final Map<int, GlobalKey> _stepKeys = {
    for (var i = 1; i <= 12; i++)
      if (i != 10) i: GlobalKey(),
  };

  @override
  void dispose() {
    for (final c in [
      _stsCtrl, _rowsCtrl,
      _chestCtrl, _neckCtrl, _bodyLenCtrl, _sleeveLenCtrl,
      _upperArmCtrl, _wristCtrl, _shoulderCtrl, _armholeDepthCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _str(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      if (v == v.toInt()) return v.toInt().toString();
      return v.toString();
    }
    return v.toString();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text) ?? 0;

  void _applyMeasurementPreset(BodyMeasurement m) {
    setState(() {
      _chestCtrl.text = _str(m.chestCm);
      _neckCtrl.text = _str(m.neckCm);
      _bodyLenCtrl.text = _str(m.bodyLengthCm);
      _sleeveLenCtrl.text = _str(m.sleeveLengthCm);
      _upperArmCtrl.text = _str(m.upperArmCm);
      _wristCtrl.text = _str(m.wristCm);
      _shoulderCtrl.text = _str(m.shoulderCm);
      _armholeDepthCtrl.text = _str(m.armholeDepthCm);
      _optionalExpanded = true;
    });
  }

  /// 인형: 치수만 적용. 게이지는 사용자 게이지 유지 (#661 후속 정책).
  void _applyDollPreset(DollPreset preset) {
    setState(() {
      final m = preset.measurement;
      _chestCtrl.text = _str(m.chestCm);
      _neckCtrl.text = _str(m.neckCm);
      _bodyLenCtrl.text = _str(m.bodyLengthCm);
      _sleeveLenCtrl.text = _str(m.sleeveLengthCm);
      _upperArmCtrl.text = _str(m.upperArmCm);
      _wristCtrl.text = _str(m.wristCm);
      _shoulderCtrl.text = _str(m.shoulderCm);
      _armholeDepthCtrl.text = _str(m.armholeDepthCm);
      _optionalExpanded = true;
      _easePreset = _EasePreset.doll;
    });
  }

  EaseSettings get _easeSettings {
    switch (_easePreset) {
      case _EasePreset.doll: return EaseSettings.doll;
      case _EasePreset.slim: return EaseSettings.slim;
      case _EasePreset.adultStandard: return EaseSettings.adultStandard;
      case _EasePreset.loose: return EaseSettings.loose;
      case _EasePreset.oversizedCrop: return EaseSettings.oversizedCrop;
    }
  }

  String _easePresetLabel(_EasePreset p, bool isKorean) {
    switch (p) {
      case _EasePreset.doll: return isKorean ? '인형' : 'Doll';
      case _EasePreset.slim: return isKorean ? '슬림' : 'Slim';
      case _EasePreset.adultStandard: return isKorean ? '표준' : 'Standard';
      case _EasePreset.loose: return isKorean ? '루즈' : 'Loose';
      case _EasePreset.oversizedCrop: return isKorean ? '오버크롭' : 'Oversized';
    }
  }

  void _generate() {
    final m = BodyMeasurement(
      chestCm: _parse(_chestCtrl),
      neckCm: _parse(_neckCtrl),
      bodyLengthCm: _parse(_bodyLenCtrl),
      sleeveLengthCm: _parse(_sleeveLenCtrl),
      upperArmCm: _parse(_upperArmCtrl) > 0 ? _parse(_upperArmCtrl) : null,
      wristCm: _parse(_wristCtrl) > 0 ? _parse(_wristCtrl) : null,
      shoulderCm: _parse(_shoulderCtrl) > 0 ? _parse(_shoulderCtrl) : null,
      armholeDepthCm: _parse(_armholeDepthCtrl) > 0 ? _parse(_armholeDepthCtrl) : null,
    );
    final g = UserGauge(stitchesPer10cm: _parse(_stsCtrl), rowsPer10cm: _parse(_rowsCtrl));
    final err = m.validate();
    if (err != null) {
      setState(() { _genError = err; _generated = null; });
      return;
    }
    try {
      final result = RaglanPatternGenerator(measurements: m, gauge: g, ease: _easeSettings).generate();
      setState(() { _generated = result; _genError = null; });
    } catch (e) {
      setState(() { _genError = '$e'; _generated = null; });
    }
  }

  /// GlobalKey가 가리키는 RepaintBoundary를 PNG 바이트로 캡처.
  /// 캡처 실패 시 null 반환 (사용자 흐름은 차단하지 않음 — placeholder fallback).
  Future<Uint8List?> _captureKey(GlobalKey key) async {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      // pixelRatio 2.0 → 출판용 선명도 확보 (A4 200dpi 수준).
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[PdfExport] capture failed for $key: $e');
      return null;
    }
  }

  /// 모든 도식(전체 도식 + 단계별 도식)을 캡처해서 Map으로 반환.
  /// PDF 생성 직전에 호출. 화면에 렌더된 위젯만 캡처 가능.
  Future<({Uint8List? schematic, Map<int, Uint8List> steps})>
      _captureAllDiagrams() async {
    // 위젯 렌더링 완료 보장 (Frame 한 번 통과).
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final schematicBytes = await _captureKey(_schematicKey);
    final stepImages = <int, Uint8List>{};
    for (final entry in _stepKeys.entries) {
      final bytes = await _captureKey(entry.value);
      if (bytes != null) stepImages[entry.key] = bytes;
    }
    return (schematic: schematicBytes, steps: stepImages);
  }

  Future<void> _exportPdf(bool isKorean) async {
    final pat = _generated;
    if (pat == null) return;
    try {
      // 1) 도식 캡처 (로딩 다이얼로그 띄우기 전에 — 다이얼로그가 캡처를 가릴 수 있음).
      final captured = await _captureAllDiagrams();

      if (!mounted) return;
      // 2) PDF 생성 + 공유.
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? 'PDF 만드는 중입니다.' : 'Building PDF...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await RaglanPdfExporter().share(
            pattern: pat,
            title: isKorean
                ? '래글런 도안 — 가슴 ${pat.measurements.chestCm.toStringAsFixed(0)}cm'
                : 'Raglan — Chest ${pat.measurements.chestCm.toStringAsFixed(0)}cm',
            subtitle: '${pat.gauge.stitchesPer10cm.toInt()}코/${pat.gauge.rowsPer10cm.toInt()}단/10cm',
            schematicImage: captured.schematic,
            stepImages: captured.steps,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _printPdf(bool isKorean) async {
    final pat = _generated;
    if (pat == null) return;
    try {
      final captured = await _captureAllDiagrams();
      if (!mounted) return;
      await RaglanPdfExporter().print(
        pattern: pat,
        title: isKorean
            ? '래글런 도안 — 가슴 ${pat.measurements.chestCm.toStringAsFixed(0)}cm'
            : 'Raglan — Chest ${pat.measurements.chestCm.toStringAsFixed(0)}cm',
        schematicImage: captured.schematic,
        stepImages: captured.steps,
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    return AppShellScaffold(
      title: isKorean ? '패턴 생성기 (래글런)' : 'Pattern Generator (Raglan)',
      subtitle: isKorean ? '치수와 게이지로 도안 자동 생성' : 'Auto-generate from measurements',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSizePresetCard(isKorean),
            const SizedBox(height: 12),
            _buildGaugeCard(isKorean),
            const SizedBox(height: 12),
            _buildMeasurementCard(isKorean),
            const SizedBox(height: 12),
            _buildEaseAndColorCard(isKorean),
            const SizedBox(height: 12),
            _buildGenerateButton(isKorean),
            if (_genError != null) ...[
              const SizedBox(height: 12),
              _buildErrorCard(isKorean, _genError!),
            ],
            if (_generated != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(isKorean, _generated!),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 입력 카드
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSizePresetCard(bool isKorean) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.checklist_rounded, color: C.pk, size: 18),
            const SizedBox(width: 6),
            Text(isKorean ? '📋 빠른 사이즈 프리셋' : '📋 Quick Size Preset', style: T.bodyBold),
          ]),
          const SizedBox(height: 4),
          Text(
            isKorean ? '탭 선택 후 사이즈 칩을 누르면 치수가 자동 입력돼요' : 'Pick a tab and tap a size to auto-fill',
            style: T.caption.copyWith(color: C.mu),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _SizePresetTab.values.map((tab) {
              final selected = _sizePresetTab == tab;
              return GestureDetector(
                onTap: () => setState(() => _sizePresetTab = tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? C.lv : C.lvL,
                    border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _sizePresetTabLabel(tab, isKorean),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : C.lvD,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildSizePresetChips(isKorean),
        ],
      ),
    );
  }

  String _sizePresetTabLabel(_SizePresetTab tab, bool isKorean) {
    switch (tab) {
      case _SizePresetTab.women: return isKorean ? '여성' : 'Women';
      case _SizePresetTab.men: return isKorean ? '남성' : 'Men';
      case _SizePresetTab.doll: return isKorean ? '인형' : 'Doll';
    }
  }

  Widget _buildSizePresetChips(bool isKorean) {
    switch (_sizePresetTab) {
      case _SizePresetTab.women:
        return Wrap(spacing: 8, runSpacing: 8, children: womenStandardSizes.map((p) {
          final key = 'women_${p.label}';
          return _buildSizeChip(label: p.label, hint: p.hint, selected: _selectedPresetKey == key, onTap: () {
            _applyMeasurementPreset(p.measurement);
            setState(() => _selectedPresetKey = key);
          });
        }).toList());
      case _SizePresetTab.men:
        return Wrap(spacing: 8, runSpacing: 8, children: menStandardSizes.map((p) {
          final key = 'men_${p.label}';
          return _buildSizeChip(label: p.label, hint: p.hint, selected: _selectedPresetKey == key, onTap: () {
            _applyMeasurementPreset(p.measurement);
            setState(() => _selectedPresetKey = key);
          });
        }).toList());
      case _SizePresetTab.doll:
        return Wrap(spacing: 8, runSpacing: 8, children: builtinDollPresets.map((d) {
          final key = 'doll_${d.id}';
          return _buildSizeChip(
            label: isKorean ? d.nameKo : d.nameEn,
            hint: '${d.heightCm}cm · 권장 ${d.suggestedGauge.stitchesPer10cm.toInt()}/${d.suggestedGauge.rowsPer10cm.toInt()}',
            selected: _selectedPresetKey == key,
            onTap: () {
              _applyDollPreset(d);
              setState(() => _selectedPresetKey = key);
            },
          );
        }).toList());
    }
  }

  Widget _buildSizeChip({required String label, required String hint, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? C.pk : C.pkL,
          border: Border.all(
            color: selected ? C.pk : C.pk.withValues(alpha: 0.30),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [BoxShadow(color: C.pk.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) ...[
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 4),
              ],
              Text(label, style: T.caption.copyWith(fontWeight: FontWeight.w700, color: selected ? Colors.white : C.pkD)),
            ]),
            const SizedBox(height: 2),
            Text(hint, style: T.caption.copyWith(color: selected ? Colors.white.withValues(alpha: 0.85) : C.mu, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeCard(bool isKorean) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.straighten_rounded, color: C.lvD, size: 18),
            const SizedBox(width: 6),
            Text(isKorean ? '📐 내 게이지 (10cm 기준)' : '📐 My Gauge (per 10cm)', style: T.bodyBold),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _NumberField(controller: _stsCtrl, label: isKorean ? '코수' : 'Stitches')),
            const SizedBox(width: 10),
            Expanded(child: _NumberField(controller: _rowsCtrl, label: isKorean ? '단수' : 'Rows')),
          ]),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(bool isKorean) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.accessibility_new_rounded, color: C.lv, size: 18),
            const SizedBox(width: 6),
            Text(isKorean ? '🧍 인체 치수 (cm)' : '🧍 Body Measurements (cm)', style: T.bodyBold),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _NumberField(controller: _chestCtrl, label: isKorean ? '가슴 *' : 'Chest *')),
            const SizedBox(width: 10),
            Expanded(child: _NumberField(controller: _neckCtrl, label: isKorean ? '목 *' : 'Neck *')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _NumberField(controller: _bodyLenCtrl, label: isKorean ? '옷 길이 *' : 'Body length *')),
            const SizedBox(width: 10),
            Expanded(child: _NumberField(controller: _sleeveLenCtrl, label: isKorean ? '소매 *' : 'Sleeve *')),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _optionalExpanded = !_optionalExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Icon(Icons.tune_rounded, color: C.pk, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isKorean ? '선택 치수 (비우면 자동 추정)' : 'Optional (auto-estimated)',
                  style: T.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(_optionalExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.mu, size: 18),
            ]),
          ),
          if (_optionalExpanded) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _NumberField(controller: _upperArmCtrl, label: isKorean ? '상완' : 'Upper arm')),
              const SizedBox(width: 10),
              Expanded(child: _NumberField(controller: _wristCtrl, label: isKorean ? '손목' : 'Wrist')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _NumberField(controller: _shoulderCtrl, label: isKorean ? '어깨' : 'Shoulder')),
              const SizedBox(width: 10),
              Expanded(child: _NumberField(controller: _armholeDepthCtrl, label: isKorean ? '진동' : 'Armhole')),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildEaseAndColorCard(bool isKorean) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.style_rounded, color: C.og, size: 18),
            const SizedBox(width: 6),
            Text(isKorean ? '👕 핏 + 실 컬러' : '👕 Fit + Yarn Color', style: T.bodyBold),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _EasePreset.values.map((p) {
            final selected = _easePreset == p;
            return GestureDetector(
              onTap: () => setState(() => _easePreset = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? C.lv : C.lvL,
                  border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_easePresetLabel(p, isKorean), style: TextStyle(
                  fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : C.lvD,
                )),
              ),
            );
          }).toList()),
          const SizedBox(height: 12),
          Row(children: [
            Text(isKorean ? '실 색:' : 'Yarn:', style: T.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            ..._yarnColorChoices.map((c) {
              final selected = _yarnColor.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _yarnColor = c),
                child: Container(
                  width: 28, height: 28, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: selected ? Border.all(color: C.tx, width: 2) : Border.all(color: C.bd),
                  ),
                ),
              );
            }),
          ]),
        ],
      ),
    );
  }

  static const _yarnColorChoices = [
    Color(0xFF8B7AB8), // 라벤더
    Color(0xFFE8A0BF), // 핑크
    Color(0xFF7BA9D6), // 블루
    Color(0xFF8DC974), // 그린
    Color(0xFFE8C547), // 옐로우
    Color(0xFFCC7A6E), // 테라코타
    Color(0xFF6B6B6B), // 그레이
    Color(0xFFFFFFFF), // 화이트
  ];

  Widget _buildGenerateButton(bool isKorean) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _generate,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(
          isKorean ? '도안 생성하기' : 'Generate Pattern',
          style: T.bodyBold.copyWith(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: C.lv,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildErrorCard(bool isKorean, String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.og.withValues(alpha: 0.08),
        border: Border.all(color: C.og.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: C.og),
        const SizedBox(width: 8),
        Expanded(child: Text(error, style: T.caption.copyWith(color: C.og))),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 결과 카드 (도안 텍스트 + 도식 + 액션)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildResultCard(bool isKorean, RaglanGeneratedPattern p) {
    final steps = p.toNarrativeSteps(isKorean: isKorean);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 전체 옷 도식 (Phase 4)
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.image_rounded, color: C.lv, size: 18),
                const SizedBox(width: 6),
                Text(isKorean ? '🎨 완성 도식 (앞면 + 뒷면)' : '🎨 Schematic', style: T.bodyBold),
              ]),
              const SizedBox(height: 10),
              // RepaintBoundary로 감싸서 PDF 캡처 가능하도록 함.
              RepaintBoundary(
                key: _schematicKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: RaglanSchematicView(pattern: p, yarnColor: _yarnColor, showLabels: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 2. 액션 (PDF 공유 / 인쇄)
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _exportPdf(isKorean),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text(isKorean ? 'PDF 공유' : 'Share PDF', style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: C.lvD, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _printPdf(isKorean),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: Text(isKorean ? '인쇄' : 'Print', style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: C.pk, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // 3. 경고
        if (p.warnings.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6D6),
              border: Border.all(color: const Color(0xFFE8C547)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFF8C6B00), size: 18),
                const SizedBox(width: 6),
                Text(isKorean ? '경고' : 'Warnings', style: T.bodyBold.copyWith(color: const Color(0xFF8C6B00))),
              ]),
              const SizedBox(height: 6),
              ...p.warnings.map((w) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $w', style: T.caption.copyWith(color: const Color(0xFF6B5300))),
              )),
            ]),
          ),
        const SizedBox(height: 12),
        // 4. 12단계 텍스트 + 도식
        ...List.generate(steps.length, (i) => _buildStepCard(isKorean, i + 1, steps[i], p)),
      ],
    );
  }

  /// 단계마다 텍스트 + 해당 단계 도식 (Phase 6).
  Widget _buildStepCard(bool isKorean, int stepNumber, String text, RaglanGeneratedPattern p) {
    final diagram = _diagramForStep(stepNumber, p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: C.lv, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$stepNumber', style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: T.body)),
            ]),
            if (diagram != null) ...[
              const SizedBox(height: 10),
              // RepaintBoundary로 감싸서 PDF 캡처 가능하도록 함.
              RepaintBoundary(
                key: _stepKeys[stepNumber],
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(6),
                  child: diagram,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 단계 번호별 단계 도식 매핑 (Phase 6 위젯들).
  Widget? _diagramForStep(int step, RaglanGeneratedPattern p) {
    switch (step) {
      case 1: return CastOnDiagram(stitchCount: p.neckCastOn);
      case 2: return RibPatternDiagram(rows: p.gauge.rowsFromCm(6), cm: 6);
      case 3: return MarkerPlacementDiagram(
        totalStitches: p.neckCastOn,
        frontStitches: p.initFront,
        backEachStitches: p.initBackEach,
        sleeveEachStitches: p.initSleeveEach,
        raglanStitches: 2,
      );
      case 4: return RaglanIncreaseDiagram(repeatCount: p.raglanRepeat);
      case 5: return StitchCountLabel(
        frontStitches: p.finalFront,
        backStitches: p.finalBackEach,
        sleeveStitches: p.finalSleeveEach,
      );
      case 6: return SleeveSeparationDiagram(
        sleeveStitches: p.finalSleeveEach,
        underarmCastOn: p.underarmCastOn,
      );
      case 7: return StockinetteDiagram(
        rows: p.bodyRows,
        cm: p.bodyRows * 10 / p.gauge.rowsPer10cm,
      );
      case 8: return RibPatternDiagram(rows: p.bodyRibRows, cm: 7);
      case 9: return BindOffDiagram(stitchCount: p.bodyTotalStitches);
      case 11: return SleeveDecreaseDiagram(
        decreaseCount: p.sleeveDecreaseCount,
        intervalRows: p.sleeveDecreaseIntervalRows,
      );
      default: return null;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 공용 입력 필드
// ──────────────────────────────────────────────────────────────────────────

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _NumberField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: C.gx,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
