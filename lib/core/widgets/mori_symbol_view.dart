// lib/core/widgets/mori_symbol_view.dart
//
// 이슈 #672 — 모든 심볼 표시 단일 SVG 소스 통일.
//
// 사용처: 뜨개백과사전 / 사각그리드 / 원형그리드 / 자유패스 / 에디토리얼 텍스트.
// 모든 위치에서 본 위젯을 사용하면 Firestore knit_symbols 의 svgUrl 이 변경될 때
// 일괄 반영된다.
//
// 데이터 소스 (`unifiedSymbolSvgUrlProvider`):
//   1) Firestore knit_symbols (관리자 등록 — 가장 높은 우선순위)
//   2) CrochetSymbolLibrary 하드코딩 firebaseUrl (코바늘 30종 임시 폴백)
//
// 키 매칭: KnitSymbol.id, KnitSymbol.abbr, CrochetSymbol.id, CrochetSymbol.abbreviation
// 모두 자동 변환 (Provider에서 모든 조합을 미리 등록).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/knit_symbol_provider.dart';
import '../theme/app_colors.dart';
import 'symbol_svg_widget.dart';

/// 모리니트 표준 심볼 표시 위젯 — 단일 SVG 소스 통일.
///
/// `symbolId`는 다음 중 어느 것이든 OK:
///   - KnitSymbol.id ('k', 'p', 'yo', ...)
///   - KnitSymbol.abbr / Firestore abbreviation 정규화 ('k', 'p', 'yo', ...)
///   - CrochetSymbol.id ('ch', 'sl_st', 'sc', ...)
///   - CrochetSymbol.abbreviation 정규화 ('ch', 'sl_st', 'sc', ...)
///
/// 동일 svgUrl 을 가리키므로 SvgPicture.network 의 자체 캐시(메모리)도 활용된다.
class MoriSymbolView extends ConsumerWidget {
  /// 심볼 식별자 (id 또는 abbr 어느 것이든).
  final String symbolId;

  /// 표시 크기 (정사각).
  final double size;

  /// SVG 미등록/미로드 시 표시할 텍스트 (보통 abbreviation).
  final String? fallbackText;

  /// 심볼 색상 오버라이드 (BlendMode.srcIn).
  final Color? color;

  /// BoxFit (기본 contain).
  final BoxFit fit;

  const MoriSymbolView({
    super.key,
    required this.symbolId,
    this.size = 24,
    this.fallbackText,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(unifiedSymbolSvgUrlProvider);
    final url = urls[symbolId];

    // 하이브리드 캐시 사용 — Hive/인라인/네트워크 자동 폴백.
    // url이 비어도 symbolId만으로 인라인(kKnitSymbolSvgData) 폴백 가능.
    return SymbolSvgWidget(
      symbolId: symbolId,
      svgUrl: (url == null || url.isEmpty) ? null : url,
      size: size,
      fit: fit,
      color: color,
      fallbackText: fallbackText,
      fallback: _fallback(),
    );
  }

  Widget _fallback() {
    final text = fallbackText;
    if (text == null || text.isEmpty) {
      return SizedBox(width: size, height: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          text.length > 6 ? text.substring(0, 6) : text,
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
            color: C.tx2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
