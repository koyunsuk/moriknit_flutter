import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../counter/domain/counter_model.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../swatch/domain/swatch_model.dart';
import '../domain/project_model.dart';
import '../domain/project_step.dart';

class ProjectPdfService {
  // ── Brand Colors ──────────────────────────────────────
  static final _brand      = PdfColor.fromHex('8B5CF6');
  static final _brandDark  = PdfColor.fromHex('6D28D9');
  static final _brandLight = PdfColor.fromHex('EDE9FE');
  static final _pink       = PdfColor.fromHex('EC4899');
  static final _green      = PdfColor.fromHex('16A34A');
  static final _greenBg    = PdfColor.fromHex('F0FDF4');
  static final _greenBrd   = PdfColor.fromHex('86EFAC');
  static final _white      = PdfColors.white;
  static final _grey50     = PdfColor.fromHex('F9FAFB');
  static final _grey100    = PdfColor.fromHex('F3F4F6');
  static final _grey200    = PdfColor.fromHex('E5E7EB');
  static final _grey400    = PdfColor.fromHex('9CA3AF');
  static final _grey600    = PdfColor.fromHex('4B5563');
  static final _grey700    = PdfColor.fromHex('374151');
  static final _grey900    = PdfColor.fromHex('111827');

  // ── Image loader ──────────────────────────────────────
  static Future<pw.ImageProvider?> _img(String url) async {
    if (url.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return pw.MemoryImage(r.bodyBytes);
    } catch (_) {}
    return null;
  }

  // ── Placeholder box ───────────────────────────────────
  static pw.Widget _box(double w, double h, String text, pw.Font font) =>
      pw.Container(
        width: w, height: h,
        decoration: pw.BoxDecoration(
          color: _grey100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: _grey200),
        ),
        child: pw.Center(
          child: pw.Text(text,
              style: pw.TextStyle(font: font, fontSize: 9, color: _grey400)),
        ),
      );

  // ── Rounded image ─────────────────────────────────────
  static pw.Widget _photo(pw.ImageProvider img, double w, double h,
          {double r = 8, pw.BoxFit fit = pw.BoxFit.cover}) =>
      pw.ClipRRect(
        horizontalRadius: r,
        verticalRadius: r,
        child: pw.Image(img, width: w, height: h, fit: fit),
      );

  // ── Section title ─────────────────────────────────────
  static pw.Widget _sectionTitle(
          String text, pw.TextStyle style, PdfColor accent) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(text, style: style),
          pw.SizedBox(height: 5),
          pw.Container(
            height: 2.5, width: 32,
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
            ),
          ),
          pw.SizedBox(height: 10),
        ],
      );

  // ── Labeled field row ─────────────────────────────────
  static pw.Widget _field(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              color: _grey100,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: pw.Text(label, style: labelStyle),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(value,
                    style: valueStyle,
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip),
              ),
            ),
          ],
        ),
      );

  // ── Info section card ─────────────────────────────────
  static pw.Widget _infoSection({
    required String title,
    required List<pw.Widget> fields,
    required pw.TextStyle titleStyle,
    required PdfColor accent,
  }) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(
              width: 3, height: 14,
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Text(title, style: titleStyle),
          ]),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              color: _grey50,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _grey200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: fields,
            ),
          ),
        ],
      );

  // ── Footer ────────────────────────────────────────────
  static pw.Widget _footer(
          pw.Font font, String dateStr, pw.Context ctx) =>
      pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: _grey200, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MoriKnit  ·  www.moriknit.com  ·  $dateStr',
                style: pw.TextStyle(
                    font: font, fontSize: 7.5, color: _grey400)),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(
                    font: font, fontSize: 7.5, color: _grey400)),
          ],
        ),
      );

  // ── Main ──────────────────────────────────────────────
  static Future<List<int>> generateProjectPdfBytes({
    required ProjectModel project,
    required List<ProjectStep> steps,
    required List<SwatchModel> swatches,
    required List<PatternChart> patterns,
    required List<CounterModel> counters,
    required bool isKorean,
    String userName = '',
  }) async {
    final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'));
    final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));

    final df = DateFormat('yyyy.MM.dd');
    final dateStr = df.format(DateTime.now());
    String fmt(DateTime? d) => d != null ? df.format(d) : '-';

    // Text styles
    final base  = pw.TextStyle(font: regular, fontSize: 9.5, color: _grey700);
    final baseB = pw.TextStyle(font: bold,    fontSize: 9.5, color: _grey700);
    final sm    = pw.TextStyle(font: regular, fontSize: 8.5, color: _grey400);
    final smB   = pw.TextStyle(font: bold,    fontSize: 8.5, color: _grey600);
    final lbl   = pw.TextStyle(font: bold,    fontSize: 8,   color: _grey700);
    final h1    = pw.TextStyle(font: bold,    fontSize: 26,  color: _grey900);
    final h2    = pw.TextStyle(font: bold,    fontSize: 15,  color: _grey900);
    final h3    = pw.TextStyle(font: bold,    fontSize: 10.5,color: _grey900);
    final whiteSm = pw.TextStyle(font: regular, fontSize: 9,  color: _white);
    final whiteMd = pw.TextStyle(font: bold,    fontSize: 12, color: _white);

    final swatch  = swatches.isNotEmpty ? swatches.first : null;
    final sorted  = [...steps]..sort((a, b) => a.order.compareTo(b.order));
    final withPhoto = sorted.where((s) => s.photoUrl?.isNotEmpty == true).toList();
    final albumUrls = project.photoUrls.where((u) => u.isNotEmpty).toList();

    // ── Parallel image load ──────────────────────────────
    final urls = [
      project.coverPhotoUrl,
      if (swatch != null) swatch.beforePhotoUrl,
      if (swatch != null) swatch.afterPhotoUrl,
      ...withPhoto.map((s) => s.photoUrl!),
      ...albumUrls,
    ];
    final imgs = await Future.wait(urls.map(_img));

    int ii = 0;
    final coverImg     = imgs[ii++];
    final swatchBefore = swatch != null ? imgs[ii++] : null;
    final swatchAfter  = swatch != null ? imgs[ii++] : null;

    final stepPhotos = <String, pw.ImageProvider>{};
    for (final s in withPhoto) {
      final img = imgs[ii++];
      if (img != null) stepPhotos[s.id] = img;
    }
    final albumImgs = <pw.ImageProvider>[];
    for (final _ in albumUrls) {
      final img = imgs[ii++];
      if (img != null) albumImgs.add(img);
    }

    // ── 사진 앨범: 모든 사진 수집 ──────────────────────────
    final allPhotos = <pw.ImageProvider>[];
    if (coverImg != null) allPhotos.add(coverImg);
    if (swatchBefore != null) allPhotos.add(swatchBefore);
    if (swatchAfter != null) allPhotos.add(swatchAfter);
    for (final s in sorted) {
      final img = stepPhotos[s.id];
      if (img != null) allPhotos.add(img);
    }
    allPhotos.addAll(albumImgs);

    final pdf = pw.Document();

    // ══════════════════════════════════════════════════════
    // PAGE 1: 표지
    // ══════════════════════════════════════════════════════
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) {
        const pageW = 595.28;
        const imgH  = 370.0;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // 브랜드 헤더 바
            pw.Container(
              height: 36,
              color: _brand,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 28),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('MoriKnit', style: whiteMd),
                  pw.Text(dateStr, style: whiteSm),
                ],
              ),
            ),
            // 커버 이미지 (가운데 정렬 · contain)
            pw.Container(
              width: pageW, height: imgH,
              color: _brandLight,
              alignment: pw.Alignment.center,
              child: coverImg != null
                  ? pw.Image(coverImg,
                      width: pageW, height: imgH,
                      fit: pw.BoxFit.contain)
                  : pw.Center(
                      child: pw.Text(
                        isKorean ? '사진 없음' : 'No photo',
                        style: pw.TextStyle(
                            font: regular,
                            fontSize: 14,
                            color: _grey400),
                      ),
                    ),
            ),
            // 타이틀 영역
            pw.Expanded(
              child: pw.Container(
                color: _white,
                padding:
                    const pw.EdgeInsets.fromLTRB(32, 18, 32, 18),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        if (project.status.isNotEmpty)
                          pw.Container(
                            margin: const pw.EdgeInsets.only(
                                bottom: 7),
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: _pink,
                              borderRadius:
                                  const pw.BorderRadius.all(
                                      pw.Radius.circular(20)),
                            ),
                            child: pw.Text(project.status,
                                style: pw.TextStyle(
                                    font: bold,
                                    fontSize: 8.5,
                                    color: _white)),
                          ),
                        pw.Text(project.title,
                            style: h1,
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip),
                        if (project.memo.isNotEmpty) ...[
                          pw.SizedBox(height: 5),
                          pw.Text(project.memo,
                              style: sm,
                              maxLines: 2,
                              overflow: pw.TextOverflow.clip),
                        ],
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        userName.isNotEmpty
                            ? pw.Text(userName, style: smB)
                            : pw.SizedBox(),
                        pw.Text(
                          [
                            if (project.startDate != null)
                              fmt(project.startDate),
                            if (project.finishDate != null)
                              fmt(project.finishDate),
                          ].join('  ~  '),
                          style: sm,
                        ),
                        pw.Text(
                            '${ctx.pageNumber} / ${ctx.pagesCount}',
                            style: sm),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ));

    // ══════════════════════════════════════════════════════
    // PAGE 2: 작품 정보
    // ══════════════════════════════════════════════════════
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
      build: (ctx) {
        final needleSize  = (swatch?.needleSize ?? 0) > 0
            ? swatch!.needleSize : project.needleSize;
        final needleBrand = swatch?.needleBrandName.isNotEmpty == true
            ? swatch!.needleBrandName : project.needleBrandName;
        final needleMat   = swatch?.needleMaterial ?? '';
        final yarnName    = swatch?.yarnName.isNotEmpty == true
            ? swatch!.yarnName : project.yarnName;
        final yarnBrand   = swatch?.yarnBrandName.isNotEmpty == true
            ? swatch!.yarnBrandName : project.yarnBrandName;
        final yarnColor   = swatch?.yarnColor.isNotEmpty == true
            ? swatch!.yarnColor : project.yarnColor;
        final yarnWeight  = swatch?.yarnWeight.isNotEmpty == true
            ? swatch!.yarnWeight : project.yarnWeight;
        final infoImg = coverImg ?? (swatchBefore ?? swatchAfter);

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sectionTitle(
                isKorean ? '작품 정보' : 'Project Details', h2, _brand),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 왼쪽: 이미지 + 기간
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      infoImg != null
                          ? _photo(infoImg, 175, 210)
                          : _box(175, 210,
                              isKorean ? '사진 없음' : 'No photo',
                              regular),
                      pw.SizedBox(height: 9),
                      pw.Container(
                        width: 175,
                        padding: const pw.EdgeInsets.all(9),
                        decoration: pw.BoxDecoration(
                          color: _brandLight,
                          borderRadius:
                              const pw.BorderRadius.all(
                                  pw.Radius.circular(8)),
                          border: pw.Border.all(
                              color: _brand, width: 0.3),
                        ),
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              isKorean ? '진행 기간' : 'Duration',
                              style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 8,
                                  color: _brandDark),
                            ),
                            pw.SizedBox(height: 5),
                            if (project.startDate != null)
                              _field(
                                  isKorean ? '시작' : 'Start',
                                  fmt(project.startDate),
                                  lbl, base),
                            if (project.finishDate != null)
                              _field(
                                  isKorean ? '완성' : 'Finish',
                                  fmt(project.finishDate),
                                  lbl, base),
                            if (project.startDate == null &&
                                project.finishDate == null)
                              pw.Text(
                                  isKorean
                                      ? '날짜 미입력'
                                      : 'No dates',
                                  style: sm),
                            if (project.status.isNotEmpty) ...[
                              pw.SizedBox(height: 3),
                              pw.Text(project.status,
                                  style: pw.TextStyle(
                                      font: bold,
                                      fontSize: 8.5,
                                      color: _brandDark)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 16),
                  // 오른쪽: 바늘/실/도안/메모
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        _infoSection(
                          title: isKorean ? '바늘 정보' : 'Needle',
                          titleStyle: h3,
                          accent: _brand,
                          fields: [
                            if (needleSize > 0)
                              _field(
                                isKorean ? '사이즈' : 'Size',
                                needleSize % 1 == 0
                                    ? '${needleSize.toInt()} mm'
                                    : '$needleSize mm',
                                lbl, baseB,
                              ),
                            if (needleMat.isNotEmpty)
                              _field(
                                  isKorean ? '재질' : 'Material',
                                  needleMat, lbl, base),
                            if (needleBrand.isNotEmpty)
                              _field(
                                  isKorean ? '브랜드' : 'Brand',
                                  needleBrand, lbl, base),
                            if (needleSize <= 0 &&
                                needleBrand.isEmpty)
                              pw.Text(
                                  isKorean
                                      ? '정보 없음'
                                      : 'No info',
                                  style: sm),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                        _infoSection(
                          title: isKorean ? '실 정보' : 'Yarn',
                          titleStyle: h3,
                          accent: _pink,
                          fields: [
                            if (yarnName.isNotEmpty)
                              _field(isKorean ? '이름' : 'Name',
                                  yarnName, lbl, baseB),
                            if (yarnBrand.isNotEmpty)
                              _field(isKorean ? '브랜드' : 'Brand',
                                  yarnBrand, lbl, base),
                            if (yarnColor.isNotEmpty)
                              _field(isKorean ? '색상' : 'Color',
                                  yarnColor, lbl, base),
                            if (yarnWeight.isNotEmpty)
                              _field(isKorean ? '두께' : 'Weight',
                                  yarnWeight, lbl, base),
                            if (yarnName.isEmpty &&
                                yarnBrand.isEmpty)
                              pw.Text(
                                  isKorean
                                      ? '정보 없음'
                                      : 'No info',
                                  style: sm),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                        _infoSection(
                          title: isKorean ? '도안' : 'Patterns',
                          titleStyle: h3,
                          accent: _green,
                          fields: patterns.isNotEmpty
                              ? patterns.take(5).map((p) =>
                                  pw.Padding(
                                    padding: const pw.EdgeInsets
                                        .only(bottom: 3),
                                    child: pw.Row(children: [
                                      pw.Container(
                                        width: 5, height: 5,
                                        decoration: pw.BoxDecoration(
                                          color: _green,
                                          borderRadius: const pw
                                              .BorderRadius.all(
                                              pw.Radius.circular(3)),
                                        ),
                                      ),
                                      pw.SizedBox(width: 5),
                                      pw.Expanded(
                                        child: pw.Text(p.title,
                                            style: base,
                                            maxLines: 1,
                                            overflow: pw
                                                .TextOverflow.clip),
                                      ),
                                    ]),
                                  )).toList()
                              : [
                                  pw.Text(
                                      isKorean
                                          ? '연계된 도안 없음'
                                          : 'No patterns',
                                      style: sm)
                                ],
                        ),
                        if (project.memo.isNotEmpty) ...[
                          pw.SizedBox(height: 12),
                          _infoSection(
                            title: isKorean ? '메모' : 'Memo',
                            titleStyle: h3,
                            accent: _grey400,
                            fields: [
                              pw.Text(project.memo,
                                  style: base,
                                  maxLines: 6,
                                  overflow: pw.TextOverflow.clip),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            _footer(regular, dateStr, ctx),
          ],
        );
      },
    ));

    // ══════════════════════════════════════════════════════
    // PAGE 3+: 단계로그 (2열 · 컴팩트)
    // ══════════════════════════════════════════════════════
    if (sorted.isNotEmpty) {
      final doneCount = sorted.where((s) => s.isDone).length;
      final pct = (doneCount / sorted.length * 100).round();
      const barMaxW = 380.0;
      final fillW =
          (barMaxW * doneCount / sorted.length).clamp(0.0, barMaxW);

      pw.Widget card(ProjectStep step, int idx) {
        final photo = stepPhotos[step.id];
        final done  = step.isDone;
        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: done ? _greenBg : _white,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(
                color: done ? _greenBrd : _grey200,
                width: done ? 1.0 : 0.5),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 썸네일 64×64
              photo != null
                  ? _photo(photo, 64, 64, r: 6)
                  : pw.Container(
                      width: 64, height: 64,
                      decoration: pw.BoxDecoration(
                        color: done ? _greenBrd : _brandLight,
                        borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6)),
                      ),
                      child: pw.Center(
                        child: pw.Text('${idx + 1}',
                            style: pw.TextStyle(
                                font: bold,
                                fontSize: 18,
                                color: done ? _green : _brand)),
                      ),
                    ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(step.name,
                              style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 9.5,
                                  color: done ? _green : _grey900),
                              maxLines: 2,
                              overflow: pw.TextOverflow.clip),
                        ),
                        if (done)
                          pw.Container(
                            margin:
                                const pw.EdgeInsets.only(left: 4),
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: _green,
                              borderRadius:
                                  const pw.BorderRadius.all(
                                      pw.Radius.circular(10)),
                            ),
                            child: pw.Text(
                                isKorean ? '완료' : 'Done',
                                style: pw.TextStyle(
                                    font: bold,
                                    fontSize: 7,
                                    color: _white)),
                          ),
                      ],
                    ),
                    if (step.description.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(step.description,
                          style: sm,
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip),
                    ],
                    if (step.note.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(step.note,
                          style: pw.TextStyle(
                              font: regular,
                              fontSize: 7.5,
                              color: _grey400),
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip),
                    ],
                    if (done && step.doneAt != null) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(fmt(step.doneAt),
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 7.5,
                              color: _green)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final rows = <List<ProjectStep>>[];
      for (int k = 0; k < sorted.length; k += 2) {
        rows.add([
          sorted[k],
          if (k + 1 < sorted.length) sorted[k + 1],
        ]);
      }

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sectionTitle(
                isKorean ? '단계로그' : 'Step Log', h2, _brand),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Stack(children: [
                  pw.Container(
                    width: barMaxW, height: 7,
                    decoration: pw.BoxDecoration(
                      color: _grey200,
                      borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(3.5)),
                    ),
                  ),
                  pw.Container(
                    width: fillW, height: 7,
                    decoration: pw.BoxDecoration(
                      color: _brand,
                      borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(3.5)),
                    ),
                  ),
                ]),
                pw.SizedBox(width: 10),
                pw.Text(
                  '$doneCount / ${sorted.length}  ($pct%)',
                  style: pw.TextStyle(
                      font: bold, fontSize: 9, color: _brand)),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (ctx) => _footer(regular, dateStr, ctx),
        build: (ctx) => rows
            .map((row) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.Row(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          child:
                              card(row[0], sorted.indexOf(row[0]))),
                      pw.SizedBox(width: 8),
                      row.length > 1
                          ? pw.Expanded(
                              child: card(
                                  row[1], sorted.indexOf(row[1])))
                          : pw.Expanded(child: pw.SizedBox()),
                    ],
                  ),
                ))
            .toList(),
      ));
    }

    // ══════════════════════════════════════════════════════
    // PAGE: 사진 앨범 (3열 · 모든 사진)
    // ══════════════════════════════════════════════════════
    if (allPhotos.isNotEmpty) {
      const cols   = 3;
      const gap    = 7.0;
      final imgSize = (523.28 - gap * (cols - 1)) / cols; // ≈ 169.76

      final albumRows = <List<pw.ImageProvider>>[];
      for (int k = 0; k < allPhotos.length; k += cols) {
        albumRows.add(allPhotos.sublist(
            k,
            k + cols > allPhotos.length ? allPhotos.length : k + cols));
      }

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sectionTitle(
                isKorean ? '사진 앨범' : 'Photo Album', h2, _pink),
          ],
        ),
        footer: (ctx) => _footer(regular, dateStr, ctx),
        build: (ctx) => albumRows
            .map((row) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: gap),
                  child: pw.Row(
                    children: [
                      for (int k = 0; k < cols; k++) ...[
                        if (k > 0) pw.SizedBox(width: gap),
                        k < row.length
                            ? _photo(row[k], imgSize, imgSize)
                            : pw.SizedBox(
                                width: imgSize, height: imgSize),
                      ],
                    ],
                  ),
                ))
            .toList(),
      ));
    }

    // ══════════════════════════════════════════════════════
    // 마지막 페이지: 제작자 정보
    // ══════════════════════════════════════════════════════
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(60, 80, 60, 60),
      build: (ctx) {
        return pw.Column(
          children: [
            pw.Spacer(),
            pw.Center(
              child: pw.Container(
                  height: 3, width: 48, color: _brand),
            ),
            pw.SizedBox(height: 28),
            pw.Center(
              child: pw.Text(
                project.title,
                style: h2.copyWith(fontSize: 20),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Container(
                  height: 0.5, width: 120, color: _grey200),
            ),
            pw.SizedBox(height: 20),
            if (userName.isNotEmpty) ...[
              pw.Center(
                child: pw.Text(
                  isKorean ? '제작자' : 'Created by',
                  style: sm,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  userName,
                  style: pw.TextStyle(
                      font: bold, fontSize: 14, color: _grey900),
                ),
              ),
              pw.SizedBox(height: 16),
            ],
            pw.Center(
              child: pw.Text(
                isKorean
                    ? '내보내기 날짜 : $dateStr'
                    : 'Exported on: $dateStr',
                style: sm,
              ),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Container(
                      height: 0.5, width: 80, color: _grey200),
                  pw.SizedBox(height: 10),
                  pw.Text('MoriKnit',
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 14,
                          color: _brand)),
                  pw.SizedBox(height: 3),
                  pw.Text('www.moriknit.com',
                      style: pw.TextStyle(
                          font: regular,
                          fontSize: 8.5,
                          color: _grey400)),
                ],
              ),
            ),
          ],
        );
      },
    ));

    return (await pdf.save()).toList();
  }
}
