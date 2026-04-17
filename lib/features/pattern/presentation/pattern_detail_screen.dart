import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
import '../../../providers/project_provider.dart';

class PatternDetailScreen extends ConsumerStatefulWidget {
  final PatternChart chart;

  /// Fork 기능: 다른 사람의 패턴을 볼 때 소유자 정보를 전달합니다.
  /// null이면 자신의 패턴으로 간주합니다.
  final String? ownerId;
  final String? ownerName;

  /// AI 변환 후 즉시 수정 모드로 열릴 때 true
  final bool initialIsEditing;

  /// AI 변환 후 저장 완료 시 호출 (확인 다이얼로그 → 저장 → 이 콜백 실행)
  final VoidCallback? onSaveComplete;

  const PatternDetailScreen({
    super.key,
    required this.chart,
    this.ownerId,
    this.ownerName,
    this.initialIsEditing = false,
    this.onSaveComplete,
  });

  @override
  ConsumerState<PatternDetailScreen> createState() => _PatternDetailScreenState();
}

class _PatternDetailScreenState extends ConsumerState<PatternDetailScreen> {
  final _memoCtrl = TextEditingController();
  bool _memoLoading = false;
  String? _uid;

  bool _isEditing = false;
  bool _isSaving = false;
  late final TextEditingController _editTitleCtrl;
  late final TextEditingController _editNarrativeCtrl;
  ChartMode _editMode = ChartMode.color;

  @override
  void initState() {
    super.initState();
    _loadMemo();
    _editTitleCtrl = TextEditingController();
    _editNarrativeCtrl = TextEditingController();
    if (widget.initialIsEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enterEditMode());
    }
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    _editTitleCtrl.dispose();
    _editNarrativeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMemo() async {
    if (widget.chart.id.isEmpty) {
      if (mounted) setState(() => _memoLoading = false);
      return;
    }
    if (mounted) setState(() => _memoLoading = true);
    try {
      // authState가 아직 로딩 중이면 future로 대기
      final authAsync = ref.read(authStateProvider);
      final user = authAsync.valueOrNull ??
          await ref
              .read(authStateProvider.future)
              .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (user == null || !mounted) {
        if (mounted) setState(() => _memoLoading = false);
        return;
      }
      _uid = user.uid;
      if (mounted) setState(() {}); // _uid 업데이트 반영 (메모 저장 버튼 표시)

      final snap = await FirebaseFirestore.instance
          .collection('pattern_memos')
          .doc('${user.uid}_${widget.chart.id}')
          .get()
          .timeout(const Duration(seconds: 10));
      if (snap.exists && mounted) {
        _memoCtrl.text = snap.data()?['memo'] as String? ?? '';
      }
    } catch (_) {
      // 메모 로딩 실패 시 빈 상태로 처리
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

  /// 다른 사용자의 패턴인지 확인합니다.
  bool get _isOtherUser {
    if (widget.ownerId == null || _uid == null) return false;
    return widget.ownerId != _uid;
  }

  /// chart 타입이고 다른 사용자의 패턴일 때 Fork 가능합니다.
  bool get _canFork =>
      widget.chart.type == PatternType.chart && _isOtherUser;

  void _enterEditMode() {
    _editTitleCtrl.text = widget.chart.title;
    _editNarrativeCtrl.text = widget.chart.narrativeText;
    _editMode = widget.chart.mode;
    setState(() => _isEditing = true);
  }

  void _cancelEdit() => setState(() => _isEditing = false);

  Future<void> _saveEdit(bool isKorean) async {
    var newTitle = _editTitleCtrl.text.trim();
    if (newTitle.isEmpty) return;

    // AI 변환 최초 저장 시: 중복 이름 체크
    if (widget.onSaveComplete != null) {
      final existingPatterns = ref.read(patternListProvider).valueOrNull ?? [];
      final duplicate = existingPatterns.any(
        (p) => p.title.toLowerCase() == newTitle.toLowerCase() && p.id != widget.chart.id,
      );
      if (duplicate) {
        final renamed = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final ctrl = TextEditingController(text: '$newTitle (2)');
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isKorean ? '같은 이름의 도안이 있어요' : 'Duplicate name', style: T.h3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isKorean ? '"$newTitle" 이름의 도안이 이미 있어요. 다른 이름으로 저장하시겠어요?' : 'A pattern named "$newTitle" already exists.',
                    style: T.body.copyWith(color: C.mu),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(labelText: isKorean ? '새 도안 이름' : 'New name'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(isKorean ? '취소' : 'Cancel', style: TextStyle(color: C.mu)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: Text(isKorean ? '이 이름으로 저장' : 'Save with this name'),
                ),
              ],
            );
          },
        );
        if (renamed == null || !mounted) return;
        _editTitleCtrl.text = renamed;
        newTitle = renamed;
      }
    }

    final newNarrative = _editNarrativeCtrl.text.trim();
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(patternRepositoryProvider).save(
          PatternChart(
            id: widget.chart.id,
            title: newTitle,
            rows: widget.chart.rows,
            cols: widget.chart.cols,
            mode: _editMode,
            grid: widget.chart.grid,
            narrativeText: newNarrative,
            type: widget.chart.type,
            imageUrl: widget.chart.imageUrl,
            pdfUrl: widget.chart.pdfUrl,
            forkCount: widget.chart.forkCount,
            sourcePatternId: widget.chart.sourcePatternId,
            sourceOwnerName: widget.chart.sourceOwnerName,
            sourceType: widget.chart.sourceType,
            aiSections: widget.chart.aiSections,
          ),
        ),
      );
      if (!mounted) return;
      if (widget.onSaveComplete != null) {
        // AI 변환 저장 완료 팝업
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Icon(Icons.check_circle_rounded, color: C.lv, size: 52),
                const SizedBox(height: 14),
                Text(
                  isKorean ? '저장 완료!' : 'Saved!',
                  style: T.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isKorean ? '나의 도안 라이브러리에 저장됐어요.' : 'Saved to your pattern library.',
                  style: T.body.copyWith(color: C.mu),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(isKorean ? '나의 도안으로 이동' : 'Go to My Patterns'),
                  ),
                ),
              ],
            ),
          ),
        );
        if (!mounted) return;
        widget.onSaveComplete!();
      } else {
        showSavedSnackBar(messenger, message: isKorean ? '수정됐어요.' : 'Updated.');
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildEditBody(bool isKorean) {
    return Stack(
      children: [
        const BgOrbs(),
        StatefulBuilder(
          builder: (ctx, setEditState) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(title: isKorean ? '도안 이름' : 'Pattern name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _editTitleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: isKorean ? '도안 이름' : 'Pattern name',
                    hintText: isKorean ? '예: 비니 도안' : 'e.g. Beanie chart',
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '설명 / 메모 (선택)' : 'Notes (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _editNarrativeCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: isKorean ? '설명 / 메모' : 'Notes',
                    hintText: isKorean ? '도안에 대한 설명이나 메모를 입력하세요' : 'Add notes about this pattern',
                  ),
                ),
                if (widget.chart.type == PatternType.chart) ...[
                  const SizedBox(height: 20),
                  SectionTitle(title: isKorean ? '도안 모드' : 'Pattern mode'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final mode in [ChartMode.color, ChartMode.symbol])
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setEditState(() => _editMode = mode),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _editMode == mode ? C.lv : C.lvL,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _editMode == mode ? C.lv : C.lv.withValues(alpha: 0.20)),
                              ),
                              child: Text(
                                mode == ChartMode.color
                                    ? (isKorean ? '컬러' : 'Color')
                                    : (isKorean ? '기호' : 'Symbol'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _editMode == mode ? Colors.white : C.lvD,
                                  fontWeight: _editMode == mode ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _duplicatePattern(bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(patternRepositoryProvider).duplicate(widget.chart),
      );
      if (mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
    } catch (e) {
      if (mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _confirmDelete(bool isKorean) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '도안 삭제' : 'Delete Pattern', style: T.h3),
        content: Text(isKorean ? '이 도안을 삭제할까요? 되돌릴 수 없어요.' : 'Delete this pattern? This cannot be undone.', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(patternRepositoryProvider).delete(widget.chart.id),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
    } catch (e) {
      if (mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _linkToProject(BuildContext context, bool isKorean) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final allProjects = cRef.watch(projectListProvider).valueOrNull ?? [];
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (_, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      isKorean ? '프로젝트에 연결' : 'Link to Project',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (allProjects.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          isKorean ? '등록된 프로젝트가 없어요.' : 'No projects available.',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: allProjects.length,
                        itemBuilder: (_, i) {
                          final project = allProjects[i];
                          final alreadyLinked = project.sourcePatternId == widget.chart.id;
                          return ListTile(
                            leading: project.coverPhotoUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(project.coverPhotoUrl, width: 40, height: 40, fit: BoxFit.cover),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.folder_outlined, size: 20),
                                  ),
                            title: Text(project.title, style: Theme.of(ctx).textTheme.bodyMedium),
                            trailing: alreadyLinked
                                ? Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18)
                                : null,
                            onTap: alreadyLinked ? null : () async {
                              Navigator.pop(ctx);
                              await runWithMoriLoadingDialog<void>(
                                context,
                                message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                                subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                task: () => ref.read(projectRepositoryProvider).updateProject(
                                      project.copyWith(sourcePatternId: widget.chart.id),
                                    ),
                              );
                              if (context.mounted) {
                                showSavedSnackBar(
                                  ScaffoldMessenger.of(context),
                                  message: isKorean ? '연결됐어요.' : 'Linked.',
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _forkPattern() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? 'Fork하는 중입니다.' : 'Forking...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          await ref.read(patternRepositoryProvider).forkPattern(
                sourceOwnerId: widget.ownerId!,
                sourceOwnerName: widget.ownerName ?? '',
                sourcePattern: widget.chart,
              );
        },
      );
      if (mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context),
            message: isKorean
                ? '도안이 내 라이브러리에 추가됐어요.'
                : 'Pattern added to your library.');
      }
    } catch (e) {
      if (mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
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
        // ignore: use_build_context_synchronously
        showSavedSnackBar(ScaffoldMessenger.of(context),
            message: isKorean ? '이미지가 교체됐어요.' : 'Image replaced.');
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        // ignore: use_build_context_synchronously
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

  Future<void> _openViewer() async {
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
        final rawUrl = widget.chart.pdfUrl;
        if (rawUrl.isEmpty) return;
        // Storage 경로(users/...)인 경우 다운로드 URL로 변환
        String downloadUrl = rawUrl;
        if (!rawUrl.startsWith('http')) {
          try {
            downloadUrl = await FirebaseStorage.instance.ref(rawUrl).getDownloadURL();
          } catch (e) {
            if (mounted) {
              showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: 'PDF를 열 수 없어요: $e');
            }
            return;
          }
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
                url: downloadUrl, title: widget.chart.title),
          ),
        );
      case PatternType.chart:
        context.push('${Routes.toolsPattern}/${widget.chart.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _isEditing
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: TextButton(
                onPressed: _cancelEdit,
                child: Text(isKorean ? '취소' : 'Cancel', style: TextStyle(color: C.mu)),
              ),
              title: Text(isKorean ? '도안 수정' : 'Edit Pattern', style: T.h3),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : () => _saveEdit(isKorean),
                  child: Text(isKorean ? '저장' : 'Save', style: TextStyle(color: C.lv, fontWeight: FontWeight.w700)),
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(widget.chart.title, style: T.h3),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                if (!_isOtherUser && widget.chart.id.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: C.tx),
                    onSelected: (v) {
                      if (v == 'edit') _enterEditMode();
                      if (v == 'copy') _duplicatePattern(isKorean);
                      if (v == 'link_project') _linkToProject(context, isKorean);
                      if (v == 'delete') _confirmDelete(isKorean);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18, color: C.lv),
                          const SizedBox(width: 8),
                          Text(isKorean ? '수정' : 'Edit'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(children: [
                          Icon(Icons.copy_rounded, size: 18, color: C.lv),
                          const SizedBox(width: 8),
                          Text(isKorean ? '복사' : 'Duplicate'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'link_project',
                        child: Row(children: [
                          Icon(Icons.folder_outlined, size: 18, color: C.lv),
                          const SizedBox(width: 8),
                          Text(isKorean ? '프로젝트 연결' : 'Link to project'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 18, color: C.og),
                          const SizedBox(width: 8),
                          Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ),
      body: _isEditing
          ? _buildEditBody(isKorean)
          : Stack(
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
                      // Fork 출처 배지
                      if (widget.chart.sourcePatternId != null &&
                          widget.chart.sourceOwnerName != null &&
                          widget.chart.sourceOwnerName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: C.pk.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: C.pk.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fork_right_rounded,
                                  size: 16, color: C.pkD),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isKorean
                                      ? '원본: ${widget.chart.sourceOwnerName}'
                                      : 'Forked from: ${widget.chart.sourceOwnerName}',
                                  style: T.caption.copyWith(color: C.pkD),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Fork 수 표시
                      if (widget.chart.forkCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.fork_right_rounded,
                                size: 14, color: C.mu),
                            const SizedBox(width: 4),
                            Text(
                              isKorean
                                  ? 'Fork ${widget.chart.forkCount}회'
                                  : '${widget.chart.forkCount} forks',
                              style: T.caption.copyWith(color: C.mu),
                            ),
                          ],
                        ),
                      ],
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
                // Fork 버튼 (chart 타입 + 다른 사용자 패턴)
                if (_canFork) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _forkPattern,
                      icon: const Icon(Icons.fork_right_rounded),
                      label: Text(isKorean ? '내 도안으로 Fork' : 'Fork to my library'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.pkD,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
                // AI 변환 도안: 단계 보기 버튼 + 섹션 요약
                if (widget.chart.sourceType == PatternSourceType.aiConverted) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                          '${Routes.toolsMyParsedPatterns}/${widget.chart.id}'),
                      icon: const Icon(Icons.checklist_rounded),
                      label: Text(isKorean ? '단계별 따라하기' : 'Step-by-step view'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.lv,
                        side: BorderSide(color: C.lv),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  if ((widget.chart.aiSections ?? []).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _AiSectionsSummary(
                        chart: widget.chart, isKorean: isKorean),
                  ],
                ],
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

// ── AI 섹션 요약 위젯 ────────────────────────────────────────────────────────
class _AiSectionsSummary extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  const _AiSectionsSummary({required this.chart, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final sections = chart.aiSections ?? [];
    final totalSteps = sections.fold<int>(
        0, (acc, s) => acc + ((s['steps'] as List?)?.length ?? 0));
    final completedSteps = sections.fold<int>(
        0,
        (acc, s) =>
            acc +
            ((s['steps'] as List?)
                    ?.where((st) => (st as Map)['isCompleted'] == true)
                    .length ??
                0));
    final progress =
        totalSteps == 0 ? 0.0 : completedSteps / totalSteps;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: C.lv),
              const SizedBox(width: 6),
              Text(
                isKorean ? 'AI 변환 도안' : 'AI Converted',
                style: T.caption.copyWith(
                    color: C.lv, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                isKorean
                    ? '$completedSteps/$totalSteps 완료'
                    : '$completedSteps/$totalSteps done',
                style: T.caption.copyWith(color: C.tx2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: C.lv.withValues(alpha: 0.12),
            color: C.lv,
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
          const SizedBox(height: 10),
          ...sections.take(3).map((sec) {
            final steps = (sec['steps'] as List?) ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right_rounded,
                      size: 14, color: C.tx2),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sec['title'] as String? ?? '',
                      style: T.sm.copyWith(color: C.tx),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    isKorean
                        ? '${steps.length}단계'
                        : '${steps.length} steps',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                ],
              ),
            );
          }),
          if (sections.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isKorean
                    ? '외 ${sections.length - 3}개 섹션...'
                    : '+${sections.length - 3} more sections...',
                style: T.caption.copyWith(color: C.tx2),
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
