import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';

/// PDF 첫 페이지를 썸네일 이미지로 렌더링하는 유틸리티.
///
/// 이슈 #641 — 도안 변환기에서 PDF 업로드 시 첫 페이지를 커버 이미지로 자동 추출.
/// 실패 시 `null` 반환 — 호출자가 fallback(커버 없음) 처리 가능.
class PdfThumbnailExtractor {
  /// PDF 첫 페이지를 JPG 바이트로 렌더링.
  ///
  /// - [dpi]: 렌더 DPI. 기본 150 (A4 기준 약 1240x1754px).
  /// - [quality]: JPG 품질 1~100. 기본 85.
  /// - [maxWidth]: 최종 출력 너비 상한. 기본 600. 초과 시 비율 유지 축소.
  ///
  /// 실패(빈 PDF, 손상, 플랫폼 미지원 등) 시 `null` 반환.
  static Future<Uint8List?> extractFirstPageThumbnail(
    Uint8List pdfBytes, {
    int dpi = 150,
    int quality = 85,
    int maxWidth = 600,
  }) async {
    try {
      if (pdfBytes.isEmpty) return null;

      // printing 5.14.3: Printing.raster(Uint8List document, {List<int>? pages, double dpi})
      //  → Stream<PdfRaster>. 첫 페이지만 필요하므로 pages: [0] + break.
      await for (final page in Printing.raster(
        pdfBytes,
        pages: const [0],
        dpi: dpi.toDouble(),
      )) {
        // #648 보강 — PdfRaster.toPng()로 안전한 PNG 디코드.
        // 이전: pixels.buffer + ChannelOrder.rgba → 일부 환경에서 R/B 채널 swap (빨간톤)
        // 변경: toPng()는 정확한 색상 복원 보장
        final pngBytes = await page.toPng();
        final decoded = img.decodePng(pngBytes);
        if (decoded == null) return null;

        // #648 추가 — 알파 채널 보유 PDF 페이지(투명 배경)는 JPG 변환 시 검정 배경으로 표시됨.
        // 흰색 캔버스를 깔고 그 위에 합성한 후 JPG 인코드.
        final hasAlpha = decoded.numChannels == 4;
        final flattened = hasAlpha
            ? img.compositeImage(
                img.Image(width: decoded.width, height: decoded.height)
                  ..clear(img.ColorRgb8(255, 255, 255)),
                decoded,
              )
            : decoded;

        final resized = flattened.width > maxWidth
            ? img.copyResize(flattened, width: maxWidth)
            : flattened;

        return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }
      return null;
    } catch (e, s) {
      debugPrint('[PdfThumbnailExtractor] 추출 실패: $e\n$s');
      return null;
    }
  }
}
