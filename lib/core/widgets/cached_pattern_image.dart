// lib/core/widgets/cached_pattern_image.dart
//
// #704 Phase 2 — 도안 이미지 캐시 위젯.
// 흐름:
//   1) PatternMediaCache.getOrFetch 로 로컬 파일 확보 시도 (모바일).
//   2) 캐시본 있으면 Image.file 로 즉시 표시.
//   3) 캐시 미스 & 오프라인이면 OfflineImagePlaceholder.
//   4) 웹/캐시 미지원이면 NetworkImage 로 폴백, errorBuilder 도 동일 플레이스홀더.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../cache/pattern_media_cache.dart';
import 'offline_image_placeholder.dart';

class CachedPatternImage extends StatefulWidget {
  const CachedPatternImage({
    super.key,
    required this.url,
    required this.patternId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.menu_book_rounded,
    this.type = 'jpg',
  });

  final String url;
  final String patternId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;
  final String type;

  @override
  State<CachedPatternImage> createState() => _CachedPatternImageState();
}

class _CachedPatternImageState extends State<CachedPatternImage> {
  File? _file;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CachedPatternImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.patternId != widget.patternId) {
      _file = null;
      _resolved = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (kIsWeb || widget.url.isEmpty) {
      if (mounted) setState(() => _resolved = true);
      return;
    }
    final f = await PatternMediaCache.instance.getOrFetch(
      widget.url,
      patternId: widget.patternId,
      type: widget.type,
    );
    if (!mounted) return;
    setState(() {
      _file = f;
      _resolved = true;
    });
  }

  Widget _placeholder() => OfflineImagePlaceholder(
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
        icon: widget.placeholderIcon,
      );

  Widget _wrapClip(Widget child) {
    if (widget.borderRadius == null) return child;
    return ClipRRect(borderRadius: widget.borderRadius!, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      return _placeholder();
    }

    // 캐시 적중 (모바일).
    if (_file != null) {
      return _wrapClip(
        Image.file(
          _file!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }

    // 캐시 미스 — 웹이거나 아직 해석 중이거나 오프라인.
    // 웹/해석완료 후 캐시 없는 경우엔 네트워크로 시도 → 실패 시 placeholder.
    if (!_resolved) {
      // 해석 진행 중 (모바일). 캐시 적중 가능성이 있으므로 살짝 대기 — 빈 컨테이너.
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: _wrapClip(
          Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: const SizedBox.shrink(),
          ),
        ),
      );
    }

    // 모바일에서 해석 완료 후에도 파일이 없으면 = 오프라인 + 캐시 없음.
    if (!kIsWeb) {
      return _placeholder();
    }

    // 웹: NetworkImage 사용, 실패 시 placeholder.
    return _wrapClip(
      Image.network(
        widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _placeholder(),
      ),
    );
  }
}
