import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../pattern/data/pattern_session_repository.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../pattern/presentation/pattern_detail_screen.dart';
import '../../blueprint/presentation/step_log_view.dart';
import 'widgets/project_progress_section.dart';
import 'widgets/project_share_card.dart';
import 'widgets/project_time_summary_card.dart';
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

    // 이슈 #629 (B-3) — 갤러리 공개 게이트: 단계로그 0개면 차단
    if (!alreadyPublished) {
      final stepsList = ref.read(projectStepsProvider(project.id)).valueOrNull ?? [];
      if (stepsList.isEmpty) {
        showSaveErrorSnackBar(
          messenger,
          message: isKorean
              ? '단계로그가 있어야 갤러리에 공개할 수 있어요. 단계를 먼저 추가해 주세요.'
              : 'Project needs step logs to publish. Add steps first.',
        );
        return;
      }
    }

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
                      // 이슈 #629 (B-3) — 마켓 등록 게이트: 단계로그 0개면 차단
                      final stepsList = ref.read(projectStepsProvider(project.id)).valueOrNull ?? [];
                      if (stepsList.isEmpty) {
                        showSaveErrorSnackBar(
                          ScaffoldMessenger.of(ctx),
                          message: isKorean
                              ? '단계로그가 있어야 마켓에 등록할 수 있어요.'
                              : 'Project needs step logs to submit to market.',
                        );
                        return;
                      }
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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '프로젝트' : 'Project',
                subtitle: isKorean ? '프로젝트 상세' : 'Project details',
                trailing: _isEditing
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
            ),
            Expanded(
              child: projectAsync.when(
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
            ),
          ],
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

  Future<void> _pickAndUpdateCover(BuildContext context, WidgetRef ref, ProjectModel project) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    ImageSource? source;
    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
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
    }
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
                        // 이슈 #696 — MaterialPageRoute에 유일한 settings.name 부여하여
                        // restoration scope key 충돌(_debugCheckDuplicatedPageKeys) 회피.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: RouteSettings(
                              name: 'pattern-detail/${chart.id}-${DateTime.now().millisecondsSinceEpoch}',
                            ),
                            builder: (_) => PatternDetailScreen(chart: chart),
                          ),
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
            // 이슈 #630 — 작업 시간 집계 카드 (편집 모드 아닐 때만)
            if (!isEditing) ...[
              ProjectTimeSummaryCard(
                projectId: project.id,
                swatchIds: {
                  if (project.swatchId.isNotEmpty) project.swatchId,
                  for (final s in linkedSwatches)
                    if (s.id.isNotEmpty) s.id,
                }.toList(),
                isKorean: isKorean,
              ),
              const SizedBox(height: 10),
              // 이슈 #649 Phase 3 — 평균 일일 작업시간
              _ProjectAvgDailyCard(project: project, isKorean: isKorean),
              const SizedBox(height: 10),
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

                    // 이슈 #696 — sourcePatternId가 있는데 patternListProvider 로딩 중인 경우
                    // 잘못된 "연결된 도안 없어요" 깜빡임 방지: 로딩 인디케이터 표시.
                    if (linked == null && project.sourcePatternId.isNotEmpty && patternsAsync.isLoading) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(color: C.lv, strokeWidth: 2)),
                      );
                    }
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
                        // 이슈 #696 — Navigator GlobalKey 크래시 fix.
                        // settings.name을 유일하게 부여하여 restoration scope key 충돌 방지.
                        // (PatternDetailScreen이 짧은 시간에 여러 번 push되어도 안전.)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: RouteSettings(
                              name: 'pattern-detail/${linked.id}-${DateTime.now().millisecondsSinceEpoch}',
                            ),
                            builder: (_) => PatternDetailScreen(chart: linked),
                          ),
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
            // 이슈 #687 (Phase E2) — 옛 _StepsSection 삭제 완료. StepLogView 통일 view만 표시.
            // project.id == StepRun.id 정책으로 멱등성 보장 (Phase D 마이그레이션).
            if (project.sourcePatternId.isNotEmpty) ...[
              const SizedBox(height: 12),
              GlassCard(
                color: C.bg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded, color: C.lmD, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          isKorean ? '단계로그' : 'Step Log',
                          style: T.bodyBold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      key: _stepsAnchorKey,
                      height: 400,
                      child: StepLogView(
                        blueprintId: project.sourcePatternId,
                        runId: project.id,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            // 이슈 #644 — Ravelry 프로젝트 링크 (ravelryProjectId 있을 때)
            if (project.ravelryProjectId != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                onTap: () async {
                  final url = 'https://www.ravelry.com/projects/-/${project.ravelryProjectId}';
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: C.lv.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.link_rounded, color: C.lvD, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isKorean ? 'Ravelry에서 보기' : 'View on Ravelry', style: T.bodyBold),
                          const SizedBox(height: 2),
                          Text(
                            'Project #${project.ravelryProjectId}',
                            style: T.caption.copyWith(color: C.mu),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded, color: C.mu, size: 18),
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
    final ImageSource? source;
    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
      source = await showModalBottomSheet<ImageSource>(
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
    }
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

/// 이슈 #649 Phase 3 — 프로젝트 평균 일일 작업시간 카드.
/// (도안세션 totalSeconds + 스와치타이머 totalSeconds) / 진행일수.
/// 진행일수 = max(1, today - (startDate ?? createdAt))
class _ProjectAvgDailyCard extends ConsumerWidget {
  final ProjectModel project;
  final bool isKorean;
  const _ProjectAvgDailyCard({required this.project, required this.isKorean});

  String _formatHms(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${seconds}s';
  }

  int _daysSpan(DateTime? start) {
    if (start == null) return 1;
    final diff = DateTime.now().difference(start).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aggAsync = ref.watch(patternTimeByProjectProvider);
    return GlassCard(
      child: aggAsync.when(
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => SizedBox(
          height: 56,
          child: Center(
            child: Text(
              isKorean ? '평균시간 불러오기 실패' : 'Failed to load average',
              style: T.caption.copyWith(color: C.og),
            ),
          ),
        ),
        data: (aggMap) {
          final agg = aggMap[project.id];
          final total = agg?.totalSeconds ?? 0;
          final start = project.startDate ?? project.createdAt;
          final days = _daysSpan(start);
          final avg = total ~/ days;
          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: C.pkD.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.trending_up_rounded, color: C.pkD, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKorean ? '평균 일일 작업' : 'Avg Daily',
                      style: T.caption
                          .copyWith(color: C.mu, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatHms(avg),
                      style: T.h3.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isKorean ? '진행 $days일' : '$days days',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isKorean ? '세션 ${agg?.sessionCount ?? 0}회' : '${agg?.sessionCount ?? 0} sessions',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
