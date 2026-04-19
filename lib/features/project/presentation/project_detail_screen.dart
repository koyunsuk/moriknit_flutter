import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/book_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/project_provider.dart';
import '../../market/domain/market_item.dart';
import '../../../providers/project_step_provider.dart';
import '../../../providers/needle_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/template_provider.dart';
import '../../../providers/yarn_provider.dart';
import '../../counter/domain/counter_model.dart';
import '../../my/domain/needle_model.dart';
import '../../swatch/domain/swatch_model.dart';
import '../../yarn/domain/yarn_model.dart';
import '../../swatch/presentation/swatch_input_screen.dart';
import '../../../core/router/routes.dart';
import '../data/project_pdf_service.dart';
import '../data/public_project_service.dart';
import '../domain/project_model.dart';
import '../domain/project_step.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../pattern/presentation/pattern_detail_screen.dart';
import 'widgets/project_progress_section.dart';
import 'widgets/project_share_card.dart';
class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  bool _isEditing = false;
  bool _isCardEditMode = false;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String _editStatus = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishToGallery(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final service = ref.read(publicProjectServiceProvider);
    final alreadyPublished = await service.isPublished(uid: user.uid, projectId: project.id);

    if (!mounted) return;

    // ignore: use_build_context_synchronously
    final confirm = await showDialog<bool>(
      context: context, // ignore: use_build_context_synchronously
      builder: (ctx) => AlertDialog(
        title: Text(
          alreadyPublished
              ? (isKorean ? '갤러리에서 내리기' : 'Unpublish')
              : (isKorean ? '갤러리에 공개' : 'Publish to gallery'),
          style: T.h3,
        ),
        content: Text(
          alreadyPublished
              ? (isKorean ? '커뮤니티 갤러리에서 이 작품을 내릴까요?' : 'Remove this project from the gallery?')
              : (isKorean ? '완성한 작품을 커뮤니티 갤러리에 공개할까요? 다른 유저가 볼 수 있어요.' : 'Share this project to the community gallery?'),
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(alreadyPublished ? (isKorean ? '내리기' : 'Unpublish') : (isKorean ? '공개' : 'Publish')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      // ignore: use_build_context_synchronously
      await runWithMoriLoadingDialog<void>(
        context, // ignore: use_build_context_synchronously
        message: isKorean ? '처리하는 중입니다.' : 'Processing...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () async {
          if (alreadyPublished) {
            await service.unpublishProject(uid: user.uid, projectId: project.id);
          } else {
            final currentUser = ref.read(currentUserProvider).valueOrNull;
            final ownerName = currentUser?.displayName ?? user.displayName ?? '';
            final steps = ref.read(projectStepsProvider(project.id)).valueOrNull ?? [];
            final completedStepTitles = steps.where((s) => s.isDone).map((s) => s.name).toList();
            // step 사진 + 프로젝트 앨범 사진 모두 포함
            final stepPhotoUrls = steps
                .where((s) => s.photoUrl?.isNotEmpty == true)
                .map((s) => s.photoUrl!)
                .toList();
            final allPhotoUrls = {...stepPhotoUrls, ...project.photoUrls}.toList();
            await service.publishProject(
              uid: user.uid,
              ownerName: ownerName,
              project: project,
              stepTitles: completedStepTitles,
              photoUrls: allPhotoUrls,
            );
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        messenger,
        message: alreadyPublished
            ? (isKorean ? '갤러리에서 내렸어요.' : 'Removed from gallery.')
            : (isKorean ? '갤러리에 공개됐어요!' : 'Published to gallery!'),
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  Future<void> _saveEdit(ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(projectRepositoryProvider).updateProject(
          project.copyWith(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            status: _editStatus,
          ),
        ),
      );
      if (!mounted) return;
      setState(() { _isEditing = false; _isCardEditMode = false; });
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '저장됐어요.' : 'Saved.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final t = ref.read(appStringsProvider);
    bool deleteSwatches = false;
    bool deleteCounters = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t.deleteProject, style: T.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.deleteProjectConfirm, style: T.body),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isKorean ? '연결된 스와치도 삭제' : 'Also delete linked swatches',
                  style: T.body,
                ),
                value: deleteSwatches,
                onChanged: (v) => setState(() => deleteSwatches = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isKorean ? '연결된 카운터도 삭제' : 'Also delete linked counters',
                  style: T.body,
                ),
                value: deleteCounters,
                onChanged: (v) => setState(() => deleteCounters = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: C.og),
              onPressed: () async {
                Navigator.pop(ctx);
                await runWithMoriLoadingDialog<void>(
                  context,
                  message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
                  subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                  task: () async {
                    if (deleteSwatches) {
                      final swatchDocs = await FirebaseFirestore.instance
                          .collection('swatches')
                          .where('projectId', isEqualTo: id)
                          .get();
                      for (final doc in swatchDocs.docs) {
                        await doc.reference.delete();
                      }
                    }
                    if (deleteCounters) {
                      final counterDocs = await FirebaseFirestore.instance
                          .collection('counters')
                          .where('projectId', isEqualTo: id)
                          .get();
                      for (final doc in counterDocs.docs) {
                        await doc.reference.delete();
                      }
                    }
                    await ref.read(projectRepositoryProvider).deleteProject(id);
                  },
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(t.deleteProject),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    final userName = ref.read(currentUserProvider).valueOrNull?.displayName ?? '';
    try {
      final bytes = await runWithMoriLoadingDialog<List<int>>(
        context,
        message: isKorean ? 'PDF를 생성하는 중입니다.' : 'Generating PDF...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          // 캐시된 값 우선, 없으면 future로 대기 (병렬 로드)
          Future<V> awaitProvider<V>(AsyncValue<V> cached, Future<V> future) =>
              cached.valueOrNull != null ? Future.value(cached.valueOrNull!) : future;

          final rawResults = await Future.wait([
            awaitProvider(
              ref.read(projectStepsProvider(project.id)),
              ref.read(projectStepsProvider(project.id).future),
            ),
            awaitProvider(
              ref.read(counterListProvider),
              ref.read(counterListProvider.future),
            ),
            awaitProvider(
              ref.read(swatchListProvider),
              ref.read(swatchListProvider.future),
            ),
            awaitProvider(
              ref.read(patternListProvider),
              ref.read(patternListProvider.future),
            ),
          ]);

          final steps = rawResults[0] as List<ProjectStep>;
          final allCounters = rawResults[1] as List<CounterModel>;
          final allSwatches = rawResults[2] as List<SwatchModel>;
          final allPatterns = rawResults[3] as List<PatternChart>;

          final counters = allCounters.where((c) => project.counterIds.contains(c.id)).toList();
          final swatches = project.swatchId.isNotEmpty
              ? allSwatches.where((s) => s.id == project.swatchId).toList()
              : <SwatchModel>[];
          final patterns = project.sourcePatternId.isNotEmpty
              ? allPatterns.where((p) => p.id == project.sourcePatternId).toList()
              : allPatterns;

          return ProjectPdfService.generateProjectPdfBytes(
            project: project,
            steps: steps,
            swatches: swatches,
            patterns: patterns,
            counters: counters,
            isKorean: isKorean,
            userName: userName,
          );
        },
      );
      if (!mounted) return;
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final safeName = project.title.replaceAll(RegExp(r'[^\w가-힣]'), '_');
      final rawUser = userName.trim().isEmpty ? '' : userName.trim();
      final safeUser = rawUser.replaceAll(RegExp(r'[^\w가-힣]'), '_');
      final filename = safeUser.isEmpty
          ? '${safeName}_$dateStr.pdf'
          : '${safeName}_${dateStr}_$safeUser.pdf';
      // Printing.sharePdf handles file sharing natively on all platforms
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? 'PDF가 저장되었어요.' : 'PDF saved.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  Future<void> _shareProjectText(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final lines = <String>[
      isKorean ? '[모리니트] 프로젝트 공유' : '[MoriKnit] Project Share',
      '${isKorean ? '작품명' : 'Title'}: ${project.title}',
    ];
    if (project.yarnName.isNotEmpty) {
      final yarnInfo = project.yarnBrandName.isNotEmpty
          ? '${project.yarnName} (${project.yarnBrandName})'
          : project.yarnName;
      lines.add('${isKorean ? '실' : 'Yarn'}: $yarnInfo');
    }
    if (project.finishDate != null) {
      lines.add('${isKorean ? '완성일' : 'Finished'}: ${DateFormat('yyyy-MM-dd').format(project.finishDate!)}');
    }
    if (project.description.isNotEmpty) {
      lines.add('');
      lines.add(project.description);
    }
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  Future<void> _showPatternSellSheet(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final titleCtrl = TextEditingController(text: project.title);
    final descCtrl = TextEditingController(text: project.description);
    final priceCtrl = TextEditingController(text: '0');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 핸들
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isKorean ? '패턴 판매 등록' : 'Sell Pattern', style: T.h3),
                const SizedBox(height: 4),
                Text(
                  isKorean ? '직접 제작한 도안을 모리니트 마켓에 등록해요. 관리자 승인 후 공개돼요.' : 'Submit your pattern to MoriKnit Market. It will be visible after admin approval.',
                  style: T.caption.copyWith(color: C.mu),
                ),
                const SizedBox(height: 20),
                // 커버 이미지 미리보기
                if (project.coverPhotoUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(project.coverPhotoUrl, height: 140, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                ],
                SectionTitle(title: isKorean ? '제목' : 'Title'),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: isKorean ? '판매 제목' : 'Listing title',
                    hintText: project.title,
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 14),
                SectionTitle(title: isKorean ? '설명' : 'Description'),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isKorean ? '도안 설명' : 'Pattern description',
                    hintText: isKorean ? '사용 실, 난이도, 완성 크기 등을 적어주세요.' : 'Yarn, difficulty, size...',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 14),
                SectionTitle(title: isKorean ? '가격 (원)' : 'Price (KRW)'),
                const SizedBox(height: 6),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isKorean ? '가격' : 'Price',
                    hintText: '0',
                    suffixText: isKorean ? '원' : 'KRW',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final desc = descCtrl.text.trim();
                      final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                      if (title.isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        final sellerName = user.displayName ?? (isKorean ? '알 수 없음' : 'Unknown');
                        final item = MarketItem(
                          id: '',
                          sellerUid: user.uid,
                          sellerName: sellerName,
                          title: title,
                          description: desc,
                          price: price,
                          category: 'pattern',
                          accentHex: '#8B5CF6',
                          imageType: 'pattern',
                          isSoldOut: false,
                          status: 'pending',
                        );
                        // ignore: use_build_context_synchronously
                        await runWithMoriLoadingDialog<void>(
                          context,
                          message: isKorean ? '등록하는 중입니다.' : 'Submitting...',
                          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                          task: () => ref.read(marketRepositoryProvider).createItem(
                            item,
                            imageBytes: null,
                            extraData: {
                              'sourceProjectId': project.id,
                              'coverPhotoUrl': project.coverPhotoUrl,
                              if (project.sourcePatternId.isNotEmpty)
                                'sourcePatternId': project.sourcePatternId,
                            },
                          ),
                        );
                        if (!context.mounted) return;
                        showSavedSnackBar(
                          ScaffoldMessenger.of(context),
                          message: isKorean ? '등록됐어요. 관리자 승인 후 마켓에 공개돼요.' : 'Submitted! Will be visible after approval.',
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                      }
                    },
                    child: Text(isKorean ? '판매 등록 신청' : 'Submit for Review'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    titleCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
  }

  Future<void> _showShareCardDialog(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final steps = ref.read(projectStepsProvider(project.id)).valueOrNull ?? [];
    final cardKey = GlobalKey();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: C.bd2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(isKorean ? '완성 기록지' : 'Completion Card', style: T.h3),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: ProjectShareCard(
                    project: project,
                    steps: steps,
                    repaintKey: cardKey,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // 시트 닫기 전에 이미지 캡처 (닫히면 repaintKey 무효화됨)
                    await shareProjectCard(context, cardKey, project.title);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(isKorean ? '이미지로 공유하기' : 'Share as image'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _duplicateProject(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '복사하는 중입니다.' : 'Duplicating...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final copied = await ref.read(projectRepositoryProvider).duplicateProject(project);
          await ref.read(projectStepRepositoryProvider).copySteps(project.id, copied.id);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean ? '복사됐어요.' : 'Duplicated.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final projectAsync = ref.watch(projectByIdProvider(widget.projectId));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const MoriKnitTitle(fontSize: 18),
        actions: _isEditing
            ? [
                IconButton(
                  icon: Icon(Icons.close, color: C.tx),
                  onPressed: () => setState(() { _isEditing = false; _isCardEditMode = false; }),
                ),
                projectAsync.whenOrNull(
                      data: (project) => project == null
                          ? null
                          : TextButton(
                              onPressed: () => _saveEdit(project),
                              child: Text(isKorean ? '저장' : 'Save', style: TextStyle(color: C.lv, fontWeight: FontWeight.w700)),
                            ),
                    ) ??
                    const SizedBox.shrink(),
              ]
            : [
                projectAsync.whenOrNull(
                      data: (project) => project == null
                          ? null
                          : PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: C.tx),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  setState(() {
                                    _isEditing = true;
                                    _isCardEditMode = true;
                                    _titleCtrl.text = project.title;
                                    _descCtrl.text = project.description;
                                    _editStatus = project.status;
                                  });
                                } else if (value == 'copy') {
                                  _duplicateProject(context, ref, project);
                                } else if (value == 'pdf') {
                                  await _exportPdf(context, ref, project);
                                } else if (value == 'share_text') {
                                  await _shareProjectText(context, ref, project);
                                } else if (value == 'share_card') {
                                  await _showShareCardDialog(context, ref, project);
                                } else if (value == 'publish') {
                                  await _publishToGallery(context, ref, project);
                                } else if (value == 'sell_pattern') {
                                  await _showPatternSellSheet(context, ref, project);
                                } else if (value == 'delete') {
                                  _confirmDelete(context, ref, project.id);
                                }
                              },
                              itemBuilder: (_) {
                                final isKorean = ref.read(appLanguageProvider).isKorean;
                                PopupMenuItem<String> menuItem(String value, IconData icon, Color iconColor, String label, {TextStyle? textStyle}) {
                                  return PopupMenuItem<String>(
                                    value: value,
                                    child: Row(children: [
                                      Icon(icon, size: 18, color: iconColor),
                                      const SizedBox(width: 10),
                                      Text(label, style: textStyle),
                                    ]),
                                  );
                                }
                                return [
                                  menuItem('edit', Icons.edit_rounded, C.lv, isKorean ? '수정' : 'Edit'),
                                  menuItem('copy', Icons.copy_rounded, C.mu, isKorean ? '복사' : 'Duplicate'),
                                  menuItem('pdf', Icons.picture_as_pdf_outlined, C.lv, isKorean ? 'PDF 내보내기' : 'Export PDF'),
                                  menuItem('share_text', Icons.share_rounded, C.mu, isKorean ? '외부 공유' : 'Share'),
                                  if (project.isFinished)
                                    menuItem('share_card', Icons.ios_share_rounded, C.pk, isKorean ? '완성 기록지 공유' : 'Share card'),
                                  if (project.isFinished)
                                    menuItem('publish', Icons.public_rounded, C.lv, isKorean ? '갤러리에 공개' : 'Publish to gallery'),
                                  if (project.isFinished && project.originProjectId.isEmpty)
                                    menuItem('sell_pattern', Icons.sell_rounded, C.lmD, isKorean ? '패턴 판매 등록' : 'Sell pattern'),
                                  menuItem('delete', Icons.delete_rounded, C.og, isKorean ? '삭제' : 'Delete', textStyle: TextStyle(color: C.og)),
                                ];
                              },
                            ),
                    ) ??
                    const SizedBox.shrink(),
              ],
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return Center(child: Text(t.projectNotFound, style: T.body));
          }
          return _ProjectBody(
            project: project,
            isEditing: _isEditing,
            isCardEditMode: _isCardEditMode,
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            editStatus: _editStatus,
            onStatusChanged: (s) => setState(() => _editStatus = s),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(
          child: Text(t.failedToLoadProject(e.toString()), style: T.body),
        ),
      ),
    );
  }
}

class _ProjectBody extends ConsumerStatefulWidget {
  final ProjectModel project;
  final bool isEditing;
  final bool isCardEditMode;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final String editStatus;
  final ValueChanged<String> onStatusChanged;

  const _ProjectBody({
    required this.project,
    required this.isEditing,
    required this.isCardEditMode,
    required this.titleCtrl,
    required this.descCtrl,
    required this.editStatus,
    required this.onStatusChanged,
  });

  @override
  ConsumerState<_ProjectBody> createState() => _ProjectBodyState();
}

class _ProjectBodyState extends ConsumerState<_ProjectBody> {
  final _scrollCtrl = ScrollController();
  final _stepsAnchorKey = GlobalKey();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToLastStep() {
    final ctx = _stepsAnchorKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } else if (_scrollCtrl.hasClients) {
      final maxExtent = _scrollCtrl.position.maxScrollExtent;
      if (maxExtent > 0) {
        _scrollCtrl.animateTo(maxExtent,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    }
  }

  Future<void> _pickAndUpdateCover(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    ImageSource? source;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: Text(isKorean ? '즉시 촬영' : 'Take photo'),
            onTap: () { source = ImageSource.camera; Navigator.pop(ctx); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery'),
            onTap: () { source = ImageSource.gallery; Navigator.pop(ctx); },
          ),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(source: source!, imageQuality: 85, maxWidth: 1600);
    if (picked == null || !mounted) return;

    try {
      // ignore: use_build_context_synchronously
      await runWithMoriLoadingDialog<void>(
        context, // ignore: use_build_context_synchronously
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final repo = ref.read(projectRepositoryProvider);
          final bytes = await picked.readAsBytes();
          final ext = picked.name.split('.').last;
          final fileName = '${project.id}_cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final storageRef = FirebaseStorage.instance.ref('project_covers/$fileName');
          await storageRef.putData(bytes);
          final url = await storageRef.getDownloadURL();
          await repo.updateProject(project.copyWith(coverPhotoUrl: url));
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger, message: isKorean ? '커버 이미지가 변경됐어요.' : 'Cover image updated.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final t = ref.watch(appStringsProvider);
    final project = widget.project;
    final isEditing = widget.isEditing;
    final isCardEditMode = widget.isCardEditMode;
    final titleCtrl = widget.titleCtrl;
    final descCtrl = widget.descCtrl;
    final editStatus = widget.editStatus;
    final onStatusChanged = widget.onStatusChanged;
    final countersAsync = ref.watch(countersByProjectProvider(project.id));
    final linkedSwatches = ref.watch(swatchesByProjectIdProvider(project.id));


    return Stack(
      children: [
        const BgOrbs(),
        ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          children: [
            // Fork 출처 배너
            if (project.originProjectId.isNotEmpty) ...[
              GestureDetector(
                onTap: project.sourcePatternId.isNotEmpty
                    ? () async {
                        final chart = await ref
                            .read(patternRepositoryProvider)
                            .getFromUser(project.originUserId, project.sourcePatternId);
                        if (!context.mounted) return;
                        if (chart == null) {
                          showSaveErrorSnackBar(
                            ScaffoldMessenger.of(context),
                            message: isKorean ? '원본 도안을 불러올 수 없어요.' : 'Could not load the original pattern.',
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PatternDetailScreen(chart: chart)),
                        );
                      }
                    : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.lv.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fork_right_rounded, size: 16, color: C.lv),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isKorean
                              ? '${project.originOwnerName.isNotEmpty ? project.originOwnerName : "다른 사용자"}님의 프로젝트에서 Fork됐어요'
                              : 'Forked from ${project.originOwnerName.isNotEmpty ? project.originOwnerName : "another user"}\'s project',
                          style: T.caption.copyWith(color: C.lv),
                        ),
                      ),
                      if (project.sourcePatternId.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 14, color: C.lv),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (project.coverPhotoUrl.isNotEmpty) ...[
              GestureDetector(
                onTap: (isEditing && isCardEditMode) ? () => _pickAndUpdateCover(context, ref, project) : null,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 500),
                        child: Image.network(
                          project.coverPhotoUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    if (isEditing && isCardEditMode)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isKorean ? '상세한 수정은 우측 상단의 점세개 메뉴에 있어요' : 'For detailed editing, use the ⋮ menu at the top right.',
                style: T.caption.copyWith(color: C.mu),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
            ],
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEditing) ...[
                    TextField(
                      controller: titleCtrl,
                      style: T.h2,
                      decoration: InputDecoration(
                        labelText: isKorean ? '프로젝트 이름' : 'Project title',
                        fillColor: C.gx,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      style: T.body,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: isKorean ? '설명' : 'Description',
                        fillColor: C.gx,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: ProjectStatus.values.map((s) {
                        final isSelected = editStatus == s.value;
                        return GestureDetector(
                          onTap: () => onStatusChanged(s.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? C.lv : C.lvL,
                              border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s.localizedLabel(isKorean),
                              style: TextStyle(
                                color: isSelected ? Colors.white : C.lvD,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.title.isEmpty ? t.untitledProject : project.title,
                            style: T.h2,
                          ),
                        ),
                        MoriChip(
                          label: project.statusEnum.localizedLabel(isKorean),
                          type: ChipType.lavender,
                        ),
                      ],
                    ),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(project.description, style: T.body.copyWith(color: C.mu)),
                    ],
                  ],
                  const SizedBox(height: 12),
                  ProjectProgressSection(project: project),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 실(Yarn) 카드
            Builder(builder: (context) {
              final yarns = ref.watch(yarnListProvider).valueOrNull ?? [];
              // yarnIds(ID 참조)로 먼저 매칭, 없으면 brandName으로 fallback
              final matchedYarn = yarns.cast<YarnModel?>().firstWhere(
                (y) => y != null && project.yarnIds.isNotEmpty && project.yarnIds.contains(y.id),
                orElse: () => yarns.cast<YarnModel?>().firstWhere(
                  (y) => y != null && project.yarnBrandName.isNotEmpty && y.brandName == project.yarnBrandName,
                  orElse: () => null,
                ),
              );
              // ID로 매칭된 실이 있으면 최신 데이터로 표시 이름 결정
              final displayBrandName = matchedYarn?.brandName ?? project.yarnBrandName;
              final displayYarnName = matchedYarn?.name ?? project.yarnName;
              final hasYarn = displayBrandName.isNotEmpty || displayYarnName.isNotEmpty;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isCardEditMode ? null : () {
                  if (matchedYarn != null && matchedYarn.id.isNotEmpty) {
                    context.push('/yarn-detail/${matchedYarn.id}');
                  } else {
                    context.push('/yarn-list');
                  }
                },
                child: GlassCard(
                  color: C.bg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: C.pk, size: 18),
                          const SizedBox(width: 6),
                          Text(isKorean ? '🧵 실 정보' : '🧵 Yarn', style: T.bodyBold),
                          const Spacer(),
                          if (isCardEditMode && hasYarn)
                            IconButton(
                              icon: Icon(Icons.link_off, color: C.og, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: isKorean ? '연결 해제' : 'Unlink',
                              onPressed: () async {
                                await runWithMoriLoadingDialog<void>(
                                  context,
                                  message: isKorean ? '연결 해제 중입니다.' : 'Unlinking...',
                                  subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                  task: () => ref.read(projectRepositoryProvider).updateProject(
                                    project.copyWith(yarnBrandName: '', yarnName: '', yarnColor: ''),
                                  ),
                                );
                                if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결이 해제됐어요.' : 'Unlinked.');
                              },
                            ),
                          if (!isCardEditMode) Icon(Icons.chevron_right, color: C.mu, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MaterialThumbnail(
                            photoUrl: matchedYarn?.photoUrl ?? '',
                            defaultIcon: Icons.bolt_rounded,
                            iconColor: C.pk,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoRow(label: t.yarnBrand, value: displayBrandName.isEmpty ? t.brandNotSet : displayBrandName),
                                _InfoRow(label: t.yarnName, value: displayYarnName.isEmpty ? t.notAvailable : displayYarnName),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!hasYarn) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            isKorean ? '연결된 실 없어요.' : 'No linked yarn.',
                            style: T.body.copyWith(color: C.mu),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      if (isCardEditMode) ...[
                        const SizedBox(height: 10),
                        _CardEditActions(
                          isKorean: isKorean,
                          onLinkFromWork: () => _linkExistingYarn(context, ref),
                          onCreateNew: () => context.push('/yarn-list'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            // 바늘(Needle) 카드
            Builder(builder: (context) {
              final needles = ref.watch(needleListProvider).valueOrNull ?? [];
              final linkedNeedle = needles.cast<NeedleModel?>().firstWhere(
                (n) => n != null && (project.needleBrandName.isNotEmpty
                    ? n.brandName == project.needleBrandName
                    : project.needleSize > 0 && n.size == project.needleSize),
                orElse: () => null,
              );
              final hasNeedle = project.needleSize > 0 || project.needleBrandName.isNotEmpty;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isCardEditMode ? null : (hasNeedle && linkedNeedle != null && linkedNeedle.id.isNotEmpty)
                    ? () => context.push('/needle-detail/${linkedNeedle.id}')
                    : null,
                child: GlassCard(
                  color: C.bg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten_rounded, color: C.lv, size: 18),
                          const SizedBox(width: 6),
                          Text(isKorean ? '🪡 바늘 정보' : '🪡 Needle', style: T.bodyBold),
                          const Spacer(),
                          if (isCardEditMode && hasNeedle)
                            IconButton(
                              icon: Icon(Icons.link_off, color: C.og, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: isKorean ? '연결 해제' : 'Unlink',
                              onPressed: () async {
                                await runWithMoriLoadingDialog<void>(
                                  context,
                                  message: isKorean ? '연결 해제 중입니다.' : 'Unlinking...',
                                  subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                  task: () => ref.read(projectRepositoryProvider).updateProject(
                                    project.copyWith(needleSize: 0.0, needleBrandName: ''),
                                  ),
                                );
                                if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결이 해제됐어요.' : 'Unlinked.');
                              },
                            ),
                          if (!isCardEditMode && hasNeedle) Icon(Icons.chevron_right, color: C.mu, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MaterialThumbnail(
                            photoUrl: linkedNeedle?.photoUrl ?? '',
                            defaultIcon: Icons.straighten_rounded,
                            iconColor: C.lv,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoRow(label: t.needle, value: project.needleSize > 0 ? t.needleSize(project.needleSize) : t.needleNotSet),
                                _InfoRow(label: t.needleBrand, value: project.needleBrandName.isEmpty ? t.brandNotSet : project.needleBrandName),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!hasNeedle) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            isKorean ? '연결된 바늘 없어요.' : 'No linked needle.',
                            style: T.body.copyWith(color: C.mu),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      if (isCardEditMode) ...[
                        const SizedBox(height: 10),
                        _CardEditActions(
                          isKorean: isKorean,
                          onLinkFromWork: () => _linkExistingNeedle(context, ref),
                          onCreateNew: () => context.push(Routes.needles),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            // 스와치 정보 섹션
            const SizedBox(height: 12),
            GlassCard(
              color: C.bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.grid_view_rounded, color: C.lmD, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        isKorean ? '스와치 정보' : 'Swatch Info',
                        style: T.bodyBold,
                      ),
                      const Spacer(),
                      if (!isCardEditMode && linkedSwatches.isNotEmpty) Icon(Icons.chevron_right, color: C.mu, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (linkedSwatches.isEmpty) ...[
                    Center(
                      child: Text(
                        isKorean ? '연결된 스와치 없어요.' : 'No linked swatches.',
                        style: T.body.copyWith(color: C.mu),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else
                    ...linkedSwatches.map(
                      (s) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: isCardEditMode ? null : () => context.push('${Routes.swatchList}/${s.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: C.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _MaterialThumbnail(
                                photoUrl: s.beforePhotoUrl.isNotEmpty
                                    ? s.beforePhotoUrl
                                    : s.afterPhotoUrl,
                                defaultIcon: Icons.grid_view_rounded,
                                iconColor: C.lmD,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s.swatchName.isNotEmpty
                                      ? s.swatchName
                                      : s.yarnName.isNotEmpty
                                          ? s.yarnName
                                          : (isKorean ? '이름 없음' : 'Untitled'),
                                  style: T.bodyBold,
                                ),
                              ),
                              if (isCardEditMode)
                                IconButton(
                                  icon: Icon(Icons.link_off, color: C.og, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: isKorean ? '연결 해제' : 'Unlink',
                                  onPressed: () async {
                                    await runWithMoriLoadingDialog<void>(
                                      context,
                                      message: isKorean ? '연결 해제 중입니다.' : 'Unlinking...',
                                      subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                      task: () => ref.read(swatchRepositoryProvider).updateSwatch(s.copyWith(projectId: '')),
                                    );
                                    if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결이 해제됐어요.' : 'Unlinked.');
                                  },
                                )
                              else ...[
                                Text(
                                  '${s.beforeStitchCount}코×${s.beforeRowCount}단',
                                  style: T.caption.copyWith(color: C.mu),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, size: 16, color: C.mu),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (isCardEditMode) ...[
                    const SizedBox(height: 10),
                    _CardEditActions(
                      isKorean: isKorean,
                      onLinkFromWork: () => _linkExistingSwatch(context, ref),
                      onCreateNew: () => _addSwatch(context, ref, isKorean),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── 도안 연결 섹션 ─────────────────────────
            GlassCard(
              color: C.bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.grid_on_rounded, color: C.lmD, size: 18),
                      const SizedBox(width: 6),
                      Text(isKorean ? '연결된 도안' : 'Linked Pattern', style: T.bodyBold),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final patternsAsync = ref.watch(patternListProvider);
                    final allPatterns = patternsAsync.valueOrNull ?? [];
                    final linked = project.sourcePatternId.isNotEmpty
                        ? allPatterns.where((p) => p.id == project.sourcePatternId).firstOrNull
                        : null;

                    if (linked == null) {
                      return Center(
                        child: Text(
                          isKorean ? '연결된 도안 없어요.' : 'No linked pattern.',
                          style: T.body.copyWith(color: C.mu),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isCardEditMode ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PatternDetailScreen(chart: linked)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _MaterialThumbnail(
                              photoUrl: linked.imageUrl,
                              defaultIcon: Icons.grid_on_rounded,
                              iconColor: C.lmD,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                linked.title.isNotEmpty ? linked.title : (isKorean ? '이름 없음' : 'Untitled'),
                                style: T.bodyBold,
                              ),
                            ),
                            if (isCardEditMode)
                              IconButton(
                                icon: Icon(Icons.link_off_rounded, size: 18, color: C.mu),
                                onPressed: () async {
                                  await runWithMoriLoadingDialog<void>(
                                    context,
                                    message: isKorean ? '연결 해제 중입니다.' : 'Unlinking...',
                                    subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                    task: () => ref.read(projectRepositoryProvider).updateProject(
                                          project.copyWith(sourcePatternId: ''),
                                        ),
                                  );
                                  if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결이 해제됐어요.' : 'Unlinked.');
                                },
                              )
                            else
                              Icon(Icons.chevron_right, color: C.mu, size: 18),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (isCardEditMode) ...[
                    const SizedBox(height: 10),
                    _CardEditActions(
                      isKorean: isKorean,
                      onLinkFromWork: () => _linkPattern(context, ref),
                      onCreateNew: null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── 참고 도서 섹션 ─────────────────────────
            GlassCard(
              color: C.bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: C.lmD, size: 18),
                      const SizedBox(width: 6),
                      Text(isKorean ? '참고 도서' : 'Reference Book', style: T.bodyBold),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    if (project.referenceBookId.isEmpty) {
                      return Text(
                        isKorean ? '연결된 도서 없어요.' : 'No reference book.',
                        style: T.body.copyWith(color: C.mu),
                      );
                    }
                    final bookAsync = ref.watch(bookDetailProvider(project.referenceBookId));
                    return bookAsync.when(
                      data: (book) {
                        if (book == null) {
                          return Text(
                            isKorean ? '도서 정보를 불러올 수 없어요.' : 'Book not found.',
                            style: T.body.copyWith(color: C.mu),
                          );
                        }
                        return Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 44,
                                height: 60,
                                child: book.coverUrl.isNotEmpty
                                    ? Image.network(
                                        book.coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: C.lvL,
                                          child: Icon(Icons.menu_book_rounded, color: C.lv, size: 24),
                                        ),
                                      )
                                    : Container(
                                        color: C.lvL,
                                        child: Icon(Icons.menu_book_rounded, color: C.lv, size: 24),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title.isNotEmpty ? book.title : (isKorean ? '(제목 없음)' : '(No title)'),
                                    style: T.bodyBold,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (book.author.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(book.author, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                  if (book.publisher.isNotEmpty || book.publishYear.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (book.publisher.isNotEmpty) book.publisher,
                                        if (book.publishYear.isNotEmpty) book.publishYear,
                                      ].join(' · '),
                                      style: T.caption.copyWith(color: C.mu, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isCardEditMode)
                              IconButton(
                                icon: Icon(Icons.link_off_rounded, size: 18, color: C.mu),
                                onPressed: () async {
                                  await runWithMoriLoadingDialog<void>(
                                    context,
                                    message: isKorean ? '연결 해제 중입니다.' : 'Unlinking...',
                                    subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                    task: () => ref.read(projectRepositoryProvider).updateProject(
                                          project.copyWith(referenceBookId: ''),
                                        ),
                                  );
                                  if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결이 해제됐어요.' : 'Unlinked.');
                                },
                              ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              color: C.bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: C.lmD, size: 18),
                      const SizedBox(width: 6),
                      Text(t.counters, style: T.bodyBold),
                      const Spacer(),
                      if (countersAsync.valueOrNull?.isNotEmpty ?? false) Icon(Icons.chevron_right, color: C.mu, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  countersAsync.when(
                    data: (counters) {
                      if (counters.isEmpty) {
                        return Center(
                          child: Text(
                            isKorean ? '연결된 카운터 없어요.' : 'No linked counters.',
                            style: T.body.copyWith(color: C.mu),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...counters.map((counter) => _CounterTile(
                                counter: counter,
                                onTap: isCardEditMode ? null : () => context.push('/counter/${counter.id}'),
                                onUnlink: isCardEditMode
                                    ? () async {
                                        await runWithMoriLoadingDialog<void>(
                                          context,
                                          message: isKorean ? '연결 해제 중입니다.' : 'Unlinking...',
                                          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                          task: () async {
                                            await ref.read(counterRepositoryProvider).updateCounter(counter.copyWith(projectId: ''));
                                            await ref.read(projectRepositoryProvider).removeCounter(project.id, counter.id);
                                          },
                                        );
                                        if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결이 해제됐어요.' : 'Unlinked.');
                                      }
                                    : null,
                              )),
                        ],
                      );
                    },
                    loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                    error: (e, _) => Text(
                      t.failedToLoadCounters(e.toString()),
                      style: T.body.copyWith(color: C.og),
                    ),
                  ),
                  if (isCardEditMode) ...[
                    const SizedBox(height: 10),
                    _CardEditActions(
                      isKorean: isKorean,
                      onLinkFromWork: () => _linkExistingCounter(context, ref),
                      onCreateNew: () => _addCounter(context, ref),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StepsSection(project: project, isCardEditMode: isCardEditMode, lastAnchorKey: _stepsAnchorKey, onScrollToLastStep: _scrollToLastStep),
            if (project.memo.isNotEmpty) ...[
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.memo, style: T.bodyBold),
                    const SizedBox(height: 8),
                    Text(project.memo, style: T.body),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _ProjectPhotosSection(project: project, isCardEditMode: isCardEditMode),
          ],
        ),
      ],
    );
  }

  void _linkExistingYarn(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final yarns = ref.read(yarnListProvider).valueOrNull ?? [];
    if (yarns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isKorean ? '등록된 실이 없어요.' : 'No yarns available.'),
      ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '내 실에서 연결' : 'Link from My Yarns', style: T.h3),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: yarns.length,
            itemBuilder: (_, i) {
              final yarn = yarns[i];
              return ListTile(
                title: Text('${yarn.brandName}  ${yarn.name}', style: T.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  await runWithMoriLoadingDialog<void>(
                    context,
                    message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                    subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                    task: () => ref.read(projectRepositoryProvider).updateProject(
                      widget.project.copyWith(
                        yarnBrandName: yarn.brandName,
                        yarnName: yarn.name,
                        yarnColor: yarn.color,
                        yarnIds: yarn.id.isNotEmpty ? [yarn.id] : widget.project.yarnIds,
                      ),
                    ),
                  );
                  if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결됐어요.' : 'Linked.');
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '닫기' : 'Close'))],
      ),
    );
  }

  void _linkExistingNeedle(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final needles = ref.read(needleListProvider).valueOrNull ?? [];
    if (needles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isKorean ? '등록된 바늘이 없어요.' : 'No needles available.'),
      ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '내 바늘에서 연결' : 'Link from My Needles', style: T.h3),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: needles.length,
            itemBuilder: (_, i) {
              final needle = needles[i];
              return ListTile(
                title: Text('${needle.size}mm  ${needle.brandName}', style: T.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  await runWithMoriLoadingDialog<void>(
                    context,
                    message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                    subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                    task: () => ref.read(projectRepositoryProvider).updateProject(
                      widget.project.copyWith(needleSize: needle.size, needleBrandName: needle.brandName),
                    ),
                  );
                  if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결됐어요.' : 'Linked.');
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '닫기' : 'Close'))],
      ),
    );
  }

  void _linkPattern(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final allPatterns = cRef.watch(patternListProvider).valueOrNull ?? [];
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
                      decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(isKorean ? '내 도안에서 연결' : 'Link from My Patterns', style: T.h3),
                  ),
                  if (allPatterns.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          isKorean ? '등록된 도안이 없어요.' : 'No patterns available.',
                          style: T.body.copyWith(color: C.mu),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: allPatterns.length,
                        itemBuilder: (_, i) {
                          final pattern = allPatterns[i];
                          return ListTile(
                            leading: pattern.imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(pattern.imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(6)),
                                    child: Icon(Icons.grid_on_rounded, size: 20, color: C.lv),
                                  ),
                            title: Text(
                              pattern.title.isNotEmpty ? pattern.title : (isKorean ? '이름 없음' : 'Untitled'),
                              style: T.body,
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await runWithMoriLoadingDialog<void>(
                                context,
                                message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                                subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                task: () => ref.read(projectRepositoryProvider).updateProject(
                                      widget.project.copyWith(sourcePatternId: pattern.id),
                                    ),
                              );
                              if (context.mounted) {
                                showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '연결됐어요.' : 'Linked.');
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

  void _linkExistingSwatch(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final allSwatches = cRef.watch(swatchListProvider).valueOrNull ?? [];
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
                        color: C.bd2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      isKorean ? '내 스와치에서 연결' : 'Link from My Swatches',
                      style: T.h3,
                    ),
                  ),
                  if (allSwatches.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          isKorean ? '등록된 스와치가 없어요.' : 'No swatches available.',
                          style: T.body.copyWith(color: C.mu),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: allSwatches.length,
                        itemBuilder: (_, i) {
                          final swatch = allSwatches[i];
                          final name = swatch.swatchName.isNotEmpty
                              ? swatch.swatchName
                              : swatch.yarnName;
                          return ListTile(
                            title: Text(
                              name.isNotEmpty
                                  ? name
                                  : (isKorean ? '이름 없음' : 'Untitled'),
                              style: T.body,
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await runWithMoriLoadingDialog<void>(
                                context,
                                message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                                subtitle: isKorean
                                    ? '잠시만 기다려 주세요.'
                                    : 'Please wait.',
                                task: () => ref
                                    .read(swatchRepositoryProvider)
                                    .updateSwatch(
                                      swatch.copyWith(projectId: widget.project.id),
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

  void _addSwatch(BuildContext context, WidgetRef ref, bool isKorean) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SwatchInputScreen(
          initialSwatch: SwatchModel.empty(uid: ref.read(authStateProvider).valueOrNull?.uid ?? '')
              .copyWith(projectId: widget.project.id),
        ),
      ),
    );
  }

  void _linkExistingCounter(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final allCounters = cRef.watch(counterListProvider).valueOrNull ?? [];
          final availableCounters =
              allCounters.where((c) => c.projectId != widget.project.id).toList();
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
                        color: C.bd2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      isKorean ? '내 작업에서 연결' : 'Link from My Counters',
                      style: T.h3,
                    ),
                  ),
                  if (availableCounters.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          isKorean
                              ? '연결할 수 있는 카운터가 없어요.'
                              : 'No available counters to link.',
                          style: T.body.copyWith(color: C.mu),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: availableCounters.length,
                        itemBuilder: (_, i) {
                          final counter = availableCounters[i];
                          return ListTile(
                            leading: Icon(Icons.tune_rounded, color: C.lv),
                            title: Text(counter.name, style: T.body),
                            subtitle: Text(
                              'S ${counter.stitchCount}  R ${counter.rowCount}',
                              style: T.caption.copyWith(color: C.mu),
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await runWithMoriLoadingDialog<void>(
                                context,
                                message: isKorean ? '연결하는 중입니다.' : 'Linking...',
                                subtitle: isKorean
                                    ? '잠시만 기다려 주세요.'
                                    : 'Please wait a moment.',
                                task: () async {
                                  await ref
                                      .read(counterRepositoryProvider)
                                      .updateCounter(
                                        counter.copyWith(projectId: widget.project.id),
                                      );
                                  await ref
                                      .read(projectRepositoryProvider)
                                      .addCounter(widget.project.id, counter.id);
                                },
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

  void _addCounter(BuildContext context, WidgetRef ref) {
    final t = ref.read(appStringsProvider);
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.createCounter, style: T.h3),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: t.counterNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(authStateProvider).valueOrNull;
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (user == null || name.isEmpty) return;
              final counter = CounterModel.empty(uid: user.uid, name: name).copyWith(projectId: widget.project.id);
              late final CounterModel saved;
              await runWithMoriLoadingDialog<void>(
                context,
                message: t.creatingCounter,
                subtitle: t.pleaseWaitMoment,
                task: () async {
                  saved = await ref.read(counterRepositoryProvider).createCounter(counter);
                  await ref.read(projectRepositoryProvider).addCounter(widget.project.id, saved.id);
                },
              );
              if (context.mounted) {
                showSavedSnackBar(
                  ScaffoldMessenger.of(context),
                  message: isKorean ? '카운터가 생성됐어요.' : 'Counter created.',
                );
              }
            },
            child: Text(t.create),
          ),
        ],
      ),
    );
  }
}

class _StepsSection extends ConsumerWidget {
  final ProjectModel project;
  final bool isCardEditMode;
  final GlobalKey? lastAnchorKey;
  final VoidCallback? onScrollToLastStep;
  const _StepsSection({required this.project, this.isCardEditMode = false, this.lastAnchorKey, this.onScrollToLastStep});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(projectStepsProvider(project.id));

    final currentSteps = stepsAsync.valueOrNull ?? [];
    final isKoreanHeader = ref.watch(appLanguageProvider).isKorean;

    return GlassCard(
      color: C.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered_rounded, color: C.lmD, size: 18),
              const SizedBox(width: 6),
              Text(
                isKoreanHeader ? '템플릿' : 'Template',
                style: T.bodyBold,
              ),
              const Spacer(),
              if (!isCardEditMode && currentSteps.isNotEmpty) ...[
                if (onScrollToLastStep != null)
                  GestureDetector(
                    onTap: onScrollToLastStep,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isKoreanHeader ? '마지막 단계로' : 'Last step',
                          style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_downward_rounded, size: 14, color: C.lv),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _saveAsMyTemplate(context, ref, currentSteps, isKoreanHeader),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_add_outlined, size: 14, color: C.pk),
                      const SizedBox(width: 2),
                      Text(
                        isKoreanHeader ? '내 템플릿 저장' : 'Save as template',
                        style: T.caption.copyWith(color: C.pk, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              if (isCardEditMode && currentSteps.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.link_off, color: C.og, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: isKoreanHeader ? '템플릿 연결 해제' : 'Unlink template',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(isKoreanHeader ? '템플릿 연결 해제' : 'Unlink Template', style: T.h3),
                        content: Text(
                          isKoreanHeader
                              ? '모든 단계(${currentSteps.length}개)가 삭제됩니다. 계속할까요?'
                              : 'All ${currentSteps.length} steps will be deleted. Continue?',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKoreanHeader ? '취소' : 'Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(isKoreanHeader ? '삭제' : 'Delete', style: TextStyle(color: C.og)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    if (!context.mounted) return;
                    await runWithMoriLoadingDialog<void>(
                      context,
                      message: isKoreanHeader ? '단계를 삭제하는 중입니다.' : 'Deleting steps...',
                      subtitle: isKoreanHeader ? '잠시만 기다려 주세요.' : 'Please wait.',
                      task: () async {
                        final stepRepo = ref.read(projectStepRepositoryProvider);
                        for (final step in currentSteps) {
                          await stepRepo.deleteStep(project.id, step.id);
                        }
                      },
                    );
                    if (context.mounted) {
                      showSavedSnackBar(
                        ScaffoldMessenger.of(context),
                        message: isKoreanHeader ? '모든 단계가 삭제됐어요.' : 'All steps deleted.',
                      );
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          stepsAsync.when(
            data: (steps) {
              if (steps.isEmpty) {
                final isKorean = ref.read(appLanguageProvider).isKorean;
                return Column(
                  children: [
                    Center(
                      child: Text(
                        isKorean ? '연결된 단계로그 없어요.' : 'No linked steps.',
                        style: T.body.copyWith(color: C.mu),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CardEditActions(
                      isKorean: isKorean,
                      onLinkFromWork: () => _showTemplateSheet(context, ref),
                      onCreateNew: () => _addStep(context, ref),
                    ),
                  ],
                );
              }
              final completedCount = steps.where((s) => s.isDone).length;
              final totalCount = steps.length;
              final progressValue = totalCount > 0 ? completedCount / totalCount : 0.0;
              final isKorean = ref.watch(appLanguageProvider).isKorean;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 6,
                      backgroundColor: C.lv.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(C.lv),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isKorean
                        ? '$completedCount/$totalCount 완료 (${(progressValue * 100).toStringAsFixed(0)}%)'
                        : '$completedCount/$totalCount done (${(progressValue * 100).toStringAsFixed(0)}%)',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                  const SizedBox(height: 8),
                  ...steps.asMap().entries.map((entry) {
                        final i = entry.key;
                        final step = entry.value;
                        return _StepTile(
                          step: step,
                          projectId: project.id,
                          index: i,
                          isCardEditMode: isCardEditMode,
                          onToggle: () => ref.read(projectStepRepositoryProvider).toggleStep(project.id, step),
                          onEdit: () => _editStep(context, ref, step),
                          onDelete: () => _deleteStep(context, ref, step),
                          onMoveUp: i > 0 ? () => _reorderSteps(context, ref, steps, i, i - 1) : null,
                          onMoveDown: i < steps.length - 1 ? () => _reorderSteps(context, ref, steps, i, i + 1) : null,
                          onInsertAfter: isCardEditMode ? () => _insertStepAfter(context, ref, steps, i) : null,
                        );
                      }),
                  // 마지막 단계 스크롤 앵커
                  SizedBox(key: lastAnchorKey, height: 0),
                ],
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
            error: (e, _) {
              final isKorean = ref.read(appLanguageProvider).isKorean;
              return Column(
                children: [
                  Center(
                    child: Text(
                      isKorean ? '단계를 불러오지 못했어요.' : 'Failed to load steps.',
                      style: T.body.copyWith(color: C.mu),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CardEditActions(
                    isKorean: isKorean,
                    onLinkFromWork: () => _showTemplateSheet(context, ref),
                    onCreateNew: () => _addStep(context, ref),
                  ),
                ],
              );
            },
          ),
          if (isCardEditMode) ...[
            const SizedBox(height: 10),
            _CardEditActions(
              isKorean: ref.read(appLanguageProvider).isKorean,
              onLinkFromWork: () => _showTemplateSheet(context, ref),
              onCreateNew: () => _addStep(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveAsMyTemplate(BuildContext context, WidgetRef ref, List<ProjectStep> steps, bool isKorean) async {
    final ctrl = TextEditingController(text: project.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '내 템플릿으로 저장' : 'Save as My Template', style: T.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isKorean ? '템플릿 이름' : 'Template name',
            hintText: project.title,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? project.title : ctrl.text.trim()),
            child: Text(isKorean ? '저장' : 'Save', style: TextStyle(color: C.lv, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || !context.mounted) return;

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(templateRepositoryProvider).create(
          title: name,
          description: '',
          stepTitles: steps.map((s) => s.name).toList(),
          stepDescs: steps.map((s) => s.description).toList(),
        ),
      );
      if (!context.mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '내 템플릿에 저장됐어요.' : 'Saved to My Templates.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _showTemplateSheet(BuildContext context, WidgetRef ref) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final builtins = [
      ('topdown', isKorean ? '탑다운 스웨터' : 'Top-down Sweater', Icons.dry_cleaning_rounded),
      ('socks', isKorean ? '양말' : 'Socks', Icons.hiking_rounded),
      ('scarf', isKorean ? '목도리' : 'Scarf', Icons.ac_unit_rounded),
      ('gloves', isKorean ? '장갑' : 'Gloves', Icons.back_hand_rounded),
      ('hat', isKorean ? '모자' : 'Hat', Icons.face_rounded),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final customTemplates = cRef.watch(userTemplateListProvider).valueOrNull ?? [];
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const SizedBox(height: 8),
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),
                  Text(isKorean ? '템플릿 선택' : 'Select Template', style: T.h3),
                  const SizedBox(height: 12),
                  // 커스텀 템플릿 (먼저)
                  if (customTemplates.isNotEmpty) ...[
                    Text(isKorean ? '나의 커스텀 템플릿' : 'My Custom Templates', style: T.caption.copyWith(color: C.mu)),
                    const SizedBox(height: 6),
                    ...customTemplates.map((tmpl) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.folder_special_rounded, color: C.lvD, size: 20),
                      ),
                      title: Text(tmpl.title, style: T.body),
                      subtitle: Text(
                        isKorean ? '${tmpl.stepTitles.length}개 단계' : '${tmpl.stepTitles.length} steps',
                        style: T.caption.copyWith(color: C.mu),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        runWithMoriLoadingDialog<void>(
                          context,
                          message: isKorean ? '단계 추가 중...' : 'Adding steps...',
                          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                          task: () async {
                            final stepRepo = ref.read(projectStepRepositoryProvider);
                            for (int i = 0; i < tmpl.stepTitles.length; i++) {
                              await stepRepo.addStep(
                                project.id,
                                tmpl.stepTitles[i],
                                i,
                                description: i < tmpl.stepDescs.length ? tmpl.stepDescs[i] : '',
                              );
                            }
                          },
                        );
                      },
                    )),
                    const SizedBox(height: 12),
                  ],
                  // 기본 템플릿
                  Text(isKorean ? '기본 템플릿' : 'Built-in', style: T.caption.copyWith(color: C.mu)),
                  const SizedBox(height: 6),
                  ...builtins.map((tpl) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(tpl.$3, color: C.lv, size: 20),
                    ),
                    title: Text(tpl.$2, style: T.body),
                    trailing: Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
                    onTap: () {
                      Navigator.pop(ctx);
                      runWithMoriLoadingDialog<void>(
                        context,
                        message: isKorean ? '단계 추가 중...' : 'Adding steps...',
                        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                        task: () => ref.read(projectStepRepositoryProvider).addTemplateSteps(project.id, tpl.$1),
                      );
                    },
                  )),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reorderSteps(BuildContext context, WidgetRef ref, List<ProjectStep> steps, int fromIndex, int toIndex) async {
    final stepA = steps[fromIndex];
    final stepB = steps[toIndex];
    await ref.read(projectStepRepositoryProvider).swapStepOrders(
      project.id,
      stepA.id, stepB.order,
      stepB.id, stepA.order,
    );
  }

  void _addStep(BuildContext context, WidgetRef ref) {
    _showStepDialog(context, ref);
  }

  void _insertStepAfter(BuildContext context, WidgetRef ref, List<ProjectStep> steps, int afterIndex) {
    _showStepDialog(context, ref, insertAfterIndex: afterIndex, allSteps: steps);
  }

  void _editStep(BuildContext context, WidgetRef ref, ProjectStep step) {
    _showStepDialog(context, ref, existingStep: step);
  }

  void _deleteStep(BuildContext context, WidgetRef ref, ProjectStep step) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '단계 삭제' : 'Delete Step', style: T.h3),
        content: Text(
          isKorean ? '"${step.name}" 단계를 삭제할까요?' : 'Delete step "${step.name}"?',
          style: T.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await runWithMoriLoadingDialog<void>(
                  context,
                  message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
                  subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                  task: () => ref.read(projectStepRepositoryProvider).deleteStep(project.id, step.id),
                );
                if (context.mounted) {
                  showSavedSnackBar(
                    ScaffoldMessenger.of(context),
                    message: isKorean ? '삭제됐어요.' : 'Deleted.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                }
              }
            },
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
  }

  void _showStepDialog(BuildContext context, WidgetRef ref, {ProjectStep? existingStep, int? insertAfterIndex, List<ProjectStep>? allSteps}) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final t = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController(text: existingStep?.name ?? '');
    final descCtrl = TextEditingController(text: existingStep?.description ?? '');
    final noteCtrl = TextEditingController(text: existingStep?.note ?? '');
    final targetRowCtrl = TextEditingController(
      text: (existingStep?.targetRow ?? 0) > 0 ? '${existingStep!.targetRow}' : '',
    );
    var selectedBlockType = existingStep?.blockType ?? StepBlockType.text;
    final isEdit = existingStep != null;
    XFile? pickedImageFile;
    String? existingPhotoUrl = existingStep?.photoUrl;

    final blockTypeLabels = <StepBlockType, String>{
      StepBlockType.text: isKorean ? '텍스트' : 'Text',
      StepBlockType.stitchCount: isKorean ? '코수' : 'Stitches',
      StepBlockType.patternLink: isKorean ? '도안' : 'Pattern',
    };

    Future<XFile?> pickImageForDialog(BuildContext dialogCtx) async {
      // dialogCtx 사용: 다이얼로그 위에 바텀시트가 표시되도록
      final source = await showModalBottomSheet<ImageSource>(
        context: dialogCtx,
        backgroundColor: C.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: C.lv),
                title: Text(isKorean ? '갤러리에서 선택' : 'Choose from Gallery', style: T.body),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: C.lv),
                title: Text(isKorean ? '즉시 촬영' : 'Take a Photo', style: T.body),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (source == null) return null;
      // 바텀시트 닫힘 후 딜레이 (카메라 프리즈 방지)
      await Future.delayed(const Duration(milliseconds: 350));
      return ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEdit ? (isKorean ? '단계 수정' : 'Edit Step') : t.addStep, style: T.h3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: isKorean ? '단계 이름' : 'Step name', hintText: t.stepNameHint),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: isKorean ? '소제목 (선택)' : 'Subtitle (optional)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetRowCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isKorean ? '목표단 (선택)' : 'Target rows (optional)',
                    hintText: '0',
                    suffixText: isKorean ? '단' : 'rows',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isKorean ? '메모 (선택)' : 'Note (optional)',
                    hintText: isKorean ? '예: 전체 콧수 120코, 래글런 마커 4개' : 'e.g. Cast on 120 sts',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(isKorean ? '유형' : 'Type', style: TextStyle(fontSize: 12, color: C.mu, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: StepBlockType.values.map((type) {
                    final isSelected = selectedBlockType == type;
                    return GestureDetector(
                      onTap: () => setState(() => selectedBlockType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? C.lv : C.lvL,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
                        ),
                        child: Text(
                          blockTypeLabels[type]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : C.lvD,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(isKorean ? '사진 (선택)' : 'Photo (optional)', style: TextStyle(fontSize: 12, color: C.mu, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final file = await pickImageForDialog(ctx);
                    if (file != null) setState(() { pickedImageFile = file; existingPhotoUrl = null; });
                  },
                  child: pickedImageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(pickedImageFile!.path), width: double.infinity, height: 100, fit: BoxFit.cover),
                        )
                      : existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(existingPhotoUrl!, width: double.infinity, height: 100, fit: BoxFit.cover),
                            )
                          : Container(
                              width: double.infinity,
                              height: 72,
                              decoration: BoxDecoration(
                                color: C.gx,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: C.bd2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, color: C.mu, size: 24),
                                  const SizedBox(height: 4),
                                  Text(isKorean ? '사진 추가' : 'Add photo', style: T.caption.copyWith(color: C.mu)),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final desc = descCtrl.text.trim();
                final note = noteCtrl.text.trim();
                final targetRow = int.tryParse(targetRowCtrl.text.trim()) ?? 0;
                final blockType = selectedBlockType;
                Navigator.pop(ctx);
                if (name.isEmpty) return;
                Future.microtask(() async {
                  if (!context.mounted) return;
                  if (isEdit) {
                    try {
                      await runWithMoriLoadingDialog<void>(
                        context,
                        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                        task: () async {
                          await ref.read(projectStepRepositoryProvider).updateStep(
                            project.id,
                            existingStep.id,
                            name: name,
                            description: desc,
                            note: note,
                            targetRow: targetRow,
                            blockType: blockType,
                          );
                          if (pickedImageFile != null) {
                            final storageRef = FirebaseStorage.instance
                                .ref()
                                .child('projects/${project.id}/steps/${existingStep.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                            await storageRef.putFile(File(pickedImageFile!.path));
                            final url = await storageRef.getDownloadURL();
                            await ref.read(projectStepRepositoryProvider).updateStepPhoto(project.id, existingStep.id, url);
                          }
                        },
                      );
                      if (context.mounted) {
                        showSavedSnackBar(
                          ScaffoldMessenger.of(context),
                          message: isKorean ? '저장됐어요.' : 'Saved.',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                      }
                    }
                  } else {
                    // insertAfterIndex가 있으면 해당 위치 이후에 삽입, 없으면 맨 끝에 추가
                    int order;
                    if (insertAfterIndex != null && allSteps != null && insertAfterIndex < allSteps.length) {
                      // 삽입 위치 이후의 단계 order를 +1씩 증가시키고, 새 단계를 사이에 삽입
                      final insertOrder = allSteps[insertAfterIndex].order + 1;
                      order = insertOrder;
                      // 이후 단계들의 order를 +1씩 증가
                      final stepRepo = ref.read(projectStepRepositoryProvider);
                      for (int k = insertAfterIndex + 1; k < allSteps.length; k++) {
                        await stepRepo.updateStepOrder(project.id, allSteps[k].id, allSteps[k].order + 1);
                      }
                    } else {
                      final stepsAsync = ref.read(projectStepsProvider(project.id));
                      order = stepsAsync.valueOrNull?.length ?? 0;
                    }
                    if (!context.mounted) return;
                    await runWithMoriLoadingDialog<void>(
                      context,
                      message: t.addingStep,
                      subtitle: t.pleaseWaitMoment,
                      task: () async {
                        String? uploadedPhotoUrl;
                        if (pickedImageFile != null) {
                          final tempId = DateTime.now().millisecondsSinceEpoch;
                          final storageRef = FirebaseStorage.instance
                              .ref()
                              .child('projects/${project.id}/steps/new_$tempId.jpg');
                          await storageRef.putFile(File(pickedImageFile!.path));
                          uploadedPhotoUrl = await storageRef.getDownloadURL();
                        }
                        await ref.read(projectStepRepositoryProvider).addStep(
                          project.id,
                          name,
                          order,
                          description: desc,
                          note: note,
                          targetRow: targetRow,
                          blockType: blockType,
                          photoUrl: uploadedPhotoUrl,
                        );
                      },
                    );
                    // 템플릿 업데이트 팝업
                    if (context.mounted) {
                      final customTemplates = ref.read(userTemplateListProvider).valueOrNull ?? [];
                      if (customTemplates.isNotEmpty) {
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(isKorean ? '템플릿도 업데이트할까요?' : 'Update template too?', style: T.h3),
                            content: Text(
                              isKorean
                                  ? '연결된 커스텀 템플릿에 이 단계를 추가할 수 있어요.'
                                  : 'You can add this step to a linked custom template.',
                              style: T.body,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(isKorean ? '건너뛰기' : 'Skip'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showTemplateUpdateSheet(context, ref, name, desc);
                                },
                                child: Text(isKorean ? '업데이트' : 'Update'),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  }
                });
              },
              child: Text(isEdit ? (isKorean ? '저장' : 'Save') : t.add),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateUpdateSheet(BuildContext context, WidgetRef ref, String stepName, String stepDesc) {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final customTemplates = ref.read(userTemplateListProvider).valueOrNull ?? [];
    if (customTemplates.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(isKorean ? '업데이트할 템플릿 선택' : 'Select template to update', style: T.h3),
              const SizedBox(height: 12),
              ...customTemplates.map((tmpl) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.folder_special_rounded, color: C.lvD, size: 18),
                ),
                title: Text(tmpl.title, style: T.body),
                subtitle: Text(
                  isKorean ? '${tmpl.stepTitles.length}개 단계' : '${tmpl.stepTitles.length} steps',
                  style: T.caption.copyWith(color: C.mu),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await runWithMoriLoadingDialog<void>(
                      context,
                      message: isKorean ? '템플릿 업데이트 중...' : 'Updating template...',
                      subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                      task: () => ref.read(templateRepositoryProvider).addStepToTemplate(tmpl.id, stepName, stepDesc),
                    );
                    if (context.mounted) {
                      showSavedSnackBar(
                        ScaffoldMessenger.of(context),
                        message: isKorean ? '템플릿이 업데이트됐어요.' : 'Template updated.',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                    }
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends ConsumerStatefulWidget {
  final ProjectStep step;
  final String projectId;
  final int index;
  final bool isCardEditMode;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onInsertAfter;
  const _StepTile({
    required this.step,
    required this.projectId,
    required this.index,
    this.isCardEditMode = false,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.onInsertAfter,
  });

  @override
  ConsumerState<_StepTile> createState() => _StepTileState();
}

class _StepTileState extends ConsumerState<_StepTile> {
  bool _uploading = false;
  bool _expanded = false;

  Future<ImageSource?> _showImageSourceDialog() {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(isKorean ? '갤러리에서 선택' : 'Choose from Gallery', style: T.body),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: C.lv),
              title: Text(isKorean ? '즉시 촬영' : 'Take a Photo', style: T.body),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;

      // 바텀시트 닫힘 애니메이션 완료 후 카메라 실행 (즉시 실행 시 프리즈 방지)
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploading = true);

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('projects/${widget.projectId}/steps/${widget.step.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(File(picked.path));
        final url = await storageRef.getDownloadURL();
        await ref.read(projectStepRepositoryProvider).updateStepPhoto(
          widget.projectId,
          widget.step.id,
          url,
        );
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isKorean
                  ? '단계 사진 업로드에 실패했어요: $error'
                  : 'Failed to upload the step photo: $error',
            ),
            backgroundColor: C.og,
          ),
        );
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isKorean
                ? '카메라를 여는 중 오류가 발생했어요. 다시 시도해주세요.'
                : 'Something went wrong while opening the camera. Please try again.',
          ),
          backgroundColor: C.og,
        ),
      );
      debugPrint('Step photo pick failed: $error');
    }
  }

  void _showPhotoViewer(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final hasPhoto = step.photoUrl != null && step.photoUrl!.isNotEmpty;
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final hasDetails = step.description.isNotEmpty || step.note.isNotEmpty ||
        step.targetRow > 0 || hasPhoto || widget.isCardEditMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 기본 행 (항상 표시) ───────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 체크박스
              GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: step.isDone ? C.lv : Colors.transparent,
                    border: Border.all(color: step.isDone ? C.lv : C.bd, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: step.isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 6),
              // 번호 배지
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: step.isDone ? C.lv.withValues(alpha: 0.15) : C.lv.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: step.isDone ? C.lv.withValues(alpha: 0.5) : C.lv),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 이름 (탭 → 확장)
              Expanded(
                child: GestureDetector(
                  onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
                  child: Text(
                    step.name,
                    style: T.body.copyWith(
                      color: step.isDone ? C.mu : C.tx,
                      decoration: step.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ),
              // 사진 미리보기 (접힌 상태에서)
              if (hasPhoto && !_expanded) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showPhotoViewer(context, step.photoUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(step.photoUrl!, width: 28, height: 28, fit: BoxFit.cover),
                  ),
                ),
              ],
              // 확장 화살표
              if (hasDetails)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: C.mu,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── 확장 패널 ────────────────────────────────────
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 58, bottom: 8, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 소제목
                if (step.description.isNotEmpty)
                  Text(step.description, style: T.captionBold.copyWith(color: C.lv)),
                // 메모
                if (step.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(step.note, style: T.caption.copyWith(color: C.mu)),
                  ),
                // 목표단
                if (step.targetRow > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: C.lmD.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('목표: ${step.targetRow}단',
                          style: T.caption.copyWith(color: C.lmD, fontSize: 11)),
                    ),
                  ),
                // 완료일
                if (step.isDone && step.doneAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('완료: ${step.doneAt!.month}/${step.doneAt!.day}',
                        style: T.caption.copyWith(color: C.mu)),
                  ),

                // 사진 영역 (항상 접근 가능)
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _uploading ? null : (hasPhoto ? () => _showPhotoViewer(context, step.photoUrl!) : _pickPhoto),
                  child: _uploading
                      ? Container(
                          height: 48,
                          decoration: BoxDecoration(color: C.gx, borderRadius: BorderRadius.circular(10)),
                          child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                        )
                      : hasPhoto
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(step.photoUrl!, width: double.infinity,
                                      height: 110, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 6, right: 6,
                                  child: GestureDetector(
                                    onTap: _pickPhoto,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(6)),
                                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              width: double.infinity, height: 44,
                              decoration: BoxDecoration(
                                color: C.lv.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: C.lv.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 16, color: C.lv),
                                  const SizedBox(width: 6),
                                  Text(isKorean ? '사진 추가' : 'Add photo',
                                      style: T.caption.copyWith(color: C.lv)),
                                ],
                              ),
                            ),
                ),

                // 수정/삭제/순서변경 (수정모드에서만)
                if (widget.isCardEditMode) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: Icon(Icons.edit_outlined, size: 13, color: C.lvD),
                        label: Text(isKorean ? '수정' : 'Edit',
                            style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: Icon(Icons.delete_outline_rounded, size: 13, color: C.og),
                        label: Text(isKorean ? '삭제' : 'Delete',
                            style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                      const Spacer(),
                      if (widget.onMoveUp != null)
                        IconButton(
                          onPressed: widget.onMoveUp,
                          icon: Icon(Icons.arrow_upward_rounded, size: 15, color: C.mu),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: isKorean ? '위로' : 'Move up',
                        ),
                      if (widget.onMoveDown != null)
                        IconButton(
                          onPressed: widget.onMoveDown,
                          icon: Icon(Icons.arrow_downward_rounded, size: 15, color: C.mu),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: isKorean ? '아래로' : 'Move down',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

        // ── 단계 삽입 버튼 (수정모드에서만) ───────────────
        if (widget.isCardEditMode && widget.onInsertAfter != null)
          GestureDetector(
            onTap: widget.onInsertAfter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              height: 28,
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.lv.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: C.lvD),
                  const SizedBox(width: 4),
                  Text(isKorean ? '여기에 단계 삽입' : 'Insert step here',
                      style: T.caption.copyWith(color: C.lvD, fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: T.captionBold.copyWith(color: C.mu))),
          Expanded(child: Text(value, style: T.body)),
        ],
      ),
    );
  }
}

class _CounterTile extends StatelessWidget {
  final CounterModel counter;
  final VoidCallback? onTap;
  final VoidCallback? onUnlink;

  const _CounterTile({required this.counter, this.onTap, this.onUnlink});

  @override
  Widget build(BuildContext context) {
    final hasRowTarget = counter.targetRowCount > 0;
    final hasStitchTarget = counter.targetStitchCount > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(counter.name, style: T.bodyBold)),
                if (onUnlink != null)
                  IconButton(
                    icon: Icon(Icons.link_off, color: C.og, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '연결 해제',
                    onPressed: onUnlink,
                  )
                else ...[
                  Text('S ${counter.stitchCount}  R ${counter.rowCount}', style: T.caption.copyWith(color: C.mu)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: C.mu),
                ],
              ],
            ),
            if (hasRowTarget) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.unfold_more_rounded, color: C.pk, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: counter.rowProgress,
                        minHeight: 5,
                        backgroundColor: C.pk.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(C.pk),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${counter.rowCount}/${counter.targetRowCount}단',
                    style: T.caption.copyWith(color: C.pk),
                  ),
                ],
              ),
            ],
            if (hasStitchTarget) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.more_horiz_rounded, color: C.lv, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: counter.stitchProgress,
                        minHeight: 5,
                        backgroundColor: C.lv.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(C.lv),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${counter.stitchCount}/${counter.targetStitchCount}코',
                    style: T.caption.copyWith(color: C.lv),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectPhotosSection extends ConsumerStatefulWidget {
  final ProjectModel project;
  final bool isCardEditMode;
  const _ProjectPhotosSection({required this.project, this.isCardEditMode = false});

  @override
  ConsumerState<_ProjectPhotosSection> createState() => _ProjectPhotosSectionState();
}

class _ProjectPhotosSectionState extends ConsumerState<_ProjectPhotosSection> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    if (widget.project.photoUrls.length >= 4) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects/${widget.project.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      final updatedUrls = [...widget.project.photoUrls, url];
      await ref.read(projectRepositoryProvider).updateProject(
        widget.project.copyWith(photoUrls: updatedUrls),
      );
    } catch (e) {
      if (mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto(String url) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '사진 삭제' : 'Delete Photo', style: T.h3),
        content: Text(isKorean ? '이 사진을 삭제할까요?' : 'Delete this photo?', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
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
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final updatedUrls = widget.project.photoUrls.where((u) => u != url).toList();
          await ref.read(projectRepositoryProvider).updateProject(
            widget.project.copyWith(photoUrls: updatedUrls),
          );
        },
      );
      if (mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '삭제됐어요.' : 'Deleted.');
    } catch (e) {
      if (mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _viewPhoto(String url, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenImageViewer(imageUrl: url, heroTag: heroTag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final photos = widget.project.photoUrls;
    final canAdd = photos.length < 4;

    return Container(
      decoration: BoxDecoration(
        color: C.pk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.pk.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: C.pk, size: 18),
              const SizedBox(width: 6),
              Text(isKorean ? '📸 착용샷 / 사용샷' : '📸 Wearing / Usage', style: T.bodyBold.copyWith(color: C.pkD)),
              const Spacer(),
              if (canAdd && widget.isCardEditMode)
                GestureDetector(
                  onTap: _isUploading ? null : _pickAndUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.pk,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, color: Colors.white, size: 14),
                              const SizedBox(width: 2),
                              Text(isKorean ? '사진 추가' : 'Add', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: C.pk.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.pk.withValues(alpha: 0.15)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: C.pk.withValues(alpha: 0.5), size: 32),
                    const SizedBox(height: 4),
                    Text(
                      isKorean ? '사진을 추가해보세요 (최대 4장)' : 'Add photos (max 4)',
                      style: T.caption.copyWith(color: C.pk.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: photos.map((url) {
                final heroTag = 'project_photo_${widget.project.id}_${url.hashCode}';
                return GestureDetector(
                  onTap: () => _viewPhoto(url, heroTag),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: heroTag,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: C.bd,
                              child: Icon(Icons.broken_image, color: C.mu),
                            ),
                          ),
                        ),
                      ),
                      if (widget.isCardEditMode)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _deletePhoto(url),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${photos.length}/4',
                style: T.caption.copyWith(color: C.pk.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageViewer({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Hero(
                tag: heroTag,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialThumbnail extends StatelessWidget {
  final String photoUrl;
  final IconData defaultIcon;
  final Color iconColor;

  const _MaterialThumbnail({
    required this.photoUrl,
    required this.defaultIcon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(10),
        image: photoUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: photoUrl.isEmpty
          ? Icon(defaultIcon, color: iconColor, size: 22)
          : null,
    );
  }
}

// ── 카드 수정모드 액션 버튼 (내작업에서 연결 / 새로만들기) ──────────────
class _CardEditActions extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onLinkFromWork;
  final VoidCallback? onCreateNew;

  const _CardEditActions({
    required this.isKorean,
    required this.onLinkFromWork,
    this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onLinkFromWork,
            icon: const Icon(Icons.link_rounded, size: 16),
            label: Text(isKorean ? '내작업에서 연결' : 'Link from work', style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              foregroundColor: C.lv,
              side: BorderSide(color: C.lv.withValues(alpha: 0.4)),
            ),
          ),
        ),
        if (onCreateNew != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCreateNew,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(isKorean ? '새로만들기' : 'Create new', style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                foregroundColor: C.lvD,
                side: BorderSide(color: C.lvD.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
