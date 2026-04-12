import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
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
  static final _grey200    = PdfColor.fromHex('E5E7EB');
  static final _grey300    = PdfColor.fromHex('D1D5DB');
  static final _grey400    = PdfColor.fromHex('9CA3AF');
  static final _grey600    = PdfColor.fromHex('4B5563');
  static final _grey700    = PdfColor.fromHex('374151');
  static final _grey900    = PdfColor.fromHex('111827');

  // ── Image loader (Firebase Storage SDK — 인증 포함 안정적 다운로드) ────
  static Future<pw.ImageProvider?> _img(String url) async {
    if (url.isEmpty) return null;
    try {
      // Firebase Storage gs:// 또는 https://firebasestorage.googleapis.com URL 처리
      final ref = FirebaseStorage.instance.refFromURL(url);
      final bytes = await ref.getData(10 * 1024 * 1024); // 최대 10MB
      if (bytes != null && bytes.isNotEmpty) return pw.MemoryImage(bytes);
    } catch (_) {}
    return null;
  }

  // ── Placeholder box (blank template slot) ────────────
  static pw.Widget _blank(double w, double h, String label, pw.Font font,
      {PdfColor? borderColor}) =>
      pw.Container(
        width: w, height: h,
        decoration: pw.BoxDecoration(
          color: _grey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(
              color: borderColor ?? _grey300, width: 0.8,
              style: pw.BorderStyle.dashed),
        ),
        child: pw.Center(
          child: pw.Text(label,
              style: pw.TextStyle(font: font, fontSize: 9, color: _grey400)),
        ),
      );

  // ── PageTheme (워터마크 없음) ─────────────────────────
  static pw.PageTheme _pageTheme(pw.Font font, String _,
      {pw.EdgeInsets margin = const pw.EdgeInsets.fromLTRB(36, 32, 36, 28)}) {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: margin,
    );
  }

  // ── Rounded image ─────────────────────────────────────
  static pw.Widget _photo(pw.ImageProvider img, double w, double h,
          {double r = 8, pw.BoxFit fit = pw.BoxFit.cover}) =>
      pw.ClipRRect(
        horizontalRadius: r,
        verticalRadius: r,
        child: pw.Image(img, width: w, height: h, fit: fit),
      );

  // ── Section card (always shown) ───────────────────────
  static pw.Widget _card({
    required String title,
    required List<pw.Widget> children,
    required pw.Font bold,
    required PdfColor accent,
    PdfColor? bgColor,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bgColor ?? _grey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: _grey200, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(children: [
              pw.Container(
                width: 3, height: 12,
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Text(title,
                  style: pw.TextStyle(font: bold, fontSize: 8.5, color: _grey700)),
            ]),
            pw.SizedBox(height: 7),
            ...children,
          ],
        ),
      );

  // ── Field row (label + value, always shown) ───────────
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
            pw.SizedBox(
              width: 42,
              child: pw.Text(label, style: labelStyle),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Text(
                value.isNotEmpty ? value : '—',
                style: value.isNotEmpty
                    ? valueStyle
                    : valueStyle.copyWith(color: _grey300),
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ],
        ),
      );

  // ── Footer ────────────────────────────────────────────
  static pw.Widget _footer(pw.Font font, String dateStr, pw.Context ctx) =>
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
                style: pw.TextStyle(font: font, fontSize: 7.5, color: _grey400)),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 7.5, color: _grey400)),
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
    pw.Font regular;
    pw.Font bold;
    try {
      regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'));
      bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
    } catch (_) {
      regular = pw.Font.helvetica();
      bold = pw.Font.helveticaBold();
    }

    final df = DateFormat('yyyy.MM.dd');
    final dateStr = df.format(DateTime.now());
    String fmt(DateTime? d) => d != null ? df.format(d) : '—';

    // Text styles
    final base  = pw.TextStyle(font: regular, fontSize: 9,   color: _grey700);
    final baseB = pw.TextStyle(font: bold,    fontSize: 9,   color: _grey700);
    final sm    = pw.TextStyle(font: regular, fontSize: 8,   color: _grey400);
    final smB   = pw.TextStyle(font: bold,    fontSize: 8,   color: _grey600);
    final lbl   = pw.TextStyle(font: bold,    fontSize: 7.5, color: _grey600);
    final h1    = pw.TextStyle(font: bold,    fontSize: 26,  color: _grey900);
    final whiteSm = pw.TextStyle(font: regular, fontSize: 9,  color: _white);
    final whiteMd = pw.TextStyle(font: bold,    fontSize: 12, color: _white);

    final swatch  = swatches.isNotEmpty ? swatches.first : null;
    final sorted  = [...steps]..sort((a, b) => a.order.compareTo(b.order));
    final albumUrls = project.photoUrls.where((u) => u.isNotEmpty).toList();

    // 프로젝트 연계 도안: imageUrl 있는 것만 (없으면 플레이스홀더)
    final patternImgUrls = patterns
        .where((p) => p.imageUrl.isNotEmpty)
        .map((p) => p.imageUrl)
        .take(1)
        .toList();
    final firstPattern = patterns.isNotEmpty ? patterns.first : null;

    // ── Parallel image load ──────────────────────────────
    final urls = [
      project.coverPhotoUrl,
      if (swatch != null) swatch.beforePhotoUrl,
      if (swatch != null) swatch.afterPhotoUrl,
      ...steps.where((s) => s.photoUrl?.isNotEmpty == true).map((s) => s.photoUrl!),
      ...albumUrls,
      ...patternImgUrls,
    ];
    final imgs = await Future.wait(urls.map(_img));

    int ii = 0;
    final coverImg     = imgs[ii++];
    final swatchBefore = swatch != null ? imgs[ii++] : null;
    final swatchAfter  = swatch != null ? imgs[ii++] : null;

    final stepPhotos = <String, pw.ImageProvider>{};
    for (final s in sorted.where((s) => s.photoUrl?.isNotEmpty == true)) {
      final img = imgs[ii++];
      if (img != null) stepPhotos[s.id] = img;
    }
    final albumImgs = <pw.ImageProvider>[];
    for (final _ in albumUrls) {
      final img = imgs[ii++];
      if (img != null) albumImgs.add(img);
    }
    pw.ImageProvider? patternImg;
    if (patternImgUrls.isNotEmpty) {
      patternImg = imgs[ii++];
    }

    // 모든 사진 앨범 수집 (이미지 + 라벨 쌍)
    final allPhotosWithLabel = <(pw.ImageProvider, String?)>[];
    if (coverImg != null) allPhotosWithLabel.add((coverImg, isKorean ? '표지' : 'Cover'));
    if (swatchBefore != null) allPhotosWithLabel.add((swatchBefore, isKorean ? '세탁 전' : 'Before'));
    if (swatchAfter != null) allPhotosWithLabel.add((swatchAfter, isKorean ? '세탁 후' : 'After'));
    for (int si = 0; si < sorted.length; si++) {
      final img = stepPhotos[sorted[si].id];
      if (img != null) allPhotosWithLabel.add((img, '#${si + 1}'));
    }
    for (final img in albumImgs) {
      allPhotosWithLabel.add((img, null));
    }

    final pdf = pw.Document();

    // ══════════════════════════════════════════════════════
    // PAGE 1: 표지 (고정 템플릿)
    // ══════════════════════════════════════════════════════
    pdf.addPage(pw.Page(
      pageTheme: _pageTheme(regular, userName, margin: pw.EdgeInsets.zero),
      build: (ctx) {
        const pageW = 595.28;
        const imgH  = 370.0;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              height: 36, color: _brand,
              padding: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('MoriKnit', style: whiteMd),
                  pw.Text(dateStr, style: whiteSm),
                ],
              ),
            ),
            // 커버 이미지 — 항상 이 영역 표시 (사진 없으면 플레이스홀더)
            pw.Container(
              width: pageW, height: imgH,
              color: _brandLight,
              alignment: pw.Alignment.center,
              child: coverImg != null
                  ? pw.Image(coverImg,
                      width: pageW, height: imgH, fit: pw.BoxFit.contain)
                  : pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 48, height: 48,
                          decoration: pw.BoxDecoration(
                            color: _brand.shade(0.3),
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(24)),
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Text(
                          isKorean ? '커버 사진을 추가해 보세요' : 'Add a cover photo',
                          style: pw.TextStyle(
                              font: regular, fontSize: 12, color: _brandDark),
                        ),
                      ],
                    ),
            ),
            // 타이틀 영역
            pw.Expanded(
              child: pw.Container(
                color: _white,
                padding: const pw.EdgeInsets.fromLTRB(32, 18, 32, 18),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (project.status.isNotEmpty)
                          pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 7),
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: _pink,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(20)),
                            ),
                            child: pw.Text(project.status,
                                style: pw.TextStyle(
                                    font: bold, fontSize: 8.5, color: _white)),
                          ),
                        pw.Text(
                          project.title.isNotEmpty
                              ? project.title
                              : (isKorean ? '제목 없음' : 'Untitled'),
                          style: h1,
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                        ),
                        if (project.memo.isNotEmpty) ...[
                          pw.SizedBox(height: 5),
                          pw.Text(project.memo,
                              style: sm,
                              maxLines: 2,
                              overflow: pw.TextOverflow.clip),
                        ],
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: pw.BoxDecoration(
                            color: _grey50,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(6)),
                            border: pw.Border.all(
                                color: _grey200, width: 0.5),
                          ),
                          child: pw.Text(
                            isKorean
                                ? '※ 본 PDF는 모리니트 플랫폼에서 생성된 자료입니다. 모리니트는 플랫폼 중개자이며, 도안·작품의 저작권을 포함한 모든 법적 책임은 사용자 본인에게 있습니다.'
                                : '※ This PDF was generated via MoriKnit. MoriKnit acts as a platform intermediary. All legal responsibilities including copyright of patterns and works belong to the user.',
                            style: pw.TextStyle(
                                font: regular, fontSize: 6.5, color: _grey600),
                            maxLines: 3,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(userName.isNotEmpty ? userName : '—',
                                style: smB),
                            pw.Text(
                              [
                                if (project.startDate != null)
                                  fmt(project.startDate),
                                if (project.finishDate != null)
                                  fmt(project.finishDate),
                              ].join('  ~  '),
                              style: sm,
                            ),
                            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                                style: sm),
                          ],
                        ),
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
    // PAGE 2: 작품 상세 — 고정 템플릿, 꽉채우기
    // ══════════════════════════════════════════════════════
    pdf.addPage(pw.Page(
      pageTheme: _pageTheme(regular, userName, margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 24)),
      build: (ctx) {
        // 데이터 추출
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

        // 스와치 게이지 문자열
        final gaugeStr = swatch != null && swatch.beforeStitchCount > 0
            ? '${swatch.beforeStitchCount}코 × ${swatch.beforeRowCount}단'
            : '—';
        final dimStr = swatch != null && swatch.beforeWidthCm > 0
            ? '${swatch.beforeWidthCm.toStringAsFixed(1)} × ${swatch.beforeHeightCm.toStringAsFixed(1)} cm'
            : '—';

        // 대표 이미지 (커버 → 스와치 before → after 순)
        final mainImg = coverImg ?? swatchBefore ?? swatchAfter;

        // 제목
        pw.Widget sectionTitle(String t) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(t, style: pw.TextStyle(font: bold, fontSize: 15, color: _grey900)),
            pw.SizedBox(height: 4),
            pw.Container(height: 2.5, width: 32,
                decoration: pw.BoxDecoration(color: _brand,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)))),
            pw.SizedBox(height: 10),
          ],
        );

        // 썸네일 위젯 (label + image/placeholder)
        pw.Widget thumbCol(String label, pw.ImageProvider? img, double size) =>
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        font: bold, fontSize: 7, color: _grey400)),
                pw.SizedBox(height: 3),
                img != null
                    ? _photo(img, size, size)
                    : _blank(size, size, '—', regular),
              ],
            );

        // ── Page 2 치수 (A4 내용 영역 W=531.28 H=789.89) ──
        const pageW  = 531.28;
        const row1H  = 420.0;  // 행1: 썸네일 + 작품정보
        const row2H  = 295.0;  // 행2: 바늘/실/스와치/도안
        const rowGap = 10.0;
        const colGap = 10.0;
        const imgW   = 220.0;
        const infoW  = pageW - imgW - colGap;       // 301.28
        const col4W  = (pageW - colGap * 3) / 4;   // 125.32

        // 날짜 정보 행 헬퍼
        pw.Widget infoRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 48,
                child: pw.Text(label, style: lbl),
              ),
              pw.Expanded(
                child: pw.Text(
                  value.isEmpty ? '—' : value,
                  style: value.isEmpty
                      ? pw.TextStyle(font: regular, fontSize: 9, color: _grey400)
                      : base,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
            ],
          ),
        );

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            sectionTitle(isKorean ? '작품 상세' : 'Project Details'),

            // ── 행 1: 썸네일(좌) + 작품정보(우) ─────────
            pw.SizedBox(
              height: row1H,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 좌: 대형 썸네일
                  mainImg != null
                      ? _photo(mainImg, imgW, row1H)
                      : _blank(imgW, row1H,
                          isKorean ? '사진 없음' : 'No photo', regular,
                          borderColor: _brandLight),
                  pw.SizedBox(width: colGap),
                  // 우: 작품 정보
                  pw.SizedBox(
                    width: infoW,
                    height: row1H,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // 제목
                        pw.Text(
                          project.title.isNotEmpty
                              ? project.title
                              : (isKorean ? '제목 없음' : 'Untitled'),
                          style: pw.TextStyle(
                              font: bold, fontSize: 15, color: _grey900),
                          maxLines: 3,
                          overflow: pw.TextOverflow.clip,
                        ),
                        pw.SizedBox(height: 10),
                        // 상태 배지
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: _brandLight,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(20)),
                            border: pw.Border.all(color: _brand, width: 0.3),
                          ),
                          child: pw.Text(
                            project.status.isEmpty
                                ? (isKorean ? '상태 없음' : 'No status')
                                : project.status,
                            style: pw.TextStyle(
                                font: bold, fontSize: 8.5, color: _brandDark),
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        // 날짜 카드
                        pw.Container(
                          width: infoW,
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: _grey50,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(8)),
                            border: pw.Border.all(color: _grey200, width: 0.5),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              infoRow(isKorean ? '시작일' : 'Start',
                                  fmt(project.startDate)),
                              infoRow(isKorean ? '목표일' : 'Target',
                                  fmt(project.targetDate)),
                              infoRow(isKorean ? '완성일' : 'Finish',
                                  fmt(project.finishDate)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        // 메모 (나머지 공간 채움)
                        pw.Expanded(
                          child: pw.Container(
                            width: infoW,
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: _white,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(8)),
                              border:
                                  pw.Border.all(color: _grey200, width: 0.5),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(isKorean ? '메모' : 'Memo', style: lbl),
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  project.memo.isNotEmpty
                                      ? project.memo
                                      : (isKorean ? '메모가 없습니다.' : 'No memo.'),
                                  style: project.memo.isNotEmpty
                                      ? base
                                      : pw.TextStyle(
                                          font: regular,
                                          fontSize: 9,
                                          color: _grey300),
                                  maxLines: 15,
                                  overflow: pw.TextOverflow.clip,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: rowGap),

            // ── 행 2: 바늘 / 실 / 스와치 / 도안 ─────────
            pw.SizedBox(
              height: row2H,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 바늘
                  pw.SizedBox(
                    width: col4W,
                    height: row2H,
                    child: _card(
                      title: isKorean ? '바늘' : 'Needle',
                      bold: bold,
                      accent: _brand,
                      children: [
                        _blank(col4W - 20, 60,
                            isKorean ? '사진 없음' : 'No photo', regular,
                            borderColor: _grey300),
                        pw.SizedBox(height: 6),
                        _field(
                          isKorean ? '사이즈' : 'Size',
                          needleSize > 0
                              ? (needleSize % 1 == 0
                                  ? '${needleSize.toInt()} mm'
                                  : '$needleSize mm')
                              : '',
                          lbl, baseB,
                        ),
                        _field(isKorean ? '재질' : 'Material', needleMat,
                            lbl, base),
                        _field(isKorean ? '브랜드' : 'Brand', needleBrand,
                            lbl, base),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: colGap),
                  // 실
                  pw.SizedBox(
                    width: col4W,
                    height: row2H,
                    child: _card(
                      title: isKorean ? '실' : 'Yarn',
                      bold: bold,
                      accent: _pink,
                      children: [
                        _blank(col4W - 20, 60,
                            isKorean ? '사진 없음' : 'No photo', regular,
                            borderColor: _grey300),
                        pw.SizedBox(height: 6),
                        _field(isKorean ? '이름' : 'Name', yarnName, lbl, baseB),
                        _field(isKorean ? '브랜드' : 'Brand', yarnBrand,
                            lbl, base),
                        _field(isKorean ? '색상' : 'Color', yarnColor, lbl, base),
                        _field(isKorean ? '두께' : 'Weight', yarnWeight,
                            lbl, base),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: colGap),
                  // 스와치
                  pw.SizedBox(
                    width: col4W,
                    height: row2H,
                    child: _card(
                      title: isKorean ? '스와치' : 'Swatch',
                      bold: bold,
                      accent: _green,
                      children: [
                        pw.Row(children: [
                          thumbCol(isKorean ? '전' : 'Before',
                              swatchBefore, (col4W - 26) / 2),
                          pw.SizedBox(width: 6),
                          thumbCol(isKorean ? '후' : 'After',
                              swatchAfter, (col4W - 26) / 2),
                        ]),
                        pw.SizedBox(height: 6),
                        _field(isKorean ? '게이지' : 'Gauge', gaugeStr,
                            lbl, baseB),
                        _field(isKorean ? '크기' : 'Size', dimStr, lbl, base),
                        if (swatch != null &&
                            swatch.hasAfterWash &&
                            swatch.afterStitchCount > 0)
                          _field(
                            isKorean ? '세탁 후' : 'After wash',
                            '${swatch.afterStitchCount}코 × ${swatch.afterRowCount}단',
                            lbl, base,
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: colGap),
                  // 도안
                  pw.SizedBox(
                    width: col4W,
                    height: row2H,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _grey50,
                        borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(8)),
                        border: pw.Border.all(color: _grey200, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(children: [
                            pw.Container(
                              width: 3, height: 12,
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('F59E0B'),
                                borderRadius: const pw.BorderRadius.all(
                                    pw.Radius.circular(2)),
                              ),
                            ),
                            pw.SizedBox(width: 5),
                            pw.Text(isKorean ? '도안' : 'Pattern',
                                style: pw.TextStyle(
                                    font: bold, fontSize: 8.5,
                                    color: _grey700)),
                          ]),
                          pw.SizedBox(height: 7),
                          patternImg != null
                              ? _photo(patternImg, col4W - 20, 100,
                                  fit: pw.BoxFit.contain)
                              : pw.Container(
                                  width: col4W - 20,
                                  height: 100,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('FFFBEB'),
                                    borderRadius: const pw.BorderRadius.all(
                                        pw.Radius.circular(6)),
                                    border: pw.Border.all(
                                      color: PdfColor.fromHex('FDE68A'),
                                      width: 0.8,
                                      style: pw.BorderStyle.dashed,
                                    ),
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      isKorean ? '도안 없음' : 'No pattern',
                                      style: pw.TextStyle(
                                          font: regular,
                                          fontSize: 8.5,
                                          color: _grey400),
                                    ),
                                  ),
                                ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            firstPattern != null
                                ? firstPattern.title
                                : (isKorean
                                    ? '도안을 연계해 주세요'
                                    : 'Link a pattern'),
                            style: firstPattern != null
                                ? baseB
                                : pw.TextStyle(
                                    font: regular,
                                    fontSize: 8.5,
                                    color: _grey300),
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                          ),
                          if (patterns.length > 1) ...[
                            pw.SizedBox(height: 3),
                            pw.Text(
                              isKorean
                                  ? '외 ${patterns.length - 1}개'
                                  : '+${patterns.length - 1} more',
                              style: sm,
                            ),
                          ],
                        ],
                      ),
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
    // PAGE 3: 단계로그 — 고정템플릿, 모든 단계 표시 (삭제 없음)
    // ══════════════════════════════════════════════════════
    {
      final doneCount = sorted.where((s) => s.isDone).length;
      final pct = sorted.isEmpty ? 0 : (doneCount / sorted.length * 100).round();
      const barMaxW = 380.0;
      final fillW = sorted.isEmpty ? 0.0 : (barMaxW * doneCount / sorted.length).clamp(0.0, barMaxW);

      final numRows = sorted.isEmpty ? 1 : (sorted.length / 2).ceil();
      // 1페이지 피팅: 8행(16단계) 이하면 동적 카드 높이로 1페이지에 피팅
      // 17단계 이상은 MultiPage로 모든 단계 표시 (단계 삭제 없음)
      // 9행(18단계) 이상은 contentH 초과 → 반드시 MultiPage 사용
      final fitOnePage = numRows <= 8;

      // 사용 가능 높이 계산 (A4 - margins - header - footer)
      const pageH = 841.89;
      const marginT = 32.0, marginB = 28.0;
      const headerH = 58.0; // 제목 + 프로그레스바
      const footerH = 22.0;
      const contentH = pageH - marginT - marginB - headerH - footerH;
      final rowGap = 7.0;
      final cardH = fitOnePage
          ? ((contentH - rowGap * (numRows - 1)) / numRows).clamp(60.0, 120.0)
          : 88.0; // MultiPage: 고정 88pt
      final thumbSize = (cardH - 20.0).clamp(36.0, 72.0);

      pw.Widget card(ProjectStep step, int idx) {
        final photo = stepPhotos[step.id];
        final done  = step.isDone;
        return pw.Container(
          height: cardH,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: done ? _greenBg : _white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(
                color: done ? _greenBrd : _grey200,
                width: done ? 1.0 : 0.5),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 썸네일 (항상 단계 번호 오버레이 표시)
              photo != null
                  ? pw.Stack(
                      children: [
                        _photo(photo, thumbSize, thumbSize, r: 6),
                        pw.Positioned(
                          bottom: 3,
                          right: 3,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: _grey900,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              '${idx + 1}',
                              style: pw.TextStyle(
                                  font: bold, fontSize: 8, color: _white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : pw.Container(
                      width: thumbSize, height: thumbSize,
                      decoration: pw.BoxDecoration(
                        color: done ? _greenBrd : _brandLight,
                        borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6)),
                      ),
                      child: pw.Center(
                        child: pw.Text('${idx + 1}',
                            style: pw.TextStyle(
                                font: bold,
                                fontSize: (thumbSize * 0.28).clamp(10, 18),
                                color: done ? _green : _brand)),
                      ),
                    ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                            margin: const pw.EdgeInsets.only(left: 4),
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: _green,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(10)),
                            ),
                            child: pw.Text(
                                isKorean ? '완료' : 'Done',
                                style: pw.TextStyle(
                                    font: bold, fontSize: 7, color: _white)),
                          ),
                      ],
                    ),
                    if (step.description.isNotEmpty && cardH > 70) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(step.description,
                          style: sm,
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip),
                    ],
                    if (done && step.doneAt != null && cardH > 80) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(fmt(step.doneAt),
                          style: pw.TextStyle(
                              font: bold, fontSize: 7.5, color: _green)),
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

      pw.Widget headerWidget(pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(isKorean ? '단계로그' : 'Step Log',
                  style: pw.TextStyle(font: bold, fontSize: 15, color: _grey900)),
              pw.SizedBox(height: 4),
              pw.Container(height: 2.5, width: 32,
                  decoration: pw.BoxDecoration(color: _brand,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)))),
              pw.SizedBox(height: 8),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Stack(children: [
                pw.Container(
                  width: barMaxW, height: 7,
                  decoration: pw.BoxDecoration(
                    color: _grey200,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3.5)),
                  ),
                ),
                pw.Container(
                  width: fillW, height: 7,
                  decoration: pw.BoxDecoration(
                    color: _brand,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3.5)),
                  ),
                ),
              ]),
              pw.SizedBox(width: 10),
              pw.Text('$doneCount / ${sorted.length}  ($pct%)',
                  style: pw.TextStyle(font: bold, fontSize: 9, color: _brand)),
            ],
          ),
          pw.SizedBox(height: 10),
        ],
      );

      // 단계 없음 → 빈 플레이스홀더 페이지 (고정템플릿)
      if (sorted.isEmpty) {
        pdf.addPage(pw.Page(
          pageTheme: _pageTheme(regular, userName),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              headerWidget(ctx),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(24),
                    decoration: pw.BoxDecoration(
                      color: _grey50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                      border: pw.Border.all(color: _grey200, width: 0.8, style: pw.BorderStyle.dashed),
                    ),
                    child: pw.Text(
                      isKorean ? '등록된 단계가 없습니다.' : 'No steps added yet.',
                      style: pw.TextStyle(font: regular, fontSize: 11, color: _grey400),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              _footer(regular, dateStr, ctx),
            ],
          ),
        ));
      } else if (fitOnePage) {
        // 단일 페이지 — 동적 카드 높이로 전체 단계 피팅
        pdf.addPage(pw.Page(
          pageTheme: _pageTheme(regular, userName),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              headerWidget(ctx),
              pw.Expanded(
                child: pw.Column(
                  children: rows
                      .map((row) => pw.Padding(
                            padding: pw.EdgeInsets.only(
                                bottom: row == rows.last ? 0 : rowGap),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                    child: card(row[0], sorted.indexOf(row[0]))),
                                pw.SizedBox(width: 8),
                                row.length > 1
                                    ? pw.Expanded(
                                        child: card(row[1],
                                            sorted.indexOf(row[1])))
                                    : pw.Expanded(child: pw.SizedBox()),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              pw.SizedBox(height: 8),
              _footer(regular, dateStr, ctx),
            ],
          ),
        ));
      } else {
        // 여러 페이지 — MultiPage로 모든 단계 표시 (삭제 없음)
        pdf.addPage(pw.MultiPage(
          pageTheme: _pageTheme(regular, userName),
          header: (ctx) => headerWidget(ctx),
          footer: (ctx) => _footer(regular, dateStr, ctx),
          build: (ctx) => rows
              .map((row) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 7),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                            child: card(row[0], sorted.indexOf(row[0]))),
                        pw.SizedBox(width: 8),
                        row.length > 1
                            ? pw.Expanded(
                                child: card(row[1], sorted.indexOf(row[1])))
                            : pw.Expanded(child: pw.SizedBox()),
                      ],
                    ),
                  ))
              .toList(),
        ));
      }
    }

    // ══════════════════════════════════════════════════════
    // PAGE: 사진 앨범 (3열 · 고정 템플릿)
    // ══════════════════════════════════════════════════════
    const cols   = 3;
    const gap    = 7.0;
    final imgSize = (523.28 - gap * (cols - 1)) / cols;

    // 앨범은 항상 페이지 추가 (사진 없으면 빈 그리드 표시)
    final albumRows = <List<(pw.ImageProvider?, String?)>>[];
    if (allPhotosWithLabel.isNotEmpty) {
      for (int k = 0; k < allPhotosWithLabel.length; k += cols) {
        final end = k + cols > allPhotosWithLabel.length ? allPhotosWithLabel.length : k + cols;
        final row = List<(pw.ImageProvider?, String?)>.from(allPhotosWithLabel.sublist(k, end));
        while (row.length < cols) {
          row.add((null, null));
        }
        albumRows.add(row);
      }
    } else {
      // 빈 그리드 3줄 표시
      albumRows.addAll(List.generate(3, (_) => List<(pw.ImageProvider?, String?)>.filled(cols, (null, null))));
    }

    pdf.addPage(pw.MultiPage(
      pageTheme: _pageTheme(regular, userName),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(isKorean ? '사진 앨범' : 'Photo Album',
              style: pw.TextStyle(font: bold, fontSize: 15, color: _grey900)),
          pw.SizedBox(height: 4),
          pw.Container(height: 2.5, width: 32,
              decoration: pw.BoxDecoration(color: _pink,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)))),
          pw.SizedBox(height: 10),
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
                      pw.SizedBox(
                        width: imgSize,
                        height: imgSize,
                        child: row[k].$1 != null
                            ? pw.Stack(
                                children: [
                                  _photo(row[k].$1!, imgSize, imgSize),
                                  if (row[k].$2 != null)
                                    pw.Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: pw.Container(
                                        width: 22,
                                        height: 22,
                                        decoration: pw.BoxDecoration(
                                          color: _grey900,
                                          shape: pw.BoxShape.circle,
                                        ),
                                        child: pw.Center(
                                          child: pw.Text(
                                            row[k].$2!,
                                            style: pw.TextStyle(
                                                font: bold,
                                                fontSize: 7,
                                                color: _white),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : _blank(imgSize, imgSize,
                                isKorean ? '사진 없음' : 'No photo', regular),
                      ),
                    ],
                  ],
                ),
              ))
          .toList(),
    ));

    // ══════════════════════════════════════════════════════
    // 마지막 페이지: 제작자 정보
    // ══════════════════════════════════════════════════════
    pdf.addPage(pw.Page(
      pageTheme: _pageTheme(regular, userName, margin: const pw.EdgeInsets.fromLTRB(60, 80, 60, 60)),
      build: (ctx) => pw.Column(
        children: [
          pw.Spacer(),
          pw.Center(child: pw.Container(height: 3, width: 48, color: _brand)),
          pw.SizedBox(height: 28),
          pw.Center(
            child: pw.Text(
              project.title.isNotEmpty
                  ? project.title
                  : (isKorean ? '제목 없음' : 'Untitled'),
              style: pw.TextStyle(font: bold, fontSize: 20, color: _grey900),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Container(height: 0.5, width: 120, color: _grey200)),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(isKorean ? '제작자' : 'Created by', style: sm),
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text(
              userName.isNotEmpty ? userName : '—',
              style: pw.TextStyle(font: bold, fontSize: 14, color: _grey900),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              isKorean ? '내보내기 날짜 : $dateStr' : 'Exported on: $dateStr',
              style: sm,
            ),
          ),
          pw.Spacer(),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Container(height: 0.5, width: 80, color: _grey200),
                pw.SizedBox(height: 10),
                pw.Text('MoriKnit',
                    style: pw.TextStyle(font: bold, fontSize: 14, color: _brand)),
                pw.SizedBox(height: 3),
                pw.Text('www.moriknit.com',
                    style: pw.TextStyle(
                        font: regular, fontSize: 8.5, color: _grey400)),
              ],
            ),
          ),
        ],
      ),
    ));

    return (await pdf.save()).toList();
  }
}
