import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../../domain/crochet_symbols.dart';
import '../../domain/knit_symbol_svgs.dart';
import '../../domain/knit_symbols.dart';

/// SVG 심볼을 비동기 로드 후 ui.Picture 캐시로 관리.
/// CustomPainter의 repaint: 인자로 전달하면 로드 완료 시 자동 리페인트.
///
/// 로드 우선순위 (#685 — 무한 hang 방지: 로컬 인라인을 최우선):
///   1. 로컬 인라인 SVG (대바늘 — 네트워크 없이 즉시, hang 0)
///   2. Firestore knit_symbols 컬렉션 svgUrl (관리자 동적 등록)
///   3. 코바늘 30종 하드코딩 Firebase URL (CrochetSymbolLibrary)
///   HTTP는 3초 타임아웃 후 폴백 유니코드로 대체.
class SvgSymbolCache extends ChangeNotifier {
  /// picture == null → 미등록(폴백 유니코드 사용)
  /// picture != null → 준비 완료
  final Map<String, ui.Picture?> _cache = {};
  final Set<String> _loading = {};

  /// Firestore knit_symbols → svgUrl 맵 (chart_canvas와 동일 소스).
  /// setSvgUrls()로 외부에서 주입.
  Map<String, String> _firestoreSvgUrls = const {};

  /// Firestore에서 받은 svgUrl 맵 주입 — 호출 시 캐시 무효화 필요 항목 재로드.
  void setSvgUrls(Map<String, String> urls) {
    if (mapEquals(_firestoreSvgUrls, urls)) return;
    _firestoreSvgUrls = Map.unmodifiable(urls);
    // Firestore URL이 새로 들어왔으면 기존 null 캐시 항목 재시도.
    final retry = _cache.entries
        .where((e) => e.value == null && urls.containsKey(e.key))
        .map((e) => e.key)
        .toList();
    for (final id in retry) {
      _cache.remove(id);
    }
    if (retry.isNotEmpty) notifyListeners();
  }

  /// 해당 심볼의 Picture를 반환. 없으면 로드 트리거 후 null 반환.
  ui.Picture? pictureFor(String symbolId) {
    if (_cache.containsKey(symbolId)) return _cache[symbolId];
    if (!_loading.contains(symbolId)) _startLoad(symbolId);
    return null;
  }

  bool isAvailable(String symbolId) =>
      _cache.containsKey(symbolId) && _cache[symbolId] != null;

  void _startLoad(String symbolId) {
    _loading.add(symbolId);
    // 키 정규화: 입력이 KnitSymbol.id 또는 CrochetSymbol.id 일 수도 있음.
    // Firestore svgUrls는 abbr 기반 키이므로 양쪽 후보를 모두 시도.
    final candidates = <String>{symbolId};
    final knit = KnitSymbolLibrary.byId(symbolId);
    if (knit != null) {
      candidates.add(knit.abbr.toLowerCase().replaceAll(' ', '_'));
    }
    final crochet = CrochetSymbolLibrary.byId(symbolId);
    if (crochet != null) {
      candidates.add(crochet.abbreviation.toLowerCase().replaceAll(' ', '_'));
    }

    // 1차 (최우선): 로컬 인라인 SVG — 네트워크 없이 즉시 표시. 무한 hang 위험 0.
    final inlineSvg = kKnitSymbolSvgData[symbolId];
    if (inlineSvg != null) {
      _loadAsync(symbolId, inlineSvg);
      return;
    }
    // candidate 키로도 시도 (id ↔ abbr 매핑 불일치 대비)
    for (final key in candidates) {
      final s = kKnitSymbolSvgData[key];
      if (s != null) {
        _loadAsync(symbolId, s);
        return;
      }
    }

    // 2차: Firestore knit_symbols svgUrl (관리자 등록 — 동적 추가/수정)
    for (final key in candidates) {
      final url = _firestoreSvgUrls[key];
      if (url != null && url.isNotEmpty) {
        _loadFromUrl(symbolId, url);
        return;
      }
    }

    // 3차: 코바늘 30종 하드코딩 Firebase URL
    if (crochet != null && crochet.hasSvg && crochet.firebaseUrl.isNotEmpty) {
      _loadFromUrl(symbolId, crochet.firebaseUrl);
      return;
    }

    // 모두 실패 — 폴백 유니코드 표시
    _cache[symbolId] = null;
    _loading.remove(symbolId);
  }

  /// 이슈 #665, #685 — Firebase Storage URL에서 SVG 다운로드 후 디코드 + 캐시.
  /// #685: 3초 타임아웃 — 무한 hang 방지. 실패 시 폴백 유니코드.
  Future<void> _loadFromUrl(String symbolId, String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        _cache[symbolId] = null;
        return;
      }
      final svgString = response.body;
      final loader = SvgStringLoader(svgString);
      final info = await vg.loadPicture(loader, null);
      _cache[symbolId] = info.picture;
    } catch (e) {
      // ignore: avoid_print
      print('[SvgSymbolCache] FAILED to load "$symbolId" from $url: $e');
      _cache[symbolId] = null;
    } finally {
      _loading.remove(symbolId);
      notifyListeners();
    }
  }

  Future<void> _loadAsync(String symbolId, String svgString) async {
    try {
      final loader = SvgStringLoader(svgString);
      final info = await vg.loadPicture(loader, null);
      _cache[symbolId] = info.picture;
    } catch (e, st) {
      // ignore: avoid_print
      print('[SvgSymbolCache] FAILED to load "$symbolId": $e\n$st');
      _cache[symbolId] = null; // 파싱 오류 → 폴백
    } finally {
      _loading.remove(symbolId);
      notifyListeners(); // CustomPainter repaint 트리거
    }
  }

  /// SVG 뷰박스 크기 (모든 심볼 24×24 고정)
  static const double kSvgSize = 24.0;
}

final svgSymbolCacheProvider = ChangeNotifierProvider<SvgSymbolCache>((ref) {
  return SvgSymbolCache();
});

// ─────────────────────────────────────────────────────────────────────────
// 캐시 기반 심볼 표시 위젯 — 팔레트/캔버스 양쪽에서 동일한 캐시 공유 (#669)
// ─────────────────────────────────────────────────────────────────────────

/// SvgSymbolCache의 ui.Picture를 직접 그리는 가벼운 위젯.
/// 캐시에 있으면 동기적으로 그리고, 없으면 fallback(Text 등)을 표시.
/// SvgPicture.network처럼 매번 다운로드하지 않으므로 깜빡임 없음.
class CachedSymbolView extends StatelessWidget {
  final SvgSymbolCache cache;
  final String symbolId;
  final double size;
  final Widget? fallback;
  final ui.Color? colorOverride;

  const CachedSymbolView({
    super.key,
    required this.cache,
    required this.symbolId,
    required this.size,
    this.fallback,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cache,
      builder: (_, _) {
        final picture = cache.pictureFor(symbolId);
        if (picture != null) {
          return CustomPaint(
            size: Size(size, size),
            painter: _PicturePainter(picture, colorOverride),
          );
        }
        return SizedBox(
          width: size,
          height: size,
          child: Center(child: fallback ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

class _PicturePainter extends CustomPainter {
  final ui.Picture picture;
  final ui.Color? colorOverride;
  _PicturePainter(this.picture, this.colorOverride);

  @override
  void paint(ui.Canvas canvas, Size size) {
    final scale = size.width / SvgSymbolCache.kSvgSize;
    canvas.save();
    canvas.scale(scale, scale);
    if (colorOverride != null) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, SvgSymbolCache.kSvgSize, SvgSymbolCache.kSvgSize),
        Paint(),
      );
      canvas.drawPicture(picture);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, SvgSymbolCache.kSvgSize, SvgSymbolCache.kSvgSize),
        Paint()
          ..color = colorOverride!
          ..blendMode = BlendMode.srcIn,
      );
      canvas.restore();
    } else {
      canvas.drawPicture(picture);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PicturePainter old) =>
      old.picture != picture || old.colorOverride != colorOverride;
}
