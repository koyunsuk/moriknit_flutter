import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/knit_symbol_svgs.dart';

/// SVG 심볼을 비동기 로드 후 ui.Picture 캐시로 관리.
/// CustomPainter의 repaint: 인자로 전달하면 로드 완료 시 자동 리페인트.
class SvgSymbolCache extends ChangeNotifier {
  /// picture == null → 미등록(폴백 유니코드 사용)
  /// picture != null → 준비 완료
  final Map<String, ui.Picture?> _cache = {};
  final Set<String> _loading = {};

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
    final svgString = kKnitSymbolSvgData[symbolId];
    if (svgString == null) {
      _cache[symbolId] = null; // 등록된 SVG 없음 → 폴백
      _loading.remove(symbolId);
      return;
    }
    _loadAsync(symbolId, svgString);
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
