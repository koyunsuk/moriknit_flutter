import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../pattern/presentation/pattern_editor_screen.dart';
import '../../pattern_generator/domain/body_measurement.dart';
import '../../pattern_generator/domain/doll_presets.dart';
import '../../pattern_generator/domain/raglan_generated_pattern.dart';
import '../../pattern_generator/domain/raglan_generated_pattern_chart_builder.dart';
import '../../pattern_generator/domain/raglan_pattern_generator.dart';
import '../../pattern_generator/domain/standard_size_presets.dart';
import '../../swatch/domain/swatch_model.dart';
import '../../swatch/presentation/swatch_input_screen.dart';

enum _GaugeMode { myGauge, patternConvert, bidirectional, photoReading, raglanGenerator }

enum _EasePreset { doll, slim, adultStandard, loose, oversizedCrop }

/// 빠른 사이즈 프리셋 탭 (이슈 #661 — 래글런 자동 입력).
enum _SizePresetTab { women, men, doll }

class GaugeCalculatorScreen extends ConsumerStatefulWidget {
  /// #639 — 인형 치수 프리셋 자동 입력용 measurementData (BuiltinTemplate.measurementData)
  final Map<String, dynamic>? preloadMeasurementData;

  const GaugeCalculatorScreen({super.key, this.preloadMeasurementData});

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

  // ── 모드 5: 래글런 도안 생성 ──
  final _chestCtrl = TextEditingController(text: '90');
  final _neckCtrl = TextEditingController(text: '36');
  final _bodyLenCtrl = TextEditingController(text: '55');
  final _sleeveLenCtrl = TextEditingController(text: '52');
  final _upperArmCtrl = TextEditingController();
  final _wristCtrl = TextEditingController();
  final _shoulderCtrl = TextEditingController();
  final _armholeDepthCtrl = TextEditingController();
  bool _optionalExpanded = false;
  _EasePreset _easePreset = _EasePreset.adultStandard;
  RaglanGeneratedPattern? _generatedPattern;

  // 이슈 #661 — 빠른 사이즈 프리셋
  _SizePresetTab _sizePresetTab = _SizePresetTab.women;
  // 어떤 칩이 적용됐는지 시각 표시 (예: 'women_55 (S)', 'doll_barbie')
  String? _selectedPresetKey;

  // ── 모드 4: 사진 판독 ──
  Uint8List? _photoBytes;
  Size? _imageSize;
  Size? _displaySize;
  Offset? _selectionStart;
  Offset? _selectionEnd;
  int? _detectedSts;
  int? _detectedRows;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    for (final c in _allControllers) {
      c.addListener(_rebuild);
    }
    // #639 — 인형 프리셋 자동 입력
    if (widget.preloadMeasurementData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyPreload());
    }
  }

  void _applyPreload() {
    final data = widget.preloadMeasurementData;
    if (data == null) return;
    final measurement = data['measurement'] as Map<String, dynamic>?;
    final gauge = data['suggestedGauge'] as Map<String, dynamic>?;
    final easeName = data['suggestedEase'] as String?;
    setState(() {
      _mode = _GaugeMode.raglanGenerator;
      if (measurement != null) {
        _chestCtrl.text = _str(measurement['chestCm']);
        _neckCtrl.text = _str(measurement['neckCm']);
        _bodyLenCtrl.text = _str(measurement['bodyLengthCm']);
        _sleeveLenCtrl.text = _str(measurement['sleeveLengthCm']);
        _upperArmCtrl.text = _str(measurement['upperArmCm']);
        _wristCtrl.text = _str(measurement['wristCm']);
        _shoulderCtrl.text = _str(measurement['shoulderCm']);
        _armholeDepthCtrl.text = _str(measurement['armholeDepthCm']);
        _optionalExpanded = true;
      }
      if (gauge != null) {
        _myStsCtrl.text = _str(gauge['stitchesPer10cm']);
        _myRowsCtrl.text = _str(gauge['rowsPer10cm']);
      }
      if (easeName != null) {
        _easePreset = switch (easeName) {
          'doll' => _EasePreset.doll,
          'slim' => _EasePreset.slim,
          'loose' => _EasePreset.loose,
          'oversizedCrop' => _EasePreset.oversizedCrop,
          _ => _EasePreset.adultStandard,
        };
      }
    });
  }

  /// 이슈 #661 — 빠른 사이즈 프리셋 적용 (성인 표준).
  /// 8개 치수 컨트롤러를 BodyMeasurement로 자동 채움. ease는 사용자 선택 유지.
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

  /// 이슈 #661 — 인형 프리셋 적용 (치수 + ease만).
  /// **게이지는 덮어쓰지 않음** — 사용자가 스와치/직접 입력한 게이지 유지.
  /// (이전: 권장 게이지를 자동 적용 → 사용자 게이지 손실 버그. #661 후속 수정)
  /// 권장 게이지는 인형 칩 hint로만 안내됨.
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

  String _str(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      // 정수면 소수점 제거, 소수점 있으면 그대로
      if (v == v.toInt()) return v.toInt().toString();
      return v.toString();
    }
    return v.toString();
  }

  List<TextEditingController> get _allControllers => [
        _myStsCtrl, _myRowsCtrl,
        _widthCtrl, _heightCtrl,
        _patStsCtrl, _patRowsCtrl, _patStCountCtrl, _patRowCountCtrl,
        _stsToConvertCtrl, _cmToConvertCtrl, _rowsToConvertCtrl, _cmHeightToConvertCtrl,
        _chestCtrl, _neckCtrl, _bodyLenCtrl, _sleeveLenCtrl,
        _upperArmCtrl, _wristCtrl, _shoulderCtrl, _armholeDepthCtrl,
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

  /// 이슈 #799 — 사진 판독은 Pro 요금제 이상에서만 사용 가능.
  /// 비-Pro 사용자에게 안내 다이얼로그 표시.
  void _showProRequiredDialog(bool isKorean) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isKorean ? 'Pro 요금제 전용' : 'Pro Plan Only',
          style: T.h3,
        ),
        content: Text(
          isKorean
              ? '⭐ 사진 판독은 Pro 요금제 이상에서 사용할 수 있어요.'
              : '⭐ Photo reading requires Pro plan or above.',
          style: T.body.copyWith(color: C.tx2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isKorean ? '닫기' : 'Close',
              style: TextStyle(color: C.mu),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(Routes.my);
            },
            child: Text(
              isKorean ? '구독하기' : 'Upgrade',
              style: TextStyle(color: C.lv, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    // 이슈 #799 — Pro 게이트 (사진 판독)
    final gates = ref.watch(featureGatesProvider);
    final canUsePhotoReading = gates.isProOrAbove;

    return AppShellScaffold(
      title: t.gaugeCalculator,
      subtitle: isKorean ? '게이지 변환·도안 생성' : 'Gauge conversion & generator',
      // 즐겨찾기 ⭐ 자동 prepend (이슈 #723 Phase B)
      favoriteScreenId: 'gauge',
      favoriteTitle: isKorean ? '게이지 계산기' : 'Gauge Calculator',
      favoriteIcon: Icons.calculate_rounded,
      favoritePath: Routes.toolsGauge,
      favoriteAccent: C.lv,
      favoriteIsKorean: isKorean,
      body: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
              // 모드 선택
              _ModeSelector(
                mode: _mode,
                isKorean: isKorean,
                canUsePhotoReading: canUsePhotoReading,
                onChanged: (m) {
                  // 이슈 #799 — 사진 판독 탭: Pro 게이트
                  if (m == _GaugeMode.photoReading && !canUsePhotoReading) {
                    _showProRequiredDialog(isKorean);
                    return;
                  }
                  setState(() => _mode = m);
                },
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
                onPickFromSwatch: () => _showSwatchPicker(isKorean),
              ),
              const SizedBox(height: 14),

              // 모드별 추가 입력 + 결과
              if (_mode == _GaugeMode.myGauge) ...[
                _buildModeMyGauge(isKorean),
              ] else if (_mode == _GaugeMode.patternConvert) ...[
                _buildModePatternConvert(isKorean),
              ] else if (_mode == _GaugeMode.bidirectional) ...[
                _buildModeBidirectional(isKorean),
              ] else if (_mode == _GaugeMode.photoReading) ...[
                _buildModePhotoReading(isKorean, t),
              ] else ...[
                _buildModeRaglanGenerator(isKorean),
              ],
              const SizedBox(height: 20),
              _RegisterSwatchButton(
                isKorean: isKorean,
                myStsCtrl: _myStsCtrl,
                myRowsCtrl: _myRowsCtrl,
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
              Text(isKorean ? '📐 원하는 크기' : '📐 Target Size', style: T.bodyBold),
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
              Text(isKorean ? '🔢 도안 코수 / 단수' : '🔢 Pattern Stitch & Row Count', style: T.bodyBold),
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
                  Text(isKorean ? '✨ 계산 결과' : '✨ Result', style: T.bodyBold),
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

  // ── 사진 선택 ──
  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1200);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    setState(() {
      _photoBytes = bytes;
      _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
      _selectionStart = null;
      _selectionEnd = null;
      _detectedSts = null;
      _detectedRows = null;
    });
  }

  void _showSwatchPicker(bool isKorean) {
    final swatches = ref.read(swatchListProvider).valueOrNull ?? [];
    final withGauge = swatches.where((s) => s.beforeStitchCount > 0 && s.beforeRowCount > 0).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(isKorean ? '스와치 선택' : 'Select Swatch', style: T.h3),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: C.mu, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: C.bd),
            if (withGauge.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    isKorean ? '게이지가 입력된 스와치가 없어요' : 'No swatches with gauge data',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: withGauge.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: C.bd),
                  itemBuilder: (_, i) {
                    final s = withGauge[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(s.swatchName.isNotEmpty ? s.swatchName : s.yarnName, style: T.body),
                      subtitle: Text(
                        isKorean
                            ? '코 ${s.beforeStitchCount} / 단 ${s.beforeRowCount} (10cm 기준)'
                            : '${s.beforeStitchCount} sts / ${s.beforeRowCount} rows per 10cm',
                        style: T.caption.copyWith(color: C.mu),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _myStsCtrl.text = '${s.beforeStitchCount}';
                          _myRowsCtrl.text = '${s.beforeRowCount}';
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog(bool isKorean) {
    // 이슈 #799 — Pro 게이트 (사진 선택 직전에도 방어적 체크).
    final gates = ref.read(featureGatesProvider);
    if (!gates.isProOrAbove) {
      _showProRequiredDialog(isKorean);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery'),
              onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(isKorean ? '카메라로 촬영' : 'Take photo'),
              onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.camera); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeSelection() async {
    if (_photoBytes == null || _selectionStart == null || _selectionEnd == null || _imageSize == null) return;
    setState(() => _analyzing = true);

    try {
      final result = await _analyzeGaugeImage(
        _photoBytes!,
        _imageSize!,
        _displaySize ?? const Size(300, 300),
        Rect.fromPoints(_selectionStart!, _selectionEnd!),
      );
      if (mounted) {
        setState(() {
          _detectedSts = result.$1;
          _detectedRows = result.$2;
          _analyzing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  /// 이미지 분석: 자기상관(autocorrelation)으로 수평/수직 주기 감지
  Future<(int stitches, int rows)> _analyzeGaugeImage(
    Uint8List imageBytes,
    Size originalImageSize,
    Size displaySize,
    Rect selectionRect,
  ) async {
    final decoded = img.decodeImage(imageBytes)!;

    // BoxFit.cover 좌표 변환: display 좌표 → 이미지 픽셀 좌표
    final imgW = decoded.width.toDouble();
    final imgH = decoded.height.toDouble();
    final dispW = displaySize.width;
    final dispH = displaySize.height;

    final scaleW = dispW / imgW;
    final scaleH = dispH / imgH;
    final scale = math.max(scaleW, scaleH);
    final offsetX = (imgW - dispW / scale) / 2;
    final offsetY = (imgH - dispH / scale) / 2;
    final visW = dispW / scale;
    final visH = dispH / scale;

    final x0 = (offsetX + selectionRect.left * visW).round().clamp(0, decoded.width - 1);
    final y0 = (offsetY + selectionRect.top * visH).round().clamp(0, decoded.height - 1);
    final x1 = (offsetX + selectionRect.right * visW).round().clamp(0, decoded.width - 1);
    final y1 = (offsetY + selectionRect.bottom * visH).round().clamp(0, decoded.height - 1);

    final cropX = math.min(x0, x1);
    final cropY = math.min(y0, y1);
    final cropW = (x1 - x0).abs().clamp(10, decoded.width - cropX);
    final cropH = (y1 - y0).abs().clamp(10, decoded.height - cropY);

    final cropped = img.copyCrop(decoded, x: cropX, y: cropY, width: cropW, height: cropH);
    final gray = img.grayscale(cropped);

    final stitches = _countPeriodsAC(gray, horizontal: true);
    final rows = _countPeriodsAC(gray, horizontal: false);

    return (stitches, rows);
  }

  /// 자기상관(Autocorrelation)으로 주기 감지 → 주기 개수 반환
  int _countPeriodsAC(img.Image gray, {required bool horizontal}) {
    final length = horizontal ? gray.width : gray.height;
    final crossLen = horizontal ? gray.height : gray.width;

    if (length < 10) return 1;

    // 밝기 투영 프로파일 (perpendicular 방향으로 평균)
    final profile = List<double>.filled(length, 0);
    for (int i = 0; i < length; i++) {
      double sum = 0;
      for (int j = 0; j < crossLen; j++) {
        final px = horizontal ? gray.getPixel(i, j) : gray.getPixel(j, i);
        sum += img.getLuminance(px);
      }
      profile[i] = sum / crossLen;
    }

    // 가벼운 스무딩 (window=2, 5점)
    final sm = List<double>.filled(length, 0);
    for (int i = 0; i < length; i++) {
      double s = 0; int cnt = 0;
      for (int k = -2; k <= 2; k++) {
        final idx = i + k;
        if (idx >= 0 && idx < length) { s += profile[idx]; cnt++; }
      }
      sm[i] = s / cnt;
    }

    // 자기상관 계산
    final mean = sm.reduce((a, b) => a + b) / length;
    final half = math.min(length ~/ 2, 200);

    final ac = List<double>.filled(half, 0);
    for (int lag = 1; lag < half; lag++) {
      double s = 0;
      final n = length - lag;
      for (int i = 0; i < n; i++) {
        s += (sm[i] - mean) * (sm[i + lag] - mean);
      }
      ac[lag] = s / n;
    }

    // 최소 주기: 3개 이상의 주기가 있어야 함
    final minPeriod = math.max(3, length ~/ 50);

    // 자기상관에서 첫 번째 로컬 최대값 찾기 (= 기본 주기)
    int peakLag = 0;
    for (int lag = minPeriod + 1; lag < half - 1; lag++) {
      if (ac[lag] > ac[lag - 1] && ac[lag] > ac[lag + 1]) {
        peakLag = lag;
        break;
      }
    }

    if (peakLag < minPeriod) {
      // 자기상관 실패 → 로컬 미니마 카운팅으로 fallback
      int count = 0;
      for (int i = 2; i < length - 2; i++) {
        if (sm[i] <= sm[i - 1] && sm[i] <= sm[i + 1] &&
            sm[i] <= sm[i - 2] && sm[i] <= sm[i + 2]) {
          count++;
        }
      }
      return count.clamp(1, 60);
    }

    return (length.toDouble() / peakLag).round().clamp(1, 60);
  }

  // ── Mode 4: 사진 판독 ────────────────────────────────────────
  Widget _buildModePhotoReading(bool isKorean, dynamic t) {
    return Column(
      children: [
        // 사진 선택 버튼
        if (_photoBytes == null)
          GlassCard(
            child: Column(
              children: [
                Icon(Icons.camera_alt_outlined, color: C.lv, size: 40),
                const SizedBox(height: 12),
                Text(t.selectSwatchPhoto, style: T.bodyBold),
                const SizedBox(height: 4),
                Text(
                  t.tapTwoPoints10cm,
                  style: T.caption.copyWith(color: C.mu),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _showImageSourceDialog(isKorean),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(t.selectSwatchPhoto),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.lv,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // 사진 + 영역 선택 UI
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.crop_free_rounded, color: C.lv, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectionStart == null
                            ? t.tapFirstPoint
                            : _selectionEnd == null
                                ? t.tapSecondPoint
                                : t.tapTwoPoints10cm,
                        style: T.bodyBold,
                      ),
                    ),
                    if (_selectionStart != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _selectionStart = null;
                          _selectionEnd = null;
                          _detectedSts = null;
                          _detectedRows = null;
                        }),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(isKorean ? '다시 하기' : 'Reset', style: T.caption.copyWith(color: C.og)),
                      ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: C.mu, size: 20),
                      onPressed: () => _showImageSourceDialog(isKorean),
                      tooltip: isKorean ? '사진 다시 선택' : 'Change photo',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final displayWidth = constraints.maxWidth;
                      final aspectRatio = _imageSize != null
                          ? _imageSize!.height / _imageSize!.width
                          : 1.0;
                      final displayHeight = displayWidth * aspectRatio;

                      final clampedHeight = displayHeight.clamp(150.0, 400.0);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _displaySize = Size(displayWidth, clampedHeight);
                      });
                      return SizedBox(
                        width: displayWidth,
                        height: clampedHeight,
                        child: GestureDetector(
                          onTapUp: (d) {
                            final box = context.findRenderObject() as RenderBox;
                            final local = box.globalToLocal(d.globalPosition);
                            final rx = (local.dx / displayWidth).clamp(0.0, 1.0);
                            final ry = (local.dy / clampedHeight).clamp(0.0, 1.0);
                            final pt = Offset(rx, ry);
                            setState(() {
                              if (_selectionStart == null || _selectionEnd != null) {
                                // 첫 탭 또는 재시작
                                _selectionStart = pt;
                                _selectionEnd = null;
                                _detectedSts = null;
                                _detectedRows = null;
                              } else {
                                // 두 번째 탭
                                _selectionEnd = pt;
                              }
                            });
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_photoBytes!, fit: BoxFit.cover),
                              if (_selectionStart != null)
                                CustomPaint(
                                  painter: _SelectionOverlayPainter(
                                    start: _selectionStart!,
                                    end: _selectionEnd,
                                    color: C.lv,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_selectionStart != null && _selectionEnd != null && !_analyzing)
                        ? _analyzeSelection
                        : null,
                    icon: _analyzing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_fix_high_rounded, size: 18),
                    label: Text(_analyzing ? t.analyzing : t.analyzeGauge),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 결과 카드
          if (_detectedSts != null && _detectedRows != null) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: C.lv, size: 18),
                      const SizedBox(width: 6),
                      Text(t.gaugeReadingResult, style: T.bodyBold),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: C.lv.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(t.detectedStitches, style: T.caption.copyWith(color: C.mu)),
                              const SizedBox(height: 4),
                              Text(
                                '$_detectedSts',
                                style: T.h2.copyWith(color: C.lv),
                              ),
                              Text(isKorean ? '코/10cm' : 'sts/10cm', style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: C.pk.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(t.detectedRows, style: T.caption.copyWith(color: C.mu)),
                              const SizedBox(height: 4),
                              Text(
                                '$_detectedRows',
                                style: T.h2.copyWith(color: C.pk),
                              ),
                              Text(isKorean ? '단/10cm' : 'rows/10cm', style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _myStsCtrl.text = '$_detectedSts';
                          _myRowsCtrl.text = '$_detectedRows';
                          _mode = _GaugeMode.myGauge;
                        });
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(t.applyResult),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.lvD,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 8),
        _TipCard(
          isKorean: isKorean,
          text: t.photoReadingTip,
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
                  Text(isKorean ? '📏 가로 (코수 ↔ cm)' : '📏 Width (stitches ↔ cm)', style: T.bodyBold),
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
                  Text(isKorean ? '📏 세로 (단수 ↔ cm)' : '📏 Height (rows ↔ cm)', style: T.bodyBold),
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

  // ── Mode 5: 래글런 도안 자동 생성 ───────────────────────────
  EaseSettings _easeFromPreset(_EasePreset p) {
    switch (p) {
      case _EasePreset.doll:
        return EaseSettings.doll;
      case _EasePreset.slim:
        return EaseSettings.slim;
      case _EasePreset.adultStandard:
        return EaseSettings.adultStandard;
      case _EasePreset.loose:
        return EaseSettings.loose;
      case _EasePreset.oversizedCrop:
        return EaseSettings.oversizedCrop;
    }
  }

  String _easePresetLabel(_EasePreset p, bool isKorean) {
    switch (p) {
      case _EasePreset.doll:
        return isKorean ? '인형용' : 'Doll';
      case _EasePreset.slim:
        return isKorean ? '슬림 핏' : 'Slim';
      case _EasePreset.adultStandard:
        return isKorean ? '표준 핏' : 'Standard';
      case _EasePreset.loose:
        return isKorean ? '루즈 핏' : 'Loose';
      case _EasePreset.oversizedCrop:
        return isKorean ? '극단 오버사이즈' : 'Oversized Crop';
    }
  }

  String _easePresetDescription(_EasePreset p, bool isKorean) {
    final e = _easeFromPreset(p);
    if (isKorean) {
      return '가슴 +${e.chestEaseCm}cm · 상완 +${e.upperArmEaseCm}cm · 목 +${e.neckEaseCm}cm';
    }
    return 'Chest +${e.chestEaseCm}cm · Upper arm +${e.upperArmEaseCm}cm · Neck +${e.neckEaseCm}cm';
  }

  double? _parseOptional(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  void _generateRaglanPattern(bool isKorean) {
    final myS = _parse(_myStsCtrl);
    final myR = _parse(_myRowsCtrl);
    if (myS <= 0 || myR <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '내 스와치 게이지를 먼저 입력해 주세요.' : 'Please enter your gauge first.')),
      );
      return;
    }

    final chest = _parse(_chestCtrl);
    final neck = _parse(_neckCtrl);
    final bodyLen = _parse(_bodyLenCtrl);
    final sleeveLen = _parse(_sleeveLenCtrl);

    final measurements = BodyMeasurement(
      chestCm: chest,
      neckCm: neck,
      bodyLengthCm: bodyLen,
      sleeveLengthCm: sleeveLen,
      upperArmCm: _parseOptional(_upperArmCtrl),
      wristCm: _parseOptional(_wristCtrl),
      shoulderCm: _parseOptional(_shoulderCtrl),
      armholeDepthCm: _parseOptional(_armholeDepthCtrl),
    );

    final validationError = measurements.validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '입력값 오류: $validationError' : 'Input error: $validationError')),
      );
      return;
    }

    // #638 P0 — gauge 0/음수 가드 (ZeroDivisionError + NaN 방어)
    if (myS <= 0 || myR <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean
            ? '게이지는 0보다 커야 합니다 (단/10cm: $myS, 코/10cm: $myR).'
            : 'Gauge must be greater than 0.')),
      );
      return;
    }

    final gauge = UserGauge(stitchesPer10cm: myS, rowsPer10cm: myR);
    final ease = _easeFromPreset(_easePreset);

    final generator = RaglanPatternGenerator(
      measurements: measurements,
      gauge: gauge,
      ease: ease,
    );

    try {
      final result = generator.generate();
      setState(() {
        _generatedPattern = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '도안 생성 실패: $e' : 'Generation failed: $e')),
      );
    }
  }

  /// 이슈 #638 Phase 4 — 생성된 래글런 도안을 PatternChart 로 변환 후 저장,
  /// 저장 성공 시 도안에디터로 진입.
  ///
  /// PatternRepository.save() 가 narrativeBlocks / repeatRegions /
  /// knittingDirection / gauge 필드를 누락하는 기존 버그를 Firestore merge set으로 보완.
  Future<void> _saveGeneratedRaglanAsPattern(bool isKorean) async {
    final pattern = _generatedPattern;
    if (pattern == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final saved = await runWithMoriLoadingDialog<PatternChart>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          // 1) 생성된 스펙 → PatternChart 변환
          final chart = buildPatternChartFromGenerated(
            pattern,
            isKorean: isKorean,
          );

          // 2) 기본 저장 (id 발급 + aiSections/grid/narrativeText)
          final repo = ref.read(patternRepositoryProvider);
          final base = await repo.save(chart);

          // 3) repository.save()가 누락하는 필드(narrativeBlocks · repeatRegions ·
          //    knittingDirection · gauge 등)를 Firestore merge set 으로 보완.
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null || uid.isEmpty) {
            throw Exception(isKorean ? '로그인이 필요해요.' : 'Login required.');
          }
          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('pattern_charts')
              .doc(base.id);
          final full = chart.copyWith(id: base.id);
          await docRef.set({
            ...full.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return full;
        },
      );

      if (!mounted) return;
      showSavedSnackBar(
        messenger,
        message: isKorean ? '도안을 저장했어요.' : 'Pattern saved.',
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatternEditorScreen(patternId: saved.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        messenger,
        message: isKorean ? '오류가 발생했어요: $e' : 'Error: $e',
      );
    }
  }

  void _showNarrativeSheet(bool isKorean) {
    final pattern = _generatedPattern;
    if (pattern == null) return;
    final steps = pattern.toNarrativeSteps(isKorean: isKorean);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: C.lv, size: 20),
                  const SizedBox(width: 8),
                  Text(isKorean ? '서술형 도안 (12단계)' : 'Narrative Pattern', style: T.h3),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: C.mu, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: C.bd),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: steps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.lv.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.lv,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(steps[i], style: T.body.copyWith(height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 이슈 #661 — 빠른 사이즈 프리셋 카드 (여성/남성/인형 탭 + 사이즈 칩).
  Widget _buildSizePresetCard(bool isKorean) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: C.pk, size: 18),
              const SizedBox(width: 6),
              Text(isKorean ? '📋 빠른 사이즈 프리셋' : '📋 Quick Size Preset', style: T.bodyBold),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isKorean
                ? '탭 선택 후 사이즈 칩을 누르면 치수가 자동 입력돼요'
                : 'Pick a tab and tap a size to auto-fill',
            style: T.caption.copyWith(color: C.mu),
          ),
          const SizedBox(height: 12),
          // 탭 (여성 · 남성 · 인형)
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
      case _SizePresetTab.women:
        return isKorean ? '여성' : 'Women';
      case _SizePresetTab.men:
        return isKorean ? '남성' : 'Men';
      case _SizePresetTab.doll:
        return isKorean ? '인형' : 'Doll';
    }
  }

  Widget _buildSizePresetChips(bool isKorean) {
    switch (_sizePresetTab) {
      case _SizePresetTab.women:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: womenStandardSizes.map((p) {
            final key = 'women_${p.label}';
            return _buildSizeChip(
              label: p.label,
              hint: p.hint,
              selected: _selectedPresetKey == key,
              onTap: () {
                _applyMeasurementPreset(p.measurement);
                setState(() => _selectedPresetKey = key);
              },
            );
          }).toList(),
        );
      case _SizePresetTab.men:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: menStandardSizes.map((p) {
            final key = 'men_${p.label}';
            return _buildSizeChip(
              label: p.label,
              hint: p.hint,
              selected: _selectedPresetKey == key,
              onTap: () {
                _applyMeasurementPreset(p.measurement);
                setState(() => _selectedPresetKey = key);
              },
            );
          }).toList(),
        );
      case _SizePresetTab.doll:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: builtinDollPresets.map((d) {
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
          }).toList(),
        );
    }
  }

  Widget _buildSizeChip({
    required String label,
    required String hint,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: T.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : C.pkD,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: T.caption.copyWith(
                color: selected ? Colors.white.withValues(alpha: 0.85) : C.mu,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeRaglanGenerator(bool isKorean) {
    return Column(
      children: [
        // 이슈 #661 — 빠른 사이즈 프리셋 (여성/남성/인형 자동 입력)
        _buildSizePresetCard(isKorean),
        const SizedBox(height: 14),

        // 인체 치수 (필수)
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.accessibility_new_rounded, color: C.lv, size: 18),
                  const SizedBox(width: 6),
                  Text(isKorean ? '🧍 인체 치수 (cm)' : '🧍 Body Measurements (cm)', style: T.bodyBold),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isKorean ? '필수 항목을 입력하세요' : 'Enter required values',
                style: T.caption.copyWith(color: C.mu),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _NumberField(controller: _chestCtrl, label: isKorean ? '가슴 둘레 *' : 'Chest *')),
                  const SizedBox(width: 10),
                  Expanded(child: _NumberField(controller: _neckCtrl, label: isKorean ? '목 둘레 *' : 'Neck *')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _NumberField(controller: _bodyLenCtrl, label: isKorean ? '옷 길이 *' : 'Body length *')),
                  const SizedBox(width: 10),
                  Expanded(child: _NumberField(controller: _sleeveLenCtrl, label: isKorean ? '소매 길이 *' : 'Sleeve length *')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 선택 치수 (접기/펼치기)
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _optionalExpanded = !_optionalExpanded),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: C.pk, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isKorean ? '선택 치수 (비우면 자동 추정)' : 'Optional (auto-estimated if blank)',
                        style: T.bodyBold,
                      ),
                    ),
                    Icon(
                      _optionalExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: C.mu,
                      size: 20,
                    ),
                  ],
                ),
              ),
              if (_optionalExpanded) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _NumberField(controller: _upperArmCtrl, label: isKorean ? '상완 둘레' : 'Upper arm')),
                    const SizedBox(width: 10),
                    Expanded(child: _NumberField(controller: _wristCtrl, label: isKorean ? '손목 둘레' : 'Wrist')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _NumberField(controller: _shoulderCtrl, label: isKorean ? '어깨 폭' : 'Shoulder')),
                    const SizedBox(width: 10),
                    Expanded(child: _NumberField(controller: _armholeDepthCtrl, label: isKorean ? '겨드랑이 깊이' : 'Armhole depth')),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 핏 프리셋
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.style_rounded, color: C.og, size: 18),
                  const SizedBox(width: 6),
                  Text(isKorean ? '👕 핏 프리셋' : '👕 Fit Preset', style: T.bodyBold),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _EasePreset.values.map((p) {
                  final selected = _easePreset == p;
                  return GestureDetector(
                    onTap: () => setState(() => _easePreset = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? C.lv : C.lvL,
                        border: Border.all(
                          color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _easePresetLabel(p, isKorean),
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
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.og.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_easePresetLabel(_easePreset, isKorean)}: ${_easePresetDescription(_easePreset, isKorean)}',
                  style: T.caption.copyWith(color: C.tx2, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 생성 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _generateRaglanPattern(isKorean),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(isKorean ? '도안 생성' : 'Generate Pattern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 결과 카드
        if (_generatedPattern != null) ...[
          _RaglanResultCard(
            isKorean: isKorean,
            pattern: _generatedPattern!,
            onShowNarrative: () => _showNarrativeSheet(isKorean),
            onSaveAsPattern: () => _saveGeneratedRaglanAsPattern(isKorean),
          ),
          const SizedBox(height: 8),
        ],
        _TipCard(
          isKorean: isKorean,
          text: isKorean
              ? '가슴·목·옷길이·소매길이는 필수입니다. 선택 항목은 비워두면 가슴 둘레 비율로 자동 추정합니다.\n생성 후 "서술형 도안 보기"로 12단계 작업 지시를 확인하세요.'
              : 'Chest, neck, body & sleeve length are required. Blank optional values are estimated from chest ratio.\nTap "View narrative pattern" for the 12-step breakdown.',
        ),
      ],
    );
  }
}

// ── 위젯들 ────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final _GaugeMode mode;
  final bool isKorean;
  final bool canUsePhotoReading;
  final ValueChanged<_GaugeMode> onChanged;

  const _ModeSelector({
    required this.mode,
    required this.isKorean,
    required this.onChanged,
    this.canUsePhotoReading = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (_GaugeMode.myGauge, isKorean ? '크기 계산' : 'Size', false),
      (_GaugeMode.patternConvert, isKorean ? '도안 변환' : 'Pattern', false),
      (_GaugeMode.bidirectional, isKorean ? '코↔cm' : 'Sts↔cm', false),
      // 이슈 #799 — 사진 판독은 Pro 요금제 전용 (⭐ 배지 표시).
      (_GaugeMode.photoReading, isKorean ? '사진 판독' : 'Photo', true),
      // #786 — 래글런 도안 생성은 AI 패턴 생성기로 단일화. 여기 진입점 제거.
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
      children: items.map((item) {
        final selected = mode == item.$1;
        final isProTab = item.$3;
        final locked = isProTab && !canUsePhotoReading;
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isProTab) ...[
                    Text(
                      '⭐',
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : C.lvD,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : C.lvD,
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: selected ? Colors.white : C.lvD,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
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
  final VoidCallback? onPickFromSwatch;

  const _GaugeInputCard({
    required this.title,
    required this.subtitle,
    required this.stsCtrl,
    required this.rowsCtrl,
    required this.stsLabel,
    required this.rowsLabel,
    required this.color,
    this.onPickFromSwatch,
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
                    Row(
                      children: [
                        Expanded(child: Text(title, style: T.bodyBold)),
                        if (onPickFromSwatch != null)
                          GestureDetector(
                            onTap: onPickFromSwatch,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: C.lv.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: C.lv.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.library_books_outlined, size: 12, color: C.lv),
                                  const SizedBox(width: 4),
                                  Text('스와치', style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
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
              Text(isKorean ? '✨ 계산 결과' : '✨ Result', style: T.bodyBold),
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

class _SelectionOverlayPainter extends CustomPainter {
  final Offset start;
  final Offset? end;
  final Color color;

  _SelectionOverlayPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pt1 = Offset(start.dx * size.width, start.dy * size.height);

    final dotPaint = Paint()..color = color;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (end == null) {
      // 첫 번째 점만 — 원형 마커
      canvas.drawCircle(pt1, 10, dotPaint);
      canvas.drawCircle(pt1, 10, dotBorderPaint);
      return;
    }

    final pt2 = Offset(end!.dx * size.width, end!.dy * size.height);
    final rect = Rect.fromPoints(pt1, pt2);

    // 어두운 오버레이 (선택 영역 외부)
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.40);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(0, rect.bottom, size.width, size.height), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), overlayPaint);

    // 선택 영역 테두리
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(rect, borderPaint);

    // 두 대각선 점 마커
    for (final pt in [pt1, pt2]) {
      canvas.drawCircle(pt, 10, dotPaint);
      canvas.drawCircle(pt, 10, dotBorderPaint);
    }

    // 모서리 L자 마커
    const markerSize = 12.0;
    final markerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final corner in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
      final dx = corner.dx == rect.left ? 1.0 : -1.0;
      final dy = corner.dy == rect.top ? 1.0 : -1.0;
      canvas.drawLine(corner, Offset(corner.dx + markerSize * dx, corner.dy), markerPaint);
      canvas.drawLine(corner, Offset(corner.dx, corner.dy + markerSize * dy), markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter oldDelegate) =>
      start != oldDelegate.start || end != oldDelegate.end;
}

// ── 래글런 도안 결과 카드 ──────────────────────────────────────
class _RaglanResultCard extends StatelessWidget {
  final bool isKorean;
  final RaglanGeneratedPattern pattern;
  final VoidCallback onShowNarrative;
  final VoidCallback onSaveAsPattern;

  const _RaglanResultCard({
    required this.isKorean,
    required this.pattern,
    required this.onShowNarrative,
    required this.onSaveAsPattern,
  });

  @override
  Widget build(BuildContext context) {
    final p = pattern;
    final actualChest = p.actualChestCm.toStringAsFixed(1);
    final actualUpperArm = p.actualUpperArmCm.toStringAsFixed(1);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: C.lv, size: 18),
              const SizedBox(width: 6),
              Text(isKorean ? '🧶 생성된 래글런 도안' : '🧶 Generated Raglan', style: T.bodyBold),
            ],
          ),
          const SizedBox(height: 14),

          // 목 / 구간별 초기 코수
          _SectionBlock(
            title: isKorean ? '목 코잡기 & 구간 배분' : 'Neck Cast-on & Sections',
            rows: [
              _KvRow(label: isKorean ? '목 코잡기' : 'Neck cast-on', value: '${p.neckCastOn}${isKorean ? "코" : " sts"}', color: C.lv),
              _KvRow(label: isKorean ? '앞판 초기' : 'Front init', value: '${p.initFront}${isKorean ? "코" : " sts"}'),
              _KvRow(label: isKorean ? '뒷판 초기 (좌/우 각)' : 'Back init (each)', value: '${p.initBackEach}${isKorean ? "코" : " sts"}'),
              _KvRow(label: isKorean ? '소매 초기 (좌/우 각)' : 'Sleeve init (each)', value: '${p.initSleeveEach}${isKorean ? "코" : " sts"}'),
              _KvRow(label: isKorean ? '래글런 마커' : 'Raglan markers', value: '${p.raglanStitches}${isKorean ? "코 (2×4)" : " sts (2×4)"}'),
            ],
          ),
          const SizedBox(height: 12),

          // 래글런 반복
          _SectionBlock(
            title: isKorean ? '래글런 늘림' : 'Raglan Increases',
            rows: [
              _KvRow(label: isKorean ? '래글런 반복' : 'Raglan repeats', value: '${p.raglanRepeat}${isKorean ? "회" : "×"}', color: C.pk),
              _KvRow(label: isKorean ? '앞목 쉐이핑' : 'Front-neck shaping', value: '${p.frontNeckShapingRows}${isKorean ? "단" : " rows"}'),
            ],
          ),
          const SizedBox(height: 12),

          // 몸통
          _SectionBlock(
            title: isKorean ? '몸통' : 'Body',
            rows: [
              _KvRow(
                label: isKorean ? '몸통 총코' : 'Body total',
                value: '${p.bodyTotalStitches}${isKorean ? "코" : " sts"}',
                sub: isKorean ? '실제 약 ${actualChest}cm' : 'Actual ~${actualChest}cm',
                color: C.lv,
              ),
              _KvRow(label: isKorean ? '겨드랑이 감아코 (각)' : 'Underarm cast-on (each)', value: '${p.underarmCastOn}${isKorean ? "코" : " sts"}'),
              _KvRow(label: isKorean ? '몸통 메리야스' : 'Body stockinette', value: '${p.bodyRows}${isKorean ? "단" : " rows"}'),
              _KvRow(label: isKorean ? '몸통 고무단' : 'Body rib', value: '${p.bodyRibRows}${isKorean ? "단" : " rows"}'),
            ],
          ),
          const SizedBox(height: 12),

          // 소매
          _SectionBlock(
            title: isKorean ? '소매' : 'Sleeve',
            rows: [
              _KvRow(
                label: isKorean ? '소매 총코' : 'Sleeve total',
                value: '${p.sleeveTotalStitches}${isKorean ? "코" : " sts"}',
                sub: isKorean ? '상완 약 ${actualUpperArm}cm' : 'Upper arm ~${actualUpperArm}cm',
                color: C.og,
              ),
              _KvRow(label: isKorean ? '소매 메리야스' : 'Sleeve stockinette', value: '${p.sleeveRows}${isKorean ? "단" : " rows"}'),
              _KvRow(label: isKorean ? '소매 고무단' : 'Sleeve rib', value: '${p.sleeveRibRows}${isKorean ? "단" : " rows"}'),
              _KvRow(
                label: isKorean ? '코줄임' : 'Decrease',
                value: isKorean
                    ? '${p.sleeveDecreaseCount}회 / ${p.sleeveDecreaseIntervalRows}단마다'
                    : '${p.sleeveDecreaseCount}× / every ${p.sleeveDecreaseIntervalRows} rows',
              ),
            ],
          ),

          // 경고
          if (p.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: C.og.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.og.withValues(alpha: 0.30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: C.og, size: 16),
                      const SizedBox(width: 6),
                      Text(isKorean ? '경고' : 'Warnings', style: T.captionBold.copyWith(color: C.og)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...p.warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                        child: Text('• $w', style: T.caption.copyWith(color: C.tx2, height: 1.4)),
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShowNarrative,
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: Text(isKorean ? '서술형 도안 보기' : 'View narrative'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.lvD,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSaveAsPattern,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: Text(isKorean ? '도안 저장' : 'Save pattern'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.lv,
                    side: BorderSide(color: C.lv),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final List<_KvRow> rows;
  const _SectionBlock({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: T.captionBold.copyWith(color: C.mu)),
        const SizedBox(height: 6),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: r,
            )),
      ],
    );
  }
}

class _KvRow extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? color;
  const _KvRow({required this.label, required this.value, this.sub, this.color});

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
              if (sub != null) Text(sub!, style: T.caption.copyWith(color: C.mu)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: T.bodyBold.copyWith(color: color ?? C.tx, fontSize: 15),
        ),
      ],
    );
  }
}

// ── 스와치 등록 버튼 ─────────────────────────────────────────────
class _RegisterSwatchButton extends ConsumerWidget {
  final bool isKorean;
  final TextEditingController myStsCtrl;
  final TextEditingController myRowsCtrl;

  const _RegisterSwatchButton({
    required this.isKorean,
    required this.myStsCtrl,
    required this.myRowsCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sts = int.tryParse(myStsCtrl.text) ?? 0;
    final rows = int.tryParse(myRowsCtrl.text) ?? 0;
    final isEnabled = sts > 0 && rows > 0;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isEnabled
            ? () {
                final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
                final initial = SwatchModel.empty(uid: uid).copyWith(
                  beforeStitchCount: sts,
                  beforeRowCount: rows,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SwatchInputScreen(initialSwatch: initial),
                  ),
                );
              }
            : null,
        icon: const Icon(Icons.add_circle_outline, size: 18),
        label: Text(isKorean ? '이 게이지로 스와치 등록하기' : 'Register Swatch with This Gauge'),
        style: OutlinedButton.styleFrom(
          foregroundColor: C.lv,
          side: BorderSide(color: isEnabled ? C.lv : C.bd),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
