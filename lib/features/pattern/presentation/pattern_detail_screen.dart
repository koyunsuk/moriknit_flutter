import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../market/presentation/pdf_viewer_screen.dart';
import '../../../providers/auth_provider.dart';
import '../domain/pattern_chart.dart';
import '../data/pattern_repository.dart';

class PatternDetailScreen extends ConsumerStatefulWidget {
  final PatternChart chart;
  const PatternDetailScreen({super.key, required this.chart});

  @override
  ConsumerState<PatternDetailScreen> createState() => _PatternDetailScreenState();
}

class _PatternDetailScreenState extends ConsumerState<PatternDetailScreen> {
  final _memoCtrl = TextEditingController();
  bool _memoLoading = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadMemo();
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMemo() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || widget.chart.id.isEmpty) return;
    _uid = user.uid;
    setState(() => _memoLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('pattern_memos')
          .doc('${user.uid}_${widget.chart.id}')
          .get();
      if (snap.exists && mounted) {
        _memoCtrl.text = snap.data()?['memo'] as String? ?? '';
      }
    } finally {
      if (mounted) setState(() => _memoLoading = false);
    }
  }

  Future<void> _saveMemo() async {
    if (_uid == null || widget.chart.id.isEmpty) return;
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          await FirebaseFirestore.instance
              .collection('pattern_memos')
              .doc('${_uid}_${widget.chart.id}')
              .set({'memo': _memoCtrl.text.trim(), 'updatedAt': FieldValue.serverTimestamp()});
        },
      );
      if (mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context),
            message: isKorean ? '메모가 저장됐어요.' : 'Memo saved.');
      }
    } catch (e) {
      if (mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _changeImage() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: C.bd2, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: C.lv),
                title: Text(isKorean ? '카메라로 찍기' : 'Take a photo', style: T.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked =
                      await ImagePicker().pickImage(source: ImageSource.camera);
                  if (picked != null && context.mounted) {
                    await _replaceImage(File(picked.path), isKorean);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: C.lv),
                title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery',
                    style: T.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (picked != null && context.mounted) {
                    await _replaceImage(File(picked.path), isKorean);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _replaceImage(File file, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '이미지 교체 중입니다.' : 'Replacing image...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(patternRepositoryProvider).saveImagePattern(
              title: widget.chart.title,
              imageFile: file,
            ),
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context),
            message: isKorean ? '이미지가 교체됐어요.' : 'Image replaced.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Future<void> _exportPdf(BuildContext context, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? 'PDF 생성 중입니다.' : 'Generating PDF...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          final pdfDoc = pw.Document();
          const cellSize = 12.0;
          final cols = widget.chart.cols;
          final rows = widget.chart.rows;

          pdfDoc.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              build: (ctx) => [
                pw.Text(widget.chart.title,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('$rows행 × $cols열',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(
                      color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    for (var i = 0; i < cols; i++)
                      i: const pw.FixedColumnWidth(cellSize)
                  },
                  children: List.generate(
                    rows,
                    (r) => pw.TableRow(
                      children: List.generate(cols, (c) {
                        final cell = r < widget.chart.grid.length &&
                                c < widget.chart.grid[r].length
                            ? widget.chart.grid[r][c]
                            : null;
                        final color = cell?.color;
                        PdfColor? pdfColor;
                        if (color != null) {
                          final argb = color.toARGB32();
                          final a = ((argb >> 24) & 0xFF) / 255.0;
                          final rv = ((argb >> 16) & 0xFF) / 255.0;
                          final gv = ((argb >> 8) & 0xFF) / 255.0;
                          final bv = (argb & 0xFF) / 255.0;
                          if (!(rv > 0.98 && gv > 0.98 && bv > 0.98)) {
                            pdfColor = PdfColor(rv, gv, bv, a);
                          }
                        }
                        return pw.Container(
                          height: cellSize,
                          color: pdfColor,
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          );

          final bytes = await pdfDoc.save();
          final dir = await getTemporaryDirectory();
          final file =
              File('${dir.path}/${widget.chart.title}.pdf');
          await file.writeAsBytes(bytes);
          await launchUrl(Uri.file(file.path));
        },
      );
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Widget _buildThumbnail() {
    if (widget.chart.type == PatternType.image &&
        widget.chart.imageUrl.isNotEmpty) {
      return Stack(
        children: [
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.bd),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.chart.imageUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (context, e, s) => _placeholderBox(220),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _changeImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }
    return _placeholderBox(120);
  }

  Widget _placeholderBox(double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: _iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(_typeIcon, color: _iconColor.withValues(alpha: 0.4), size: 48),
    );
  }

  IconData get _typeIcon {
    switch (widget.chart.type) {
      case PatternType.image:
        return Icons.image_rounded;
      case PatternType.pdf:
        return Icons.picture_as_pdf_rounded;
      case PatternType.chart:
        return Icons.grid_on_rounded;
    }
  }

  Color get _iconColor {
    switch (widget.chart.type) {
      case PatternType.image:
        return C.lmD;
      case PatternType.pdf:
        return C.og;
      case PatternType.chart:
        return C.lvD;
    }
  }

  IconData get _actionIcon {
    switch (widget.chart.type) {
      case PatternType.image:
        return Icons.zoom_in_rounded;
      case PatternType.pdf:
        return Icons.open_in_new_rounded;
      case PatternType.chart:
        return Icons.visibility_rounded;
    }
  }

  String _typeLabel(bool isKorean) {
    switch (widget.chart.type) {
      case PatternType.image:
        return isKorean ? '이미지 도안' : 'Image pattern';
      case PatternType.pdf:
        return isKorean ? 'PDF 도안' : 'PDF pattern';
      case PatternType.chart:
        final mode = widget.chart.mode == ChartMode.color
            ? (isKorean ? '컬러' : 'Color')
            : (isKorean ? '기호' : 'Symbol');
        return isKorean ? '에디터 도안 · $mode' : 'Editor pattern · $mode';
    }
  }

  String _actionLabel(bool isKorean) {
    switch (widget.chart.type) {
      case PatternType.image:
        return isKorean ? '이미지 보기' : 'View image';
      case PatternType.pdf:
        return isKorean ? 'PDF 열기' : 'Open PDF';
      case PatternType.chart:
        return isKorean ? '도안 보기 (뷰어)' : 'View pattern';
    }
  }

  void _openViewer() {
    switch (widget.chart.type) {
      case PatternType.image:
        if (widget.chart.imageUrl.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(widget.chart.title)),
                body: InteractiveViewer(
                  child: Center(
                      child: Image.network(widget.chart.imageUrl,
                          fit: BoxFit.contain)),
                ),
              ),
            ),
          );
        }
      case PatternType.pdf:
        if (widget.chart.pdfUrl.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                  url: widget.chart.pdfUrl, title: widget.chart.title),
            ),
          );
        }
      case PatternType.chart:
        context.push('${Routes.toolsPattern}/${widget.chart.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.chart.title, style: T.h3),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                _buildThumbnail(),
                const SizedBox(height: 16),
                // Info card
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                Icon(_typeIcon, color: _iconColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.chart.title, style: T.bodyBold),
                                Text(_typeLabel(isKorean),
                                    style:
                                        T.caption.copyWith(color: C.mu)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.chart.type == PatternType.chart) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _InfoChip(
                                label: isKorean ? '행' : 'Rows',
                                value: '${widget.chart.rows}'),
                            const SizedBox(width: 8),
                            _InfoChip(
                                label: isKorean ? '열' : 'Cols',
                                value: '${widget.chart.cols}'),
                            const SizedBox(width: 8),
                            _InfoChip(
                              label: isKorean ? '모드' : 'Mode',
                              value: widget.chart.mode == ChartMode.color
                                  ? (isKorean ? '컬러' : 'Color')
                                  : (isKorean ? '기호' : 'Symbol'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _openViewer,
                    icon: Icon(_actionIcon),
                    label: Text(_actionLabel(isKorean)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                // PDF export button (chart type only)
                if (widget.chart.type == PatternType.chart) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _exportPdf(context, isKorean),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(
                          isKorean ? 'PDF로 내보내기' : 'Export as PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.og,
                        side: BorderSide(color: C.og),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
                // Memo section
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(isKorean ? '나만의 메모' : 'My notes',
                    style: T.bodyBold.copyWith(color: C.lvD)),
                const SizedBox(height: 8),
                if (_memoLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  TextField(
                    controller: _memoCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: isKorean
                          ? '도안을 보면서 메모를 남겨보세요.'
                          : 'Take notes about this pattern.',
                    ),
                  ),
                const SizedBox(height: 12),
                if (_uid != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveMemo,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(isKorean ? '메모 저장' : 'Save notes'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: C.lv,
                          foregroundColor: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: T.bodyBold.copyWith(color: C.lvD, fontSize: 14)),
          Text(label, style: T.caption.copyWith(color: C.mu, fontSize: 10)),
        ],
      ),
    );
  }
}
