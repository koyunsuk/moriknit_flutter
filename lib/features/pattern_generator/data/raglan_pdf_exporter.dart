// lib/features/pattern_generator/data/raglan_pdf_exporter.dart
//
// 이슈 #664 Phase 7 — 래글런 도안 결과를 출판용 PDF로 변환.
//
// 구성 페이지:
//   1) 표지 — 제목/부제/작성자/날짜 + 도식 자리.
//   2) 요약 — 입력 치수/게이지/핏 + 메타.
//   3) 단계별 — RaglanGeneratedPattern.toNarrativeSteps() 12단 + 도식 자리.
//   4) 마무리 — 워터마크 + 라이센스.
//
// 한글 폰트는 assets/fonts/NotoSansKR-* 사용 (오프라인 보장).

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/raglan_generated_pattern.dart';

/// 래글런 도안 PDF 출력기.
class RaglanPdfExporter {
  // 모리니트 브랜드 색상 (라벤더 계열).
  static const PdfColor _lv = PdfColor.fromInt(0xFF8B7AB8);
  static const PdfColor _lvDark = PdfColor.fromInt(0xFF6B5A98);
  static const PdfColor _lvLight = PdfColor.fromInt(0xFFEDE7F6);
  static const PdfColor _txDark = PdfColor.fromInt(0xFF2E2A3D);
  static const PdfColor _txMid = PdfColor.fromInt(0xFF555068);
  static const PdfColor _txMuted = PdfColor.fromInt(0xFF8A879C);
  static const PdfColor _bgSoft = PdfColor.fromInt(0xFFF7F5FB);
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E0F2);

  /// 도안 + 메타 → PDF 바이트 생성.
  ///
  /// [schematicImage]: 표지에 임베드할 전체 도식 PNG 바이트 (RaglanSchematicView 캡처).
  /// [stepImages]: 단계별 도식 PNG 바이트 맵 (key=단계번호 1~12).
  /// 둘 다 null/비어있을 경우 placeholder로 폴백.
  Future<Uint8List> generate({
    required RaglanGeneratedPattern pattern,
    required String title,
    String? subtitle,
    String? author,
    DateTime? createdAt,
    Uint8List? schematicImage,
    Map<int, Uint8List> stepImages = const {},
  }) async {
    try {
      final theme = await _buildTheme();
      final doc = pw.Document(
        title: title,
        author: author ?? 'MoriKnit',
        creator: 'MoriKnit Pattern Generator',
        subject: subtitle ?? '래글런 도안',
        theme: theme,
      );

      final created = createdAt ?? DateTime.now();
      final steps = pattern.toNarrativeSteps(isKorean: true);

      // 1. 표지.
      doc.addPage(_buildCoverPage(
        title: title,
        subtitle: subtitle,
        author: author,
        createdAt: created,
        schematicImage: schematicImage,
      ));

      // 2. 요약 + 단계 + 마무리 (다중 페이지로 자동 흐름).
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
        header: (ctx) => _buildHeader(title),
        footer: (ctx) => _buildFooter(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          _buildSummarySection(pattern),
          pw.SizedBox(height: 16),
          if (pattern.warnings.isNotEmpty) ...[
            _buildWarningsSection(pattern.warnings),
            pw.SizedBox(height: 16),
          ],
          _buildStepsHeader(),
          pw.SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++) ...[
            _buildStepBlock(
              index: i + 1,
              text: steps[i],
              diagramImage: stepImages[i + 1],
            ),
            pw.SizedBox(height: 10),
          ],
          pw.SizedBox(height: 18),
          _buildClosingSection(),
        ],
      ));

      return await doc.save();
    } catch (e) {
      // 사용자 친화 한국어 에러 메시지로 변환 후 재던짐.
      throw Exception('PDF 생성에 실패했어요: $e');
    }
  }

  /// 생성 + 시스템 공유 시트.
  Future<void> share({
    required RaglanGeneratedPattern pattern,
    required String title,
    String? subtitle,
    Uint8List? schematicImage,
    Map<int, Uint8List> stepImages = const {},
  }) async {
    try {
      final bytes = await generate(
        pattern: pattern,
        title: title,
        subtitle: subtitle,
        schematicImage: schematicImage,
        stepImages: stepImages,
      );
      final fileName = '${_safeFileName(title)}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      throw Exception('PDF 공유에 실패했어요: $e');
    }
  }

  /// 생성 + 인쇄 다이얼로그.
  Future<void> print({
    required RaglanGeneratedPattern pattern,
    required String title,
    Uint8List? schematicImage,
    Map<int, Uint8List> stepImages = const {},
  }) async {
    try {
      final bytes = await generate(
        pattern: pattern,
        title: title,
        schematicImage: schematicImage,
        stepImages: stepImages,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: title,
      );
    } catch (e) {
      throw Exception('PDF 인쇄에 실패했어요: $e');
    }
  }

  // ── 테마 ────────────────────────────────────────────────────────────
  /// 한글 폰트 적용된 ThemeData 생성.
  Future<pw.ThemeData> _buildTheme() async {
    pw.Font regular;
    pw.Font bold;
    try {
      regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'),
      );
      bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'),
      );
    } catch (_) {
      // 로컬 자산 실패 시 Google Fonts로 폴백 (네트워크 필요).
      regular = await PdfGoogleFonts.notoSansKRRegular();
      bold = await PdfGoogleFonts.notoSansKRBold();
    }
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
    );
  }

  // ── 표지 페이지 ─────────────────────────────────────────────────────
  pw.Page _buildCoverPage({
    required String title,
    String? subtitle,
    String? author,
    required DateTime createdAt,
    Uint8List? schematicImage,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _lv, width: 1.5),
            borderRadius: pw.BorderRadius.circular(20),
            color: _bgSoft,
          ),
          padding: const pw.EdgeInsets.all(36),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 상단 라벨.
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _lv,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  'MORIKNIT  PATTERN',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 36),
              // 제목.
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                  color: _txDark,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: _txMid,
                    height: 1.4,
                  ),
                ),
              ],
              pw.SizedBox(height: 40),
              // 도식 영역: 캡처된 이미지가 있으면 임베드, 없으면 placeholder.
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: _border, width: 1),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(16),
                  child: schematicImage != null
                      ? pw.Image(
                          pw.MemoryImage(schematicImage),
                          fit: pw.BoxFit.contain,
                        )
                      : pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              '도식 자리',
                              style: pw.TextStyle(
                                fontSize: 18,
                                color: _txMuted,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              '도식 캡처 실패 — 화면에 도식이 표시된 상태에서 다시 시도해 주세요',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: _txMuted,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                ),
              ),
              pw.SizedBox(height: 24),
              // 메타 (작성자/날짜).
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '작성자',
                        style: pw.TextStyle(fontSize: 9, color: _txMuted),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        author ?? '익명',
                        style: pw.TextStyle(
                          fontSize: 13,
                          color: _txDark,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '작성일',
                        style: pw.TextStyle(fontSize: 9, color: _txMuted),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        _formatDate(createdAt),
                        style: pw.TextStyle(
                          fontSize: 13,
                          color: _txDark,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 헤더/푸터 (요약~본문 페이지 공통) ─────────────────────────────
  pw.Widget _buildHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              color: _txMid,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'MoriKnit',
            style: pw.TextStyle(
              fontSize: 10,
              color: _lv,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(int page, int total) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      margin: const pw.EdgeInsets.only(top: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 1)),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        '$page / $total',
        style: pw.TextStyle(fontSize: 9, color: _txMuted),
      ),
    );
  }

  // ── 요약 섹션 ───────────────────────────────────────────────────────
  pw.Widget _buildSummarySection(RaglanGeneratedPattern p) {
    final m = p.measurements;
    final g = p.gauge;
    final e = p.ease;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('요약'),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 입력 치수.
            pw.Expanded(
              child: _miniCard(
                heading: '입력 치수',
                rows: [
                  ['가슴 둘레', '${_fmt(m.chestCm)} cm'],
                  ['목 둘레', '${_fmt(m.neckCm)} cm'],
                  ['옷 길이', '${_fmt(m.bodyLengthCm)} cm'],
                  ['소매 길이', '${_fmt(m.sleeveLengthCm)} cm'],
                  if (m.upperArmCm != null)
                    ['상완 둘레', '${_fmt(m.upperArmCm!)} cm'],
                  if (m.wristCm != null)
                    ['손목 둘레', '${_fmt(m.wristCm!)} cm'],
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            // 게이지 + 여유.
            pw.Expanded(
              child: _miniCard(
                heading: '게이지 · 여유',
                rows: [
                  ['게이지 (코)', '${_fmt(g.stitchesPer10cm)} / 10cm'],
                  ['게이지 (단)', '${_fmt(g.rowsPer10cm)} / 10cm'],
                  ['가슴 여유', '${_fmt(e.chestEaseCm)} cm'],
                  ['상완 여유', '${_fmt(e.upperArmEaseCm)} cm'],
                  ['목 여유', '${_fmt(e.neckEaseCm)} cm'],
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        // 도안 메타.
        _miniCard(
          heading: '도안 메타',
          rows: [
            ['목둘레 코잡기', '${p.neckCastOn} 코'],
            ['래글런 늘림 반복', '${p.raglanRepeat} 회'],
            ['앞목 쉐이핑 단수', '${p.frontNeckShapingRows} 단'],
            ['소매 분리 후 몸통', '${p.bodyTotalStitches} 코'],
            ['몸통 단수 (메리야스)', '${p.bodyRows} 단'],
            ['몸통 고무단', '${p.bodyRibRows} 단'],
            ['소매 총 코수', '${p.sleeveTotalStitches} 코'],
            ['소매 단수 (메리야스)', '${p.sleeveRows} 단'],
            ['소매 코줄임', '${p.sleeveDecreaseCount}회 / ${p.sleeveDecreaseIntervalRows}단마다'],
            ['실제 가슴 둘레', '${_fmt(p.actualChestCm)} cm'],
            ['실제 상완 둘레', '${_fmt(p.actualUpperArmCm)} cm'],
          ],
        ),
      ],
    );
  }

  // ── 경고 섹션 ───────────────────────────────────────────────────────
  pw.Widget _buildWarningsSection(List<String> warnings) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFF6E6),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFE0A82E),
          width: 1,
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '경고',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF8A6A00),
            ),
          ),
          pw.SizedBox(height: 4),
          for (final w in warnings)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                '• $w',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: const PdfColor.fromInt(0xFF6A5200),
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 단계별 섹션 ─────────────────────────────────────────────────────
  pw.Widget _buildStepsHeader() {
    return _sectionTitle('단계별 도안 (12단계)');
  }

  pw.Widget _buildStepBlock({
    required int index,
    required String text,
    Uint8List? diagramImage,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _border, width: 1),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 26,
                height: 26,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: _lv,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Text(
                  '$index',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                _stepTitle(index),
                style: pw.TextStyle(
                  fontSize: 13,
                  color: _lvDark,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 11,
              color: _txDark,
              height: 1.5,
            ),
          ),
          // 도식 영역: 캡처된 이미지가 있을 때만 표시.
          // (10번 단계는 도식이 원래 없으므로 placeholder도 표시 안 함)
          if (diagramImage != null) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: _border, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              alignment: pw.Alignment.center,
              child: pw.ConstrainedBox(
                constraints: const pw.BoxConstraints(
                  maxHeight: 180,
                  maxWidth: double.infinity,
                ),
                child: pw.Image(
                  pw.MemoryImage(diagramImage),
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 마무리 섹션 ─────────────────────────────────────────────────────
  pw.Widget _buildClosingSection() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _bgSoft,
        border: pw.Border.all(color: _lv, width: 1),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: _lv,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'MoriKnit',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                '도안 생성기로 만든 문서',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: _txMid,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '라이센스 안내',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _txDark,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '• 본 도안은 사용자의 입력 치수와 게이지를 기반으로 모리니트 패턴 생성기가 자동 생성한 문서입니다.\n'
            '• 개인적인 뜨개 활동 및 비상업적 공유 용도로 자유롭게 활용 가능합니다.\n'
            '• 모리니트 자산을 활용한 상업적 판매(완성품/도안 재판매)는 마켓플레이스 정책을 따릅니다.\n'
            '• 자세한 정책은 moriknit.com 을 참고해 주세요.',
            style: pw.TextStyle(
              fontSize: 10,
              color: _txMid,
              height: 1.55,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'Made with MoriKnit  ·  moriknit.com',
              style: pw.TextStyle(
                fontSize: 9,
                color: _txMuted,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 공통 위젯 ───────────────────────────────────────────────────────
  pw.Widget _sectionTitle(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _lvLight,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          color: _lvDark,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _miniCard({
    required String heading,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _border, width: 1),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            heading,
            style: pw.TextStyle(
              fontSize: 11,
              color: _lvDark,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: _border, height: 1),
          pw.SizedBox(height: 6),
          for (final row in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    row[0],
                    style: pw.TextStyle(fontSize: 10, color: _txMid),
                  ),
                  pw.Text(
                    row[1],
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _txDark,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 유틸 ────────────────────────────────────────────────────────────
  /// 숫자 포맷 (소수 있으면 1자리, 정수면 그대로).
  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  /// 날짜 포맷 (yyyy. MM. dd).
  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y. $m. $day';
  }

  /// 단계 번호 → 한국어 제목 (toNarrativeSteps와 1:1 매핑).
  String _stepTitle(int index) {
    switch (index) {
      case 1:
        return '목둘레 코잡기';
      case 2:
        return '목 고무단';
      case 3:
        return '셋업단 + 앞목 쉐이핑';
      case 4:
        return '래글런 늘림 반복';
      case 5:
        return '래글런 후 콧수 확인';
      case 6:
        return '소매 분리';
      case 7:
        return '몸통 메리야스';
      case 8:
        return '몸통 고무단';
      case 9:
        return '몸통 마무리';
      case 10:
        return '소매 시작';
      case 11:
        return '소매 뜨기 + 코줄임';
      case 12:
        return '소매 마무리';
      default:
        return '단계 $index';
    }
  }

  /// 파일명에 안전한 문자열로 정제.
  String _safeFileName(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'moriknit_pattern' : cleaned;
  }
}
