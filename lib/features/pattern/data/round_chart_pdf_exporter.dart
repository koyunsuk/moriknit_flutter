// lib/features/pattern/data/round_chart_pdf_exporter.dart
//
// 이슈 #665 Phase 5 — 원형(코바늘) 도안 PDF 내보내기.
//
// PDF 페이지 구성:
//   1) 표지 — 제목/부제/작성일/썸네일(원형 도식 PNG)
//   2) 도식 페이지 — 원형 도안 큰 사이즈 (A4 폭 ~80%)
//   3) 라운드별 코수 표 (R1: 6코, R2: 12코, ...)
//   4) 사용된 심볼 범례 (셀에 사용된 심볼만)
//   5) 마무리 — 라이센스 (RaglanPdfExporter와 동일)
//
// 한글 폰트: assets/fonts/NotoSansKR-* (오프라인 보장).
// 도식 렌더링: round_chart_thumbnail.generateRoundThumbnail() 재사용.

import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/crochet_symbols.dart';
import '../domain/pattern_chart.dart';
import '../domain/round_chart.dart';
import 'round_chart_thumbnail.dart';

/// 원형(코바늘) 도안 PDF 출력기.
class RoundChartPdfExporter {
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
  /// [pattern]: chartType이 round*이고 roundData != null 이어야 함.
  /// [coverThumbnail]: 표지에 임베드할 썸네일 PNG 바이트. null 시 자동 생성.
  /// [largeSchematic]: 도식 페이지 본문 PNG. null 시 자동 생성 (큰 사이즈).
  Future<Uint8List> generate({
    required PatternChart pattern,
    String? subtitle,
    String? author,
    DateTime? createdAt,
    Uint8List? coverThumbnail,
    Uint8List? largeSchematic,
  }) async {
    final round = pattern.roundData;
    if (round == null) {
      throw Exception('원형 도안 데이터가 없어요.');
    }

    try {
      final theme = await _buildTheme();
      final doc = pw.Document(
        title: pattern.title,
        author: author ?? 'MoriKnit',
        creator: 'MoriKnit Round Pattern',
        subject: subtitle ?? '코바늘 라운드 도안',
        theme: theme,
      );

      final created = createdAt ?? DateTime.now();

      // 썸네일·도식 자동 생성 (호출자가 안 줬을 때).
      final cover = coverThumbnail ??
          await generateRoundThumbnail(
            round,
            size: const Size(512, 512),
            showGuides: false,
            showRoundLabels: false,
          );
      final big = largeSchematic ??
          await generateRoundThumbnail(
            round,
            size: const Size(900, 900),
            showGuides: true,
            showRoundLabels: true,
          );

      // 1) 표지.
      doc.addPage(_buildCoverPage(
        title: pattern.title,
        subtitle: subtitle ?? '코바늘 라운드 도안',
        author: author,
        createdAt: created,
        rounds: round.rounds,
        thumbnail: cover,
      ));

      // 2) 본문 (다중 페이지 자동 흐름).
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
        header: (ctx) => _buildHeader(pattern.title),
        footer: (ctx) => _buildFooter(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          // 도식 페이지.
          _sectionTitle('도식'),
          pw.SizedBox(height: 8),
          _buildSchematicBlock(big),
          pw.SizedBox(height: 16),

          // 라운드별 코수 표.
          _sectionTitle('라운드별 코수'),
          pw.SizedBox(height: 8),
          _buildRoundCountsTable(round),
          pw.SizedBox(height: 16),

          // 사용된 심볼 범례.
          _sectionTitle('사용된 심볼 범례'),
          pw.SizedBox(height: 8),
          _buildSymbolLegend(round),
          pw.SizedBox(height: 18),

          // 마무리.
          _buildClosingSection(),
        ],
      ));

      return await doc.save();
    } catch (e) {
      throw Exception('PDF 생성에 실패했어요: $e');
    }
  }

  /// 생성 + 시스템 공유 시트.
  Future<void> share({
    required PatternChart pattern,
    String? subtitle,
    String? author,
    Uint8List? coverThumbnail,
    Uint8List? largeSchematic,
  }) async {
    try {
      final bytes = await generate(
        pattern: pattern,
        subtitle: subtitle,
        author: author,
        coverThumbnail: coverThumbnail,
        largeSchematic: largeSchematic,
      );
      final fileName = '${_safeFileName(pattern.title)}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      throw Exception('PDF 공유에 실패했어요: $e');
    }
  }

  /// 생성 + 인쇄 다이얼로그.
  Future<void> print({
    required PatternChart pattern,
    String? subtitle,
    String? author,
    Uint8List? coverThumbnail,
    Uint8List? largeSchematic,
  }) async {
    try {
      final bytes = await generate(
        pattern: pattern,
        subtitle: subtitle,
        author: author,
        coverThumbnail: coverThumbnail,
        largeSchematic: largeSchematic,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: pattern.title,
      );
    } catch (e) {
      throw Exception('PDF 인쇄에 실패했어요: $e');
    }
  }

  // ── 테마 ────────────────────────────────────────────────────────────
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
      regular = await PdfGoogleFonts.notoSansKRRegular();
      bold = await PdfGoogleFonts.notoSansKRBold();
    }
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  // ── 표지 페이지 ─────────────────────────────────────────────────────
  pw.Page _buildCoverPage({
    required String title,
    required String subtitle,
    String? author,
    required DateTime createdAt,
    required int rounds,
    Uint8List? thumbnail,
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
              // 상단 라벨 (코바늘 도안 명시).
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
                  'MORIKNIT  ROUND  CROCHET',
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
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: _txDark,
                  height: 1.2,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                subtitle,
                style: pw.TextStyle(
                  fontSize: 14,
                  color: _txMid,
                  height: 1.4,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '총 $rounds 라운드',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: _txMuted,
                ),
              ),
              pw.SizedBox(height: 28),
              // 썸네일 영역.
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
                  child: thumbnail != null
                      ? pw.Image(
                          pw.MemoryImage(thumbnail),
                          fit: pw.BoxFit.contain,
                        )
                      : pw.Text(
                          '도식 자리',
                          style: pw.TextStyle(
                            fontSize: 16,
                            color: _txMuted,
                          ),
                        ),
                ),
              ),
              pw.SizedBox(height: 24),
              // 메타.
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('작성자',
                          style:
                              pw.TextStyle(fontSize: 9, color: _txMuted)),
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
                      pw.Text('작성일',
                          style:
                              pw.TextStyle(fontSize: 9, color: _txMuted)),
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

  // ── 헤더/푸터 ───────────────────────────────────────────────────────
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
            'MoriKnit · Round',
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

  // ── 도식 블록 (큰 사이즈) ───────────────────────────────────────────
  pw.Widget _buildSchematicBlock(Uint8List? bytes) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _border, width: 1),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      alignment: pw.Alignment.center,
      child: bytes != null
          ? pw.ConstrainedBox(
              constraints: const pw.BoxConstraints(
                maxHeight: 460, // A4 폭의 약 80% 영역에 맞춤.
                maxWidth: double.infinity,
              ),
              child: pw.Image(
                pw.MemoryImage(bytes),
                fit: pw.BoxFit.contain,
              ),
            )
          : pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Text(
                '도식을 생성할 수 없어요',
                style: pw.TextStyle(fontSize: 11, color: _txMuted),
              ),
            ),
    );
  }

  // ── 라운드별 코수 표 ────────────────────────────────────────────────
  pw.Widget _buildRoundCountsTable(RoundChart round) {
    final headers = ['라운드', '코수', '시작 각도'];
    final rows = <List<String>>[];
    for (var r = 1; r <= round.rounds; r++) {
      final count = round.stitchCountForRound(r);
      final deg = (round.startAngleForRound(r) * 180 / 3.141592653589793)
          .toStringAsFixed(0);
      rows.add(['R$r', '$count 코', '$deg°']);
    }
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _lvLight),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _lvDark,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (final cell in row)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: pw.Text(
                    cell,
                    style: pw.TextStyle(fontSize: 10, color: _txDark),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // ── 사용된 심볼 범례 ────────────────────────────────────────────────
  pw.Widget _buildSymbolLegend(RoundChart round) {
    // 셀에 실제로 사용된 심볼 ID만 추출.
    final usedIds = <String>{};
    for (final cell in round.cells.values) {
      final sid = cell.symbolId;
      if (sid != null && sid.isNotEmpty) usedIds.add(sid);
    }
    if (usedIds.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _bgSoft,
          border: pw.Border.all(color: _border, width: 1),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Text(
          '사용된 심볼이 없어요. 도식만 표기된 도안입니다.',
          style: pw.TextStyle(fontSize: 11, color: _txMid),
        ),
      );
    }

    final entries = kCrochetSymbols.where((s) => usedIds.contains(s.id)).toList();

    // 알 수 없는 ID는 별도 분리 (라이브러리에 없는 심볼).
    final knownIds = entries.map((e) => e.id).toSet();
    final unknownIds = usedIds.difference(knownIds).toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.6),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(0.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _lvLight),
              children: [
                for (final h in ['약어', '한글명', '영문명', '카테고리'])
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: _lvDark,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            for (final s in entries)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    child: pw.Text(
                      s.abbreviation,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: _lvDark,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    child: pw.Text(s.labelKo,
                        style: pw.TextStyle(fontSize: 10, color: _txDark)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    child: pw.Text(s.labelEn,
                        style: pw.TextStyle(fontSize: 10, color: _txMid)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    child: pw.Text(_categoryLabel(s.category),
                        style: pw.TextStyle(fontSize: 10, color: _txMid)),
                  ),
                ],
              ),
          ],
        ),
        if (unknownIds.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            '※ 라이브러리에 등록되지 않은 심볼: ${unknownIds.join(", ")}',
            style: pw.TextStyle(fontSize: 9, color: _txMuted),
          ),
        ],
      ],
    );
  }

  String _categoryLabel(CrochetCategory c) {
    switch (c) {
      case CrochetCategory.basic:
        return '기초코';
      case CrochetCategory.decrease:
        return '코줄임';
      case CrochetCategory.increase:
        return '코늘림';
      case CrochetCategory.special:
        return '특수·장식';
      case CrochetCategory.edge:
        return '가장자리·공간';
    }
  }

  // ── 마무리 섹션 (RaglanPdfExporter와 동일 톤) ──────────────────────
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
                '원형 도안 에디터로 만든 문서',
                style: pw.TextStyle(fontSize: 11, color: _txMid),
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
            '• 본 도안은 모리니트 원형 도안 에디터에서 작성된 문서입니다.\n'
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

  // ── 유틸 ────────────────────────────────────────────────────────────
  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y. $m. $day';
  }

  String _safeFileName(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'moriknit_round' : cleaned;
  }
}
