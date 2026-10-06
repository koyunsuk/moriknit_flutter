import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/label_template.dart';

/// #889 — D11 Niimbot 지원 3사이즈
enum LabelSize {
  s40x12, // 40mm×12mm
  s40x15, // 40mm×15mm
  s40x30, // 40mm×30mm
}

extension LabelSizeExt on LabelSize {
  String get label {
    switch (this) {
      case LabelSize.s40x12: return '40×12mm';
      case LabelSize.s40x15: return '40×15mm';
      case LabelSize.s40x30: return '40×30mm';
    }
  }
}

class LabelPdfGenerator {
  static PdfPageFormat _pageFormat(LabelSize size) {
    switch (size) {
      case LabelSize.s40x12:
        return PdfPageFormat(
            40 * PdfPageFormat.mm, 12 * PdfPageFormat.mm,
            marginAll: 2 * PdfPageFormat.mm);
      case LabelSize.s40x15:
        return PdfPageFormat(
            40 * PdfPageFormat.mm, 15 * PdfPageFormat.mm,
            marginAll: 2 * PdfPageFormat.mm);
      case LabelSize.s40x30:
        return PdfPageFormat(
            40 * PdfPageFormat.mm, 30 * PdfPageFormat.mm,
            marginAll: 3 * PdfPageFormat.mm);
    }
  }

  /// [size]: 라벨 크기 (기본 40×30mm)
  /// [showQr]: QR코드 표시 여부 (기본 true)
  /// [deepLink]: QR코드에 인코딩할 딥링크 (예: 'moriknit://open?type=swatch&id=xxx')
  static Future<Uint8List> generate(
    LabelData data, {
    LabelSize size = LabelSize.s40x30,
    bool showQr = true,
    String? deepLink,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: _pageFormat(size),
        build: (ctx) => _buildLabel(ctx, data, size: size, showQr: showQr, deepLink: deepLink),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildLabel(
    pw.Context ctx,
    LabelData data, {
    required LabelSize size,
    required bool showQr,
    String? deepLink,
  }) {
    final activeFields = data.enabledFields
        .where((k) => data.fields.containsKey(k) && data.fields[k]!.isNotEmpty)
        .toList();

    final hasQr = showQr && deepLink != null && deepLink.isNotEmpty;
    final isNarrow = size == LabelSize.s40x12 || size == LabelSize.s40x15;

    // ── QR코드 위젯 ────────────────────────────────────────────────
    pw.Widget? qrWidget;
    if (hasQr) {
      final qrSize = isNarrow ? 8.0 * PdfPageFormat.mm : 20.0 * PdfPageFormat.mm;
      qrWidget = pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: deepLink,
        width: qrSize,
        height: qrSize,
      );
    }

    // ── 필드 목록 ────────────────────────────────────────────────
    final fieldWidgets = activeFields.map((key) {
      final label = data.fieldLabels[key] ?? key;
      final value = data.fields[key] ?? '';
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: isNarrow ? 0.5 * PdfPageFormat.mm : 1.2 * PdfPageFormat.mm),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 14 * PdfPageFormat.mm,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: isNarrow ? 5 : 6,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: isNarrow ? 5.5 : 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: isNarrow ? 1 : 2,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ],
        ),
      );
    }).toList();

    // ── 커스텀 메모 ────────────────────────────────────────────────
    final noteWidgets = <pw.Widget>[];
    if (data.customNote.isNotEmpty && !isNarrow) {
      noteWidgets.addAll([
        pw.Divider(height: 0.3 * PdfPageFormat.mm, color: PdfColor.fromHex('#EEEEEE')),
        pw.SizedBox(height: 0.8 * PdfPageFormat.mm),
        pw.Text(
          data.customNote,
          style: pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#444444')),
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
        ),
      ]);
    }

    // ── s40x30 레이아웃: 좌측 필드 + 우측 하단 QR ─────────────────
    if (size == LabelSize.s40x30) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 상단: 브랜드 + 타입
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MoriKnit',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7C6BD8')),
              ),
              pw.Text(
                data.typeName,
                style: pw.TextStyle(fontSize: 6, color: PdfColor.fromHex('#888888')),
              ),
            ],
          ),
          pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
          pw.Divider(height: 0.3 * PdfPageFormat.mm, color: PdfColor.fromHex('#CCCCCC')),
          pw.SizedBox(height: 1 * PdfPageFormat.mm),
          // 본문: 필드 목록 (좌) + QR (우하단)
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [...fieldWidgets, ...noteWidgets],
                  ),
                ),
                if (hasQr && qrWidget != null) ...[
                  pw.SizedBox(width: 2 * PdfPageFormat.mm),
                  pw.Align(
                    alignment: pw.Alignment.bottomRight,
                    child: qrWidget,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    // ── 좁은 사이즈 레이아웃 (s40x12 / s40x15) ─────────────────────
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'MoriKnit',
                style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7C6BD8')),
              ),
              pw.SizedBox(height: 0.8 * PdfPageFormat.mm),
              ...fieldWidgets,
            ],
          ),
        ),
        if (hasQr && qrWidget != null) ...[
          pw.SizedBox(width: 1.5 * PdfPageFormat.mm),
          qrWidget,
        ],
      ],
    );
  }
}
