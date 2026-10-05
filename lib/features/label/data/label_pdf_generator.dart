import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/label_template.dart';

class LabelPdfGenerator {
  // 기본 라벨 크기: 62mm × 29mm (일반 주소 라벨)
  static const double _labelWidthMm = 62;
  static const double _labelHeightMm = 29;

  static Future<Uint8List> generate(LabelData data) async {
    final pdf = pw.Document();

    final pageFormat = PdfPageFormat(
      _labelWidthMm * PdfPageFormat.mm,
      _labelHeightMm * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(3 * PdfPageFormat.mm),
        build: (ctx) => _buildLabel(ctx, data),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildLabel(pw.Context ctx, LabelData data) {
    final activeFields = data.enabledFields
        .where((k) => data.fields.containsKey(k) && data.fields[k]!.isNotEmpty)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── 상단: 브랜드 + 타입 ─────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MoriKnit',
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#7C6BD8'),
              ),
            ),
            pw.Text(
              data.typeName,
              style: pw.TextStyle(
                fontSize: 6,
                color: PdfColor.fromHex('#888888'),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
        // ── 구분선 ───────────────────────────────────────────────────
        pw.Divider(
          height: 0.3 * PdfPageFormat.mm,
          color: PdfColor.fromHex('#CCCCCC'),
        ),
        pw.SizedBox(height: 1 * PdfPageFormat.mm),
        // ── 필드 목록 ─────────────────────────────────────────────────
        ...activeFields.map((key) {
          final label = data.fieldLabels[key] ?? key;
          final value = data.fields[key] ?? '';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1.2 * PdfPageFormat.mm),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 16 * PdfPageFormat.mm,
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 6,
                      color: PdfColor.fromHex('#666666'),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    value,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                  ),
                ),
              ],
            ),
          );
        }),
        // ── 커스텀 메모 ──────────────────────────────────────────────
        if (data.customNote.isNotEmpty) ...[
          pw.Divider(
            height: 0.3 * PdfPageFormat.mm,
            color: PdfColor.fromHex('#EEEEEE'),
          ),
          pw.SizedBox(height: 0.8 * PdfPageFormat.mm),
          pw.Text(
            data.customNote,
            style: pw.TextStyle(
              fontSize: 6,
              fontStyle: pw.FontStyle.italic,
              color: PdfColor.fromHex('#444444'),
            ),
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
          ),
        ],
      ],
    );
  }
}
