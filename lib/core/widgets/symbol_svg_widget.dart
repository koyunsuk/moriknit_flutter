// lib/core/widgets/symbol_svg_widget.dart
//
// 하이브리드 캐시 기반 심볼 SVG 표시 위젯.
// SvgPicture.network 의 대체재 — 오프라인에서도 항상 동작.
//
// 사용 방식:
//   SymbolSvgWidget(symbolId: 'k', size: 22)           // ID 기반 (Firestore + 인라인)
//   SymbolSvgWidget(svgUrl: 'https://...svg', size: 22) // URL 기반 (encyclopedia 등)
//   SymbolSvgWidget.either(symbolId: id, svgUrl: url, size: 22) // 양쪽
//
// 동작 흐름 (Repository.getSvg 와 동일):
//   1. 메모리 캐시 hit → 즉시 표시 (FutureBuilder 1프레임 빈 박스 회피용 동기 fast-path)
//   2. Hive 영속 캐시 hit → 즉시
//   3. 인라인 폴백 hit → 즉시
//   4. 네트워크 다운로드 후 표시 (Hive 자동 저장 → 다음번 즉시)
//   5. 전부 실패 → 오프라인 플레이스홀더 (있으면 fallbackText)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/pattern/data/symbol_svg_repository.dart';
import '../theme/app_colors.dart';

class SymbolSvgWidget extends ConsumerStatefulWidget {
  /// 심볼 ID (KnitSymbol.id / abbr / CrochetSymbol.id / abbreviation 어느 것이든).
  final String? symbolId;

  /// 직접 SVG URL — encyclopedia/landing 등 referenceUrl 기반 호출.
  final String? svgUrl;

  /// 표시 사이즈 (정사각).
  final double size;

  /// 색상 오버라이드 (BlendMode.srcIn).
  final Color? color;

  /// BoxFit (기본 contain).
  final BoxFit fit;

  /// 폴백 텍스트 (SVG 미가용 시 표시; 보통 abbreviation).
  final String? fallbackText;

  /// 폴백 위젯 (fallbackText 보다 우선).
  final Widget? fallback;

  /// SVG semantic label.
  final String? semanticsLabel;

  const SymbolSvgWidget({
    super.key,
    this.symbolId,
    this.svgUrl,
    this.size = 24,
    this.color,
    this.fit = BoxFit.contain,
    this.fallbackText,
    this.fallback,
    this.semanticsLabel,
  }) : assert(symbolId != null || svgUrl != null,
            'symbolId 또는 svgUrl 중 최소 하나는 필요');

  @override
  ConsumerState<SymbolSvgWidget> createState() => _SymbolSvgWidgetState();
}

class _SymbolSvgWidgetState extends ConsumerState<SymbolSvgWidget> {
  String? _svg;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolveSync();
    if (_svg == null) _resolveAsync();
  }

  @override
  void didUpdateWidget(covariant SymbolSvgWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbolId != widget.symbolId ||
        oldWidget.svgUrl != widget.svgUrl) {
      _svg = null;
      _resolved = false;
      _resolveSync();
      if (_svg == null) _resolveAsync();
    }
  }

  void _resolveSync() {
    final repo = ref.read(symbolSvgRepositoryProvider);
    final svg = repo.getSvgSync(
      symbolId: widget.symbolId,
      svgUrl: widget.svgUrl,
    );
    if (svg != null) {
      _svg = svg;
      _resolved = true;
    }
  }

  Future<void> _resolveAsync() async {
    final repo = ref.read(symbolSvgRepositoryProvider);
    final svg = await repo.getSvg(
      symbolId: widget.symbolId,
      svgUrl: widget.svgUrl,
    );
    if (!mounted) return;
    setState(() {
      _svg = svg;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final svg = _svg;
    if (svg != null && svg.isNotEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: SvgPicture.string(
          svg,
          width: widget.size,
          height: widget.size,
          fit: widget.fit,
          colorFilter: widget.color != null
              ? ColorFilter.mode(widget.color!, BlendMode.srcIn)
              : null,
          semanticsLabel: widget.semanticsLabel,
        ),
      );
    }

    // 해결 진행 중 — 빈 박스로 레이아웃 유지 (CLS 0)
    if (!_resolved) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    // 완전 실패 — fallback
    if (widget.fallback != null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(child: widget.fallback),
      );
    }
    final text = widget.fallbackText;
    if (text != null && text.isNotEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Text(
            text.length > 6 ? text.substring(0, 6) : text,
            style: TextStyle(
              fontSize: widget.size * 0.32,
              fontWeight: FontWeight.w700,
              color: C.tx2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Icon(
        Icons.help_outline_rounded,
        size: widget.size * 0.6,
        color: C.tx2.withValues(alpha: 0.45),
      ),
    );
  }
}
