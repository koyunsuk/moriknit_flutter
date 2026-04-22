import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../swatch/domain/swatch_model.dart';
import '../../swatch/presentation/swatch_input_screen.dart';

enum _GaugeMode { myGauge, patternConvert, bidirectional, photoReading }

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
              ] else ...[
                _buildModePhotoReading(isKorean, t),
              ],
              const SizedBox(height: 20),
              _RegisterSwatchButton(
                isKorean: isKorean,
                myStsCtrl: _myStsCtrl,
                myRowsCtrl: _myRowsCtrl,
              ),
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
                  separatorBuilder: (_, __) => Divider(height: 1, color: C.bd),
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
      (_GaugeMode.photoReading, isKorean ? '사진 판독' : 'Photo'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
