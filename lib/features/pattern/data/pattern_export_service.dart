import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/pattern_chart.dart';

/// 도안 내보내기·가져오기 공통 서비스
/// - 이미지(PNG) 내보내기
/// - .mori 파일 내보내기/가져오기
/// - PDF 매거진 스타일 내보내기
class PatternExportService {
  /// 도안 캔버스를 PNG 이미지로 변환 후 공유
  /// [boundaryKey] 는 ChartCanvas를 감싼 RepaintBoundary의 GlobalKey
  static Future<void> exportImage({
    required GlobalKey boundaryKey,
    required String title,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('캔버스를 찾을 수 없어요.');
    }
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('이미지 변환에 실패했어요.');
    }
    final bytes = byteData.buffer.asUint8List();

    final safeTitle = _sanitizeFileName(title);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safeTitle.png');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: title,
      ),
    );
  }

  /// PatternChart를 .mori 파일(JSON)로 내보내기
  static Future<void> exportMoriFile({required PatternChart chart}) async {
    final payload = <String, dynamic>{
      'format': 'mori',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'chart': chart.toJson(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final safeTitle = _sanitizeFileName(chart.title);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safeTitle.mori');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        text: chart.title,
      ),
    );
  }

  /// 사용자로부터 .mori 파일을 선택받아 PatternChart로 역직렬화
  /// null 반환 시 사용자가 취소한 경우
  static Future<PatternChart?> importMoriFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;
    final name = picked.name.toLowerCase();
    if (!name.endsWith('.mori') && !name.endsWith('.json')) {
      throw Exception('.mori 파일만 가져올 수 있어요.');
    }

    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null) {
      throw Exception('파일을 읽을 수 없어요.');
    }

    final jsonStr = utf8.decode(bytes);
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('올바른 .mori 파일이 아니에요.');
    }
    final chartJson = decoded['chart'];
    if (chartJson is! Map<String, dynamic>) {
      throw Exception('도안 데이터를 찾을 수 없어요.');
    }
    // id는 새로 저장될 때 할당되도록 비움
    final chart = PatternChart.fromJson(chartJson);
    return chart.copyWith(id: '');
  }

  /// PDF 매거진 스타일 내보내기
  /// - 타이틀 페이지, 그리드 정보, 칼라 팔레트, 도안 이미지
  static Future<Uint8List> buildMagazinePdf({
    required PatternChart chart,
    required Uint8List? chartImageBytes,
    required String creatorName,
  }) async {
    final pdfDoc = pw.Document(
      title: chart.title,
      author: creatorName,
      creator: 'MoriKnit',
    );

    // 팔레트 수집
    final paletteColors = _collectPaletteColors(chart);

    // 도안 이미지 (있으면)
    final pwImage =
        chartImageBytes != null ? pw.MemoryImage(chartImageBytes) : null;

    final now = DateTime.now();
    final dateStr =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
        build: (ctx) {
          return [
            // ── 헤더 ──────────────────────────────────────
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.2),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'MoriKnit',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.deepPurple400,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.Text(
                    'PATTERN MAGAZINE · $dateStr',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── 타이틀 ────────────────────────────────────
            pw.Text(
              chart.title,
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Designed by $creatorName',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.SizedBox(height: 18),

            // ── 도안 정보 카드 ───────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _infoBlock('Rows', '${chart.rows}'),
                  _divider(),
                  _infoBlock('Cols', '${chart.cols}'),
                  _divider(),
                  _infoBlock(
                    'Mode',
                    _modeLabel(chart.mode),
                  ),
                  _divider(),
                  _infoBlock(
                    'Colors',
                    '${paletteColors.length}',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── 칼라 팔레트 ──────────────────────────────
            if (paletteColors.isNotEmpty) ...[
              pw.Text(
                'COLOR PALETTE',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                  letterSpacing: 1.4,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: paletteColors.map((c) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                          color: PdfColors.grey300, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 12,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            color: c,
                            shape: pw.BoxShape.circle,
                            border: pw.Border.all(
                                color: PdfColors.grey400, width: 0.3),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          '#${c.toHex().toUpperCase()}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // ── 도안 이미지 ──────────────────────────────
            pw.Text(
              'CHART',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
                letterSpacing: 1.4,
              ),
            ),
            pw.SizedBox(height: 8),
            if (pwImage != null)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border:
                      pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Image(pwImage, fit: pw.BoxFit.contain),
                ),
              )
            else
              _buildTablePreview(chart),

            // ── 서술형 도안 (있으면) ─────────────────────
            if (chart.narrativeText.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                'NARRATIVE',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                  letterSpacing: 1.4,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  chart.narrativeText,
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 4),
                ),
              ),
            ],
          ];
        },
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MoriKnit · $creatorName',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey500),
              ),
              pw.Text(
                '${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey500),
              ),
            ],
          ),
        ),
      ),
    );

    return pdfDoc.save();
  }

  // ── 내부 헬퍼 ──────────────────────────────────────────
  static List<PdfColor> _collectPaletteColors(PatternChart chart) {
    final seen = <int>{};
    final list = <PdfColor>[];
    for (final row in chart.grid) {
      for (final cell in row) {
        final c = cell.color;
        if (c == null) continue;
        final argb = c.toARGB32();
        if (seen.contains(argb)) continue;
        seen.add(argb);
        final rv = ((argb >> 16) & 0xFF) / 255.0;
        final gv = ((argb >> 8) & 0xFF) / 255.0;
        final bv = (argb & 0xFF) / 255.0;
        // 순백 제외
        if (rv > 0.98 && gv > 0.98 && bv > 0.98) continue;
        list.add(PdfColor(rv, gv, bv, 1.0));
      }
    }
    return list;
  }

  static pw.Widget _infoBlock(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  static pw.Widget _divider() => pw.Container(
        width: 1,
        height: 30,
        color: PdfColors.grey300,
      );

  static String _modeLabel(ChartMode mode) {
    switch (mode) {
      case ChartMode.color:
        return 'Color';
      case ChartMode.symbol:
        return 'Symbol';
      case ChartMode.colorChart:
        return 'Color Chart';
      case ChartMode.narrative:
        return 'Text';
    }
  }

  /// 이미지가 없을 때 대체 테이블 렌더링
  static pw.Widget _buildTablePreview(PatternChart chart) {
    const cellSize = 10.0;
    final cols = chart.cols;
    final rows = chart.rows;
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        for (var i = 0; i < cols; i++)
          i: const pw.FixedColumnWidth(cellSize)
      },
      children: List.generate(
        rows,
        (r) => pw.TableRow(
          children: List.generate(cols, (c) {
            final cell = r < chart.grid.length && c < chart.grid[r].length
                ? chart.grid[r][c]
                : null;
            PdfColor? pdfColor;
            final color = cell?.color;
            if (color != null) {
              final argb = color.toARGB32();
              final rv = ((argb >> 16) & 0xFF) / 255.0;
              final gv = ((argb >> 8) & 0xFF) / 255.0;
              final bv = (argb & 0xFF) / 255.0;
              if (!(rv > 0.98 && gv > 0.98 && bv > 0.98)) {
                pdfColor = PdfColor(rv, gv, bv, 1.0);
              }
            }
            return pw.Container(height: cellSize, color: pdfColor);
          }),
        ),
      ),
    );
  }

  static String _sanitizeFileName(String input) {
    final cleaned = input.trim().isEmpty ? 'pattern' : input.trim();
    return cleaned.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
