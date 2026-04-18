import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/photo_album_repository.dart';
import '../domain/photo_album_item.dart';

// ── 필터 타입 ──────────────────────────────────────────────────────────────────
enum _AlbumFilter { all, project, swatch }

extension _AlbumFilterLabel on _AlbumFilter {
  String label(bool isKorean) {
    switch (this) {
      case _AlbumFilter.all:
        return isKorean ? '전체' : 'All';
      case _AlbumFilter.project:
        return isKorean ? '프로젝트' : 'Project';
      case _AlbumFilter.swatch:
        return isKorean ? '스와치' : 'Swatch';
    }
  }
}

// ── 화면 ────────────────────────────────────────────────────────────────────
class PhotoAlbumScreen extends ConsumerStatefulWidget {
  const PhotoAlbumScreen({super.key});

  @override
  ConsumerState<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends ConsumerState<PhotoAlbumScreen> {
  _AlbumFilter _filter = _AlbumFilter.all;

  bool get _isKorean {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'ko';
  }

  List<PhotoAlbumItem> _applyFilter(List<PhotoAlbumItem> items) {
    switch (_filter) {
      case _AlbumFilter.all:
        return items;
      case _AlbumFilter.project:
        return items.where((e) => e.sourceType == 'project').toList();
      case _AlbumFilter.swatch:
        return items.where((e) => e.sourceType == 'swatch').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = _isKorean;
    final asyncItems = ref.watch(photoAlbumItemsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isKorean ? '나의 사진 앨범' : 'My Photo Album', style: T.h3),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          Column(
            children: [
              // ── 필터 칩 ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: _AlbumFilter.values.map((f) {
                    final isSelected = f == _filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? C.lv : C.lvL,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? C.lv
                                  : C.lv.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Text(
                            f.label(isKorean),
                            style: T.caption.copyWith(
                              color: isSelected ? Colors.white : C.lvD,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              // ── 그리드 ────────────────────────────────────────────
              Expanded(
                child: asyncItems.when(
                  loading: () =>
                      Center(child: CircularProgressIndicator(color: C.lv)),
                  error: (e, _) => Center(
                      child: Text('$e',
                          style: T.body.copyWith(color: C.og))),
                  data: (items) {
                    final filtered = _applyFilter(items);
                    if (filtered.isEmpty) {
                      return _EmptyPlaceholder(isKorean: isKorean);
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(2, 2, 2, 80),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _AlbumCell(
                          item: item,
                          index: index,
                          onTap: () => _openViewer(context, filtered, index),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openViewer(
      BuildContext context, List<PhotoAlbumItem> items, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PhotoViewerScreen(items: items, initialIndex: initialIndex),
      ),
    );
  }
}

// ── 그리드 셀 ────────────────────────────────────────────────────────────────
class _AlbumCell extends StatelessWidget {
  final PhotoAlbumItem item;
  final int index;
  final VoidCallback onTap;

  const _AlbumCell(
      {required this.item, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'photo_album_${item.imageUrl}_$index',
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                color: C.bd,
                child: Icon(Icons.image_not_supported_outlined,
                    color: C.mu, size: 28),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                item.sourceType == 'project'
                    ? Icons.folder_outlined
                    : Icons.grid_3x3_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 플레이스홀더 ──────────────────────────────────────────────────────
class _EmptyPlaceholder extends StatelessWidget {
  final bool isKorean;
  const _EmptyPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 빈 행 3개
          for (int i = 0; i < 3; i++)
            Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.bd.withValues(alpha: 0.5)),
              ),
            ),
          const SizedBox(height: 8),
          Icon(Icons.photo_library_outlined, size: 38, color: C.mu),
          const SizedBox(height: 10),
          Text(
            isKorean
                ? '아직 저장된 사진이 없어요\n프로젝트나 스와치에 사진을 추가해 보세요'
                : 'No photos yet\nAdd photos to your projects or swatches',
            style: T.body.copyWith(color: C.tx2, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 전체화면 뷰어 ─────────────────────────────────────────────────────────────
class _PhotoViewerScreen extends StatefulWidget {
  final List<PhotoAlbumItem> items;
  final int initialIndex;

  const _PhotoViewerScreen(
      {required this.items, required this.initialIndex});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late int _currentIndex;
  late PageController _pageController;
  bool _sharing = false;

  // 워터마크 합성용 GlobalKey
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isKorean {
    try {
      final locale = Localizations.localeOf(context);
      return locale.languageCode == 'ko';
    } catch (_) {
      return true;
    }
  }

  PhotoAlbumItem get _current => widget.items[_currentIndex];

  Future<void> _shareWithWatermark() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // RepaintBoundary 캡처
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      // 임시 파일 저장
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/moriknit_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          text: 'MoriKnit',
          files: [XFile(file.path)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = _isKorean;
    final item = _current;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.sourceName.isEmpty
                  ? (isKorean ? '무제' : 'Untitled')
                  : item.sourceName,
              style: T.bodyBold.copyWith(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_currentIndex + 1} / ${widget.items.length}',
              style: T.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_sharing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon:
                  const Icon(Icons.share_outlined, color: Colors.white),
              tooltip: isKorean ? '공유' : 'Share',
              onPressed: _shareWithWatermark,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final pageItem = widget.items[index];
          return Center(
            child: RepaintBoundary(
              key: index == _currentIndex ? _repaintKey : null,
              child: _WatermarkedImage(item: pageItem),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(
                item.sourceType == 'project'
                    ? Icons.folder_outlined
                    : Icons.grid_3x3_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                item.sourceType == 'project'
                    ? (isKorean ? '프로젝트' : 'Project')
                    : (isKorean ? '스와치' : 'Swatch'),
                style: T.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7)),
              ),
              const Spacer(),
              Text(
                DateFormat('yyyy.MM.dd').format(item.createdAt),
                style: T.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 워터마크 합성 위젯 ────────────────────────────────────────────────────────
class _WatermarkedImage extends StatelessWidget {
  final PhotoAlbumItem item;
  const _WatermarkedImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd').format(item.createdAt);

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CachedNetworkImage(
          imageUrl: item.imageUrl,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => Container(
            color: const Color(0xFF111111),
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined,
                  color: Colors.white54, size: 48),
            ),
          ),
        ),
        // 워터마크 오버레이
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MoriKnit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
