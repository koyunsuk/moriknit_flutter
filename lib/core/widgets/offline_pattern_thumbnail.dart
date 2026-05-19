// lib/core/widgets/offline_pattern_thumbnail.dart
//
// #838 — 도안 카드 썸네일 (오프라인 우선 표시).
//
// 흐름:
//   1) patternId 가 주어졌고 OfflinePatternEntry.thumbnailPath 가 있으면
//      Image.file 로 즉시 표시 (오프라인 + 비행기 모드 OK).
//   2) 없으면 PatternMediaCache 의 캐시 파일 시도 (이미 본 적 있으면 캐시 적중).
//   3) 둘 다 없으면 CachedNetworkImage 로 폴백 (cached_network_image 가 디스크 캐시).
//   4) 모두 실패하면 fallback 위젯 또는 OfflineImagePlaceholder.
//
// 사용처: 도안/스와치/프로젝트 카드 등 모리니트 자체 자산 썸네일.
// (커뮤니티/마켓 등 외부 자산은 patternId 가 없으므로 CachedNetworkImage 만 사용)

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/pattern_media_cache.dart';
import '../../features/pattern/data/pattern_offline_repository.dart';
import 'offline_image_placeholder.dart';

class OfflinePatternThumbnail extends ConsumerStatefulWidget {
  const OfflinePatternThumbnail({
    super.key,
    required this.imageUrl,
    this.patternId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
    this.placeholderIcon = Icons.menu_book_rounded,
  });

  /// 네트워크 URL (Firebase Storage 등). 비어있으면 fallback 표시.
  final String imageUrl;

  /// 도안 id. 주어지면 오프라인 영구 캐시 (#782) 우선 검사.
  /// 비어있으면 PatternMediaCache + 네트워크 캐시만 사용.
  final String? patternId;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// imageUrl이 비어있거나 모든 캐시/네트워크 실패 시 표시할 위젯.
  /// 없으면 OfflineImagePlaceholder 사용.
  final Widget? fallback;

  final IconData placeholderIcon;

  @override
  ConsumerState<OfflinePatternThumbnail> createState() =>
      _OfflinePatternThumbnailState();
}

class _OfflinePatternThumbnailState
    extends ConsumerState<OfflinePatternThumbnail> {
  File? _offlineFile;
  File? _mediaCacheFile;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant OfflinePatternThumbnail old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl ||
        old.patternId != widget.patternId) {
      _offlineFile = null;
      _mediaCacheFile = null;
      _resolved = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (kIsWeb || widget.imageUrl.isEmpty) {
      if (mounted) setState(() => _resolved = true);
      return;
    }

    // 1) 오프라인 영구 캐시 (#782/#838) — patternId 있을 때만.
    final id = widget.patternId;
    if (id != null && id.isNotEmpty) {
      try {
        final entry =
            await ref.read(patternOfflineRepositoryProvider).get(id);
        if (entry != null && entry.thumbnailPath.isNotEmpty) {
          final f = File(entry.thumbnailPath);
          if (await f.exists()) {
            if (!mounted) return;
            setState(() {
              _offlineFile = f;
              _resolved = true;
            });
            return;
          }
        }
      } catch (_) {}
    }

    // 2) PatternMediaCache — 본 적 있는 도안 디스크 캐시.
    try {
      final f = await PatternMediaCache.instance.peek(
        widget.imageUrl,
        patternId: id ?? widget.imageUrl,
      );
      if (f != null) {
        if (!mounted) return;
        setState(() {
          _mediaCacheFile = f;
          _resolved = true;
        });
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _resolved = true);
  }

  Widget _wrapClip(Widget child) {
    if (widget.borderRadius == null) return child;
    return ClipRRect(borderRadius: widget.borderRadius!, child: child);
  }

  Widget _placeholderWidget() =>
      widget.fallback ??
      OfflineImagePlaceholder(
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
        icon: widget.placeholderIcon,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return _placeholderWidget();
    }

    // 1) 오프라인 영구 캐시 적중.
    if (_offlineFile != null) {
      return _wrapClip(
        Image.file(
          _offlineFile!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, _, _) => _placeholderWidget(),
        ),
      );
    }

    // 2) PatternMediaCache 적중.
    if (_mediaCacheFile != null) {
      return _wrapClip(
        Image.file(
          _mediaCacheFile!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, _, _) => _placeholderWidget(),
        ),
      );
    }

    // 3) 해석 중 — 빈 박스 (깜빡임 방지).
    if (!_resolved) {
      return _wrapClip(
        SizedBox(
          width: widget.width,
          height: widget.height,
        ),
      );
    }

    // 4) 네트워크 캐시 fallback — cached_network_image 가 디스크 캐시.
    //    웹/모바일 공통.
    return _wrapClip(
      CachedNetworkImage(
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorWidget: (_, _, _) => _placeholderWidget(),
      ),
    );
  }
}
