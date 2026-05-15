import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/blueprint_provider.dart';
import '../../../providers/pattern_library_provider.dart';
import '../../../providers/project_provider.dart';

import '../../blueprint/domain/step_blueprint.dart';
import '../../pattern_library/domain/pattern_file.dart';
import 'widgets/chart_shape_picker.dart';
import '../../ravelry/data/ravelry_auth_provider.dart';
import '../../ravelry/data/ravelry_repository.dart';
import '../../ravelry/domain/ravelry_models.dart';
import '../../ravelry/presentation/ravelry_pattern_detail_screen.dart';
import '../data/pattern_export_service.dart';
import '../data/pattern_repository.dart';
import '../domain/pattern_chart.dart';
import 'pattern_detail_screen.dart';
import 'pattern_editor_screen.dart';

class PatternListScreen extends ConsumerStatefulWidget {
  const PatternListScreen({super.key});

  @override
  ConsumerState<PatternListScreen> createState() => _PatternListScreenState();
}

class _PatternListScreenState extends ConsumerState<PatternListScreen> {
  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    // 이슈 #687 (Phase I-B) — 신규 step_blueprints 컬렉션 우선 + legacy pattern_charts fallback.
    // myBlueprintsWithLegacyProvider 는 두 stream 을 합성해 단일 List<StepBlueprint> 로 노출.
    // 옛 pattern_charts 어댑터(메모리 전용)도 동일하게 표시되어 마이그레이션 안 한 데이터까지 보여줌.
    final blueprintsAsync = ref.watch(myBlueprintsWithLegacyProvider);
    // PatternChart 보존 — 카드 onTap 시 PatternDetailScreen 으로 전달하기 위해 유지.
    // (PatternDetailScreen 인자는 PatternChart 형식 그대로 둠 → 회귀 최소화.)
    final patternsAsync = ref.watch(patternListProvider);
    final filesAsync = ref.watch(patternFilesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '도안 에디터' : 'Pattern Editor',
                subtitle: isKorean ? '나만의 뜨개 도안을 만들어요' : 'Create your own knitting charts',
              ),
            ),
            // 도안 요약카드 틀고정
            Consumer(
              builder: (_, ref2, _) {
                // 도안 카운트는 신규 컬렉션 + legacy 합산 기반.
                final pc = blueprintsAsync.valueOrNull?.length ?? 0;
                final fc = filesAsync.valueOrNull?.length ?? 0;
                final total = pc + fc;
                final auth = ref2.watch(ravelryAuthProvider);
                final libraryAsync = auth.isLoggedIn ? ref2.watch(ravelryLibraryProvider) : null;
                final libCount = libraryAsync?.maybeWhen(data: (p) => '${p.length}', orElse: () => '-') ?? '-';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: LibrarySummaryCard(
                    headers: [isKorean ? '전체' : 'Total'],
                    rows: [
                      LibrarySummaryRowData(
                        badge: 'MoriKnit',
                        badgeColor: C.pkD,
                        values: [blueprintsAsync.isLoading ? '-' : '$total'],
                        valueColors: [C.tx],
                      ),
                      LibrarySummaryRowData(
                        badge: 'Ravelry',
                        badgeColor: auth.isLoggedIn ? C.lv : C.mu,
                        values: [libCount],
                        valueColors: [auth.isLoggedIn ? C.tx : C.mu],
                      ),
                    ],
                    // #628 — 도안 등록 단일 진입점: pattern_converter로 직행
                    // (기존 _showPatternSourceDialog + _showPatternStartSheet 삭제됨)
                    addLabel: isKorean ? '새 도안' : 'New',
                    onAdd: () => _showPatternStartSheet(context, ref),
                  ),
                );
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  // 모리니트 도안 라이브러리 — 통합 블록 디자인 (옅은 보라 톤, 양끝 보더)
                  MoriBlockShell(
                    label: isKorean ? '나의 도안 (MoriKnit)' : 'My Patterns (MoriKnit)',
                    icon: Icons.grid_on_rounded,
                    accent: C.lv,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        blueprintsAsync.when(
                          loading: () => AsyncLoadingFriendly(
                            isKorean: isKorean,
                            onRetry: () {
                              ref.invalidate(myBlueprintsWithLegacyProvider);
                              ref.invalidate(patternListProvider);
                              ref.invalidate(patternFilesProvider);
                            },
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            compact: true,
                          ),
                          // 이슈 #699 — raw Firestore 에러 노출 금지. 친화 메시지 + 재시도 버튼.
                          error: (e, _) => AsyncDelayedFriendly(
                            isKorean: isKorean,
                            onRetry: () {
                              ref.invalidate(myBlueprintsWithLegacyProvider);
                              ref.invalidate(patternListProvider);
                              ref.invalidate(patternFilesProvider);
                            },
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            compact: true,
                          ),
                          // 이슈 #687 (Phase I-B) — 신규 청사진 + legacy 어댑터 합산 데이터.
                          // 카드 표시는 PatternChart 기반 _PatternRow 그대로 사용하기 위해
                          // patternListProvider 의 PatternChart 로 lookup, 없으면 어댑터로 합성.
                          data: (blueprints) {
                            final files = filesAsync.valueOrNull ?? [];
                            final legacyCharts = patternsAsync.valueOrNull ?? const <PatternChart>[];
                            final chartById = {for (final c in legacyCharts) c.id: c};
                            final total = blueprints.length + files.length;
                            if (total == 0) {
                              return MoriEmptyState(
                                icon: Icons.grid_on_rounded,
                                iconColor: C.lvD,
                                title: isKorean ? '아직 도안이 없어요' : 'No patterns yet',
                                subtitle: isKorean ? '나만의 도안을 만들어보세요.' : 'Create your own pattern.',
                                buttonLabel: isKorean ? '새 도안 만들기' : 'Create new',
                                onAction: () => _showPatternStartSheet(context, ref),
                              );
                            }
                            // 이슈 #699 보완 — 모리니트 블록 내부 독립 스크롤 (높이 고정 + Scrollbar).
                            // 페이지 전체 ListView 는 헤더/요약카드/모리니트블록/라벨리블록 컨테이너 단위로만 스크롤.
                            final rowItems = <Widget>[
                              ...blueprints.map((bp) {
                                final chart = chartById[bp.id]
                                    ?? (bp.sourcePatternChartId != null ? chartById[bp.sourcePatternChartId!] : null)
                                    ?? (bp.chartAssetId != null ? chartById[bp.chartAssetId!] : null)
                                    ?? _blueprintToChart(bp);
                                // 이슈 #701 — visibility 를 부모 stream 데이터에서 직접 전달.
                                // 기존 _PatternRow 내부의 blueprintByIdWithLegacyProvider(chart.id) 호출 제거 →
                                // N 개 카드 × per-row Firestore round-trip 으로 인한 freeze 차단.
                                return _PatternRow(
                                  chart: chart,
                                  isKorean: isKorean,
                                  blueprintVisibility: bp.visibility,
                                  onTap: () => _openPattern(context, chart, filesAsync),
                                );
                              }),
                              ...files.map((f) => _FileRow(
                                file: f,
                                isKorean: isKorean,
                                onTap: () => _openFile(context, f),
                              )),
                            ];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 사용자 보고 (#619 보완) — 모리니트 카드의 '새 도안' 중복 버튼 삭제
                                // 요약카드 우측의 '+ 새 도안' 사용
                                Text(
                                  isKorean ? '내 도안 $total개' : '$total items',
                                  style: T.bodyBold,
                                ),
                                const SizedBox(height: 8),
                                // 통합 블록 셸이 양끝 옅은 보더 + 둥근 모서리를 제공 → 내부 독립 스크롤만 유지
                                SizedBox(
                                  height: 400,
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: ListView.builder(
                                      itemCount: rowItems.length,
                                      itemBuilder: (_, i) => rowItems[i],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Ravelry 도안 라이브러리 섹션
                  _RavelryLibrarySection(isKorean: isKorean),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 이슈 #687 (Phase I-B) — StepBlueprint → PatternChart 어댑터(합성).
  ///
  /// myBlueprintsWithLegacyProvider 가 반환한 청사진이 legacy pattern_charts 에 매칭되지
  /// 않을 때 표시·진입용으로 사용. 차트 그리드는 비어 있으나(rows=0, cols=0) 카드 표시와
  /// PatternDetailScreen 진입에는 충분. id/title/createdAt 등 표시 핵심 필드는 보존.
  PatternChart _blueprintToChart(StepBlueprint bp) {
    final imageUrls = bp.attachedImageUrls ?? const <String>[];
    final pdfUrls = bp.attachedPdfUrls ?? const <String>[];
    return PatternChart(
      id: bp.sourcePatternChartId ?? bp.chartAssetId ?? bp.id,
      title: bp.title,
      rows: 0,
      cols: 0,
      mode: ChartMode.color,
      grid: const <List<CellData>>[],
      type: pdfUrls.isNotEmpty
          ? PatternType.pdf
          : (imageUrls.isNotEmpty ? PatternType.image : PatternType.chart),
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
      pdfUrl: pdfUrls.isNotEmpty ? pdfUrls.first : '',
      sourceType: PatternSourceType.external,
      createdAt: bp.createdAt,
    );
  }

  // #645 — 도안 열기 라우팅 단일화
  // 기존: aiSections 있으면 텍스트뷰어로 강제 점프 → Case A/B 불일치
  // 현재: 모든 도안이 PatternDetailScreen 경유, 상태는 "초안" 배지로 구분
  //       서술형 보기는 뷰어 내 AppBar "subject" 아이콘으로 전환 (#612)
  void _openPattern(BuildContext context, PatternChart chart, AsyncValue<List<PatternFile>> filesAsync) {
    debugPrint('[OpenPattern] id=${chart.id} type=${chart.type.name} imageUrl="${chart.imageUrl}" pdfUrl="${chart.pdfUrl}"');
    if (chart.type == PatternType.chart) {
      debugPrint('[OpenPattern] → PatternEditorScreen (chart type)');
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PatternEditorScreen(
          patternId: chart.id,
          readOnly: true,
          returnRoute: Routes.toolsPatterns,
        ),
      ));
    } else {
      debugPrint('[OpenPattern] → PatternDetailScreen (image/pdf type)');
      // 이슈 #696 — settings.name 유일화로 restoration key 충돌 방지
      Navigator.push(context, MaterialPageRoute(
        settings: RouteSettings(
          name: 'pattern-detail/${chart.id}-${DateTime.now().millisecondsSinceEpoch}',
        ),
        builder: (_) => PatternDetailScreen(chart: chart),
      ));
    }
  }

  /// #659 — pattern_files도 도안 라이브러리에서 다른 도안과 동일 동작.
  /// PatternFile → PatternChart로 변환해 PatternDetailScreen으로 진입.
  /// 입수 경로(Dropbox/Ravelry/갤러리 등)는 단지 메타정보일 뿐, 표시·조작 통일.
  void _openFile(BuildContext context, PatternFile f) {
    debugPrint('[OpenFile] id=${f.id} mime=${f.mimeType} source=${f.source.name} storageUrl="${f.storageUrl}" parsedChartId=${f.parsedChartId}');
    final isImage = f.mimeType.startsWith('image/');
    final isPdf = f.mimeType == 'application/pdf';
    if (!isImage && !isPdf) {
      // 도안화 불가 형식 — 기존 파일 뷰어 유지
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _PatternFileViewerScreen(file: f),
      ));
      return;
    }
    final chart = PatternChart(
      id: f.id,
      title: f.fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
      rows: 0,
      cols: 0,
      mode: ChartMode.color,
      grid: const <List<CellData>>[],
      type: isPdf ? PatternType.pdf : PatternType.image,
      imageUrl: isImage
          ? f.storageUrl
          : (f.thumbnailUrl ?? ''),
      pdfUrl: isPdf ? f.storageUrl : '',
      sourceType: PatternSourceType.external,
      createdAt: f.createdAt,
    );
    debugPrint('[OpenFile] → PatternDetailScreen via PatternChart bridge');
    // 이슈 #696 — settings.name 유일화로 restoration key 충돌 방지
    Navigator.push(context, MaterialPageRoute(
      settings: RouteSettings(
        name: 'pattern-detail/${chart.id}-${DateTime.now().millisecondsSinceEpoch}',
      ),
      builder: (_) => PatternDetailScreen(chart: chart),
    ));
  }

  Future<void> _showImageSourceDialog(BuildContext context, WidgetRef ref, bool isKorean, {bool aiAnalysis = true}) async {
    if (kIsWeb) {
      // 웹: 파일 선택 직접 실행 (카메라 미지원)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.first.bytes != null && context.mounted) {
        final bytes = result.files.first.bytes!;
        final ext = result.files.first.extension?.toLowerCase() ?? 'jpg';
        final tmpFile = await _bytesToTempFile(bytes, 'picked.$ext');
        if (context.mounted) await _saveImageFile(context, ref, tmpFile, isKorean, aiAnalysis: aiAnalysis);
      }
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: C.lv),
                title: Text(isKorean ? '카메라로 찍기' : 'Take a photo', style: T.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.microtask(() {});
                  final picked = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 85);
                  if (picked != null && context.mounted) {
                    await _saveImageFile(context, ref, File(picked.path), isKorean, aiAnalysis: aiAnalysis);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: C.lv),
                title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery', style: T.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.microtask(() {});
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
                  if (picked != null && context.mounted) {
                    await _saveImageFile(context, ref, File(picked.path), isKorean, aiAnalysis: aiAnalysis);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File> _bytesToTempFile(List<int> bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _saveImageFile(BuildContext context, WidgetRef ref, File file, bool isKorean, {bool aiAnalysis = true}) async {
    // #687 — PatternRepository.saveImagePattern이 내부에서 step_blueprints 동시 미러.
    final repo = ref.read(patternRepositoryProvider);
    final title = await _askPatternTitle(context, isKorean);
    if (title == null || !context.mounted) return;

    try {
      PatternChart? saved;
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          saved = await repo.saveImagePattern(title: title, imageFile: file);
        },
      );
      if (!context.mounted || saved == null) return;
      // #687 — 저장 직후 라이선스·visibility 즉시 선택 (건너뛰기 가능, 기본값 Reserved+Draft).
      await _promptLicenseAndVisibility(context, ref, saved!.id, isKorean);
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PatternDetailScreen(chart: saved!)));
    } catch (e) {
      if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  /// .mori 파일 가져오기 → 저장소에 신규 도안으로 저장
  Future<void> _importMoriFile(BuildContext context, WidgetRef ref, bool isKorean) async {
    final repo = ref.read(patternRepositoryProvider);
    try {
      final imported = await PatternExportService.importMoriFile();
      if (imported == null || !context.mounted) return;
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '가져오는 중입니다.' : 'Importing...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await repo.save(imported);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          message: isKorean ? '도안을 가져왔어요.' : 'Pattern imported.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Future<void> _savePdfFile(BuildContext context, WidgetRef ref, File file, bool isKorean, {bool aiAnalysis = true}) async {
    // #687 — PatternRepository.savePdfPattern이 내부에서 step_blueprints 미러 + 커버 백그라운드 추출.
    final repo = ref.read(patternRepositoryProvider);
    final title = await _askPatternTitle(context, isKorean);
    if (title == null || !context.mounted) return;

    try {
      PatternChart? saved;
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          saved = await repo.savePdfPattern(title: title, pdfFile: file);
        },
      );
      if (!context.mounted || saved == null) return;
      // #687 — 저장 직후 라이선스·visibility 선택.
      await _promptLicenseAndVisibility(context, ref, saved!.id, isKorean);
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PatternDetailScreen(chart: saved!)));
    } catch (e) {
      if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  /// 이슈 #683 + #687 — 웹 호환 PDF 저장 (bytes 진입점).
  /// PatternRepository.savePdfPatternFromBytes가 내부에서 step_blueprints 미러.
  Future<void> _savePdfBytes(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
    String fileName,
    bool isKorean, {
    bool aiAnalysis = true,
  }) async {
    final repo = ref.read(patternRepositoryProvider);
    final title = await _askPatternTitle(context, isKorean);
    if (title == null || !context.mounted) return;

    try {
      PatternChart? saved;
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          saved = await repo.savePdfPatternFromBytes(
            title: title,
            bytes: bytes,
            fileName: fileName,
          );
        },
      );
      if (!context.mounted || saved == null) return;
      // #687 — 저장 직후 라이선스·visibility 선택.
      await _promptLicenseAndVisibility(context, ref, saved!.id, isKorean);
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PatternDetailScreen(chart: saved!)));
    } catch (e) {
      if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  /// 이슈 #683 + #687 — 웹 호환 이미지 저장 (bytes 진입점).
  /// PatternRepository.saveImagePatternFromBytes가 내부에서 step_blueprints 미러.
  Future<void> _saveImageBytes(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
    String fileName,
    bool isKorean, {
    bool aiAnalysis = true,
  }) async {
    final repo = ref.read(patternRepositoryProvider);
    final title = await _askPatternTitle(context, isKorean);
    if (title == null || !context.mounted) return;

    try {
      PatternChart? saved;
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          saved = await repo.saveImagePatternFromBytes(
            title: title,
            bytes: bytes,
            fileName: fileName,
          );
        },
      );
      if (!context.mounted || saved == null) return;
      // #687 — 저장 직후 라이선스·visibility 선택.
      await _promptLicenseAndVisibility(context, ref, saved!.id, isKorean);
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PatternDetailScreen(chart: saved!)));
    } catch (e) {
      if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<String?> _askPatternTitle(BuildContext context, bool isKorean) async {
    final ctrl = TextEditingController();
    String? result;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(isKorean ? '도안 이름' : 'Pattern name', style: T.h3),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isKorean ? '도안 이름을 입력하세요' : 'Enter pattern name',
                ),
                onSubmitted: (v) {
                  result = v.trim().isEmpty ? (isKorean ? '내 도안' : 'My Pattern') : v.trim();
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isKorean ? '취소' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        result = ctrl.text.trim().isEmpty ? (isKorean ? '내 도안' : 'My Pattern') : ctrl.text.trim();
                        Navigator.pop(ctx);
                      },
                      child: Text(isKorean ? '등록' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    // ctrl.dispose()를 여기서 호출하면 BottomSheet 닫힘 애니메이션 중
    // TextField가 이미 disposed된 controller를 사용하여 크래쉬 발생.
    // 로컬 변수이므로 GC가 처리하도록 dispose 생략.
    return result;
  }

  /// 이슈 #687 — 도안 저장 직후 라이선스·visibility 즉시 선택 다이얼로그.
  /// 기본값(Reserved + Draft) 그대로 두어도 되며, "건너뛰기" 누르면 스킵.
  /// 선택 시 stepBlueprintRepositoryProvider.update() 로 step_blueprints 갱신.
  Future<void> _promptLicenseAndVisibility(
    BuildContext context,
    WidgetRef ref,
    String chartId,
    bool isKorean,
  ) async {
    if (chartId.isEmpty) return;
    var visibility = BlueprintVisibility.draft;
    var license = LicenseType.reserved;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: C.bd2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isKorean ? '라이선스 · 공개 범위' : 'License & Visibility',
                  style: T.h3,
                ),
                const SizedBox(height: 6),
                Text(
                  isKorean
                      ? '도안의 권리·공개 범위를 지정해요. 나중에 도안 상세에서 변경할 수 있어요.'
                      : 'Set your pattern\'s rights and visibility. You can change later.',
                  style: T.caption.copyWith(color: C.mu),
                ),
                const SizedBox(height: 18),
                Text(isKorean ? '공개 범위' : 'Visibility',
                    style: T.bodyBold.copyWith(color: C.lvD, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kBlueprintVisibilityOptions.map((v) {
                    return BlueprintSelectableChip(
                      label: blueprintVisibilityLabel(v, isKorean),
                      selected: v == visibility,
                      onTap: () => setSheet(() => visibility = v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(isKorean ? '라이선스' : 'License',
                    style: T.bodyBold.copyWith(color: C.lvD, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kBlueprintLicenseOptions.map((t) {
                    return BlueprintSelectableChip(
                      label: blueprintLicenseLabel(t, isKorean),
                      selected: t == license,
                      onTap: () => setSheet(() => license = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(isKorean ? '건너뛰기' : 'Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.lv,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(isKorean ? '적용' : 'Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = ref.read(stepBlueprintRepositoryProvider);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await repo.update(chartId, {
            'visibility': visibility.name,
            'license': BlueprintLicense(type: license).toMap(),
          });
        },
      );
      ref.invalidate(blueprintByIdWithLegacyProvider(chartId));
      if (!context.mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '저장됐어요.' : 'Saved.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  /// 이슈 #665 — 사각/원형 도안 형태 선택 모달.
  /// 도구함과 공통 사용 — chart_shape_picker.dart의 showChartShapePicker로 위임.
  Future<String?> _pickChartShape(BuildContext context, bool isKorean) =>
      showChartShapePicker(context, isKorean);

  /// 이슈 #716 — "내 핸드폰" 하위 시트: 사진 / PDF / 내 폰 파일 3가지 옵션 통합.
  Future<void> _showMyDeviceSubSheet(
    BuildContext context,
    WidgetRef ref,
    bool isKorean, {
    required bool aiAnalysis,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: ListView(
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: C.bd2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(isKorean ? '내 핸드폰에서 가져오기' : 'Import from device', style: T.h3),
              const SizedBox(height: 12),
              // 사진에서 만들기 (갤러리 + 카메라)
              GlassCard(
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.microtask(() {});
                  if (context.mounted) {
                    _showImageSourceDialog(context, ref, isKorean, aiAnalysis: aiAnalysis);
                  }
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.photo_library_rounded, color: C.lv),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isKorean ? '사진에서 만들기' : 'From photo', style: T.bodyBold),
                        const SizedBox(height: 4),
                        Text(
                          isKorean ? '갤러리나 카메라로 사진을 찍어요' : 'Take or pick a photo',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              // PDF에서 만들기
              GlassCard(
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.microtask(() {});
                  if (kIsWeb) {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      withData: true,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final f = result.files.first;
                    if (f.bytes == null || !context.mounted) return;
                    await _savePdfBytes(context, ref, f.bytes!, f.name, isKorean, aiAnalysis: aiAnalysis);
                    return;
                  }
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );
                  if (result != null && result.files.first.path != null && context.mounted) {
                    await _savePdfFile(context, ref, File(result.files.first.path!), isKorean, aiAnalysis: aiAnalysis);
                  }
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.og.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded, color: C.og),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isKorean ? 'PDF에서 만들기' : 'From PDF', style: T.bodyBold),
                        const SizedBox(height: 4),
                        Text(
                          isKorean ? 'PDF 파일에서 도안을 가져와요' : 'Import pattern from PDF',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              // 내 폰 파일에서 가져오기 (PDF·이미지 통합)
              GlassCard(
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.microtask(() {});
                  if (kIsWeb) {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
                      withData: true,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final f = result.files.first;
                    if (f.bytes == null || !context.mounted) return;
                    final ext = f.name.split('.').last.toLowerCase();
                    if (ext == 'pdf') {
                      await _savePdfBytes(context, ref, f.bytes!, f.name, isKorean, aiAnalysis: aiAnalysis);
                    } else {
                      await _saveImageBytes(context, ref, f.bytes!, f.name, isKorean, aiAnalysis: aiAnalysis);
                    }
                    return;
                  }
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
                  );
                  if (result == null || result.files.first.path == null) return;
                  if (!context.mounted) return;
                  final path = result.files.first.path!;
                  final ext = path.split('.').last.toLowerCase();
                  final file = File(path);
                  if (ext == 'pdf') {
                    await _savePdfFile(context, ref, file, isKorean, aiAnalysis: aiAnalysis);
                  } else {
                    await _saveImageFile(context, ref, file, isKorean, aiAnalysis: aiAnalysis);
                  }
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.folder_open_rounded, color: C.lv),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKorean ? '내 폰 파일에서 가져오기' : 'Import from device files',
                          style: T.bodyBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKorean
                              ? '다운로드 폴더 등에서 PDF·이미지 파일을 골라요'
                              : 'Pick PDF or image from downloads/files',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPatternStartSheet(BuildContext context, WidgetRef ref) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    // #628 — AI 자동 분석 토글 (closure로 시트 세션 내 유지, 기본 ON)
    // 정책: AI는 유료 기능. 무료 사용자는 OFF 가능. 현재 테스트 기간 모두 사용 가능.
    bool aiAnalysis = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final scrollCtrl = ScrollController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: ListView(
            controller: scrollCtrl,
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: C.bd2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(isKorean ? '도안 만들기' : 'Create Pattern', style: T.h3),
              const SizedBox(height: 12),
              // #628 — AI 자동 분석 토글 (기본 ON, 사용자 OFF 가능)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: aiAnalysis ? C.lvL : C.gx,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: aiAnalysis ? C.lv.withValues(alpha: 0.4) : C.bd),
                ),
                child: Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: aiAnalysis ? C.lvD : C.mu, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKorean ? 'AI 자동 분석' : 'AI Auto Analysis',
                          style: T.caption.copyWith(color: aiAnalysis ? C.lvD : C.tx, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          aiAnalysis
                              ? (isKorean ? '업로드 시 단계로그를 자동 생성해요' : 'Auto-create step log on upload')
                              : (isKorean ? '단순 저장 — 단계로그는 도안 상세에서 추가' : 'Save only — add steps later'),
                          style: T.caption.copyWith(color: C.mu, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: aiAnalysis,
                    onChanged: (v) => setSheetState(() => aiAnalysis = v),
                    activeThumbColor: C.lv,
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // 이슈 #716 — 정렬 1: 내 핸드폰 (사진 / PDF / 내 폰 파일 통합 하위 시트).
              GlassCard(
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.microtask(() {});
                  if (!context.mounted) return;
                  await _showMyDeviceSubSheet(context, ref, isKorean, aiAnalysis: aiAnalysis);
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.smartphone_rounded, color: C.lv),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKorean ? '내 핸드폰' : 'My device',
                          style: T.bodyBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKorean ? '사진 · PDF · 내 폰 파일에서 가져와요' : 'Photos · PDF · files on device',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              // 이슈 #716 — 정렬 2: 도안에디터로 만들기 (이슈 #665 — 사각/원형 분기).
              GlassCard(
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  final shape = await _pickChartShape(context, isKorean);
                  if (shape == null) return;
                  if (!context.mounted) return;
                  if (shape == 'rect') {
                    context.push(Routes.toolsPattern);
                  } else {
                    context.push('${Routes.toolsPattern}?chartType=$shape');
                  }
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.lvD.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.grid_on_rounded, color: C.lvD),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKorean ? '도안에디터로 만들기' : 'Use pattern editor',
                          style: T.bodyBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKorean
                              ? '사각 그리드(스웨터) 또는 원형(코바늘) 직접 작성'
                              : 'Draw rect grid (sweater) or round (crochet)',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              // 이슈 #716 — 정렬 3: 클라우드 (Dropbox·Google Drive·iCloud·OneDrive 통합 허브).
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(Routes.cloudHub);
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0061FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cloud_rounded, color: Color(0xFF0061FF)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isKorean ? '클라우드' : 'Cloud',
                              style: T.bodyBold,
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: C.lv,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'AI',
                                style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKorean
                              ? 'Dropbox · Google Drive · iCloud · OneDrive 에서 가져오기'
                              : 'Import from Dropbox · Google Drive · iCloud · OneDrive',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              // 유지: .mori 파일 가져오기.
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  _importMoriFile(context, ref, isKorean);
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.file_upload_rounded, color: C.lv),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKorean ? '.mori 파일 가져오기' : 'Import .mori file',
                          style: T.bodyBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKorean ? '모리니트 도안 파일(.mori)을 불러와요' : 'Load a MoriKnit pattern file (.mori)',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              // 유지: AI 변환기 (외부 진입점 보존).
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(Routes.toolsPatternConverter);
                },
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: C.pkD.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: C.pkD),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKorean ? 'AI 변환기' : 'AI converter',
                          style: T.bodyBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKorean ? '복잡한 도안을 AI가 단계별로 분석해드려요' : 'AI breaks complex patterns into steps',
                          style: T.caption.copyWith(color: C.mu),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
            ],
          ),
          ),
        );
      },
    );
  }



}

class _PatternRow extends ConsumerWidget {
  final PatternChart chart;
  final bool isKorean;
  final VoidCallback onTap;
  // 이슈 #701 — 부모 stream 의 StepBlueprint.visibility 를 직접 받음.
  // 과거: 카드마다 blueprintByIdWithLegacyProvider 로 Firestore 재호출 → N 카드 × 라운드트립으로 UI freeze.
  // 현재: 부모 watch 결과를 props 로 전달 → 추가 I/O 0.
  final BlueprintVisibility? blueprintVisibility;
  const _PatternRow({
    required this.chart,
    required this.isKorean,
    required this.onTap,
    this.blueprintVisibility,
  });

  IconData get _typeIcon {
    switch (chart.type) {
      case PatternType.image: return Icons.image_rounded;
      case PatternType.pdf: return Icons.picture_as_pdf_rounded;
      case PatternType.chart: return Icons.grid_on_rounded;
    }
  }

  Color get _iconBgColor {
    switch (chart.type) {
      case PatternType.image: return C.lmD;
      case PatternType.pdf: return C.og;
      case PatternType.chart: return C.lvD;
    }
  }

  String _subtitleText(bool isKorean) {
    switch (chart.type) {
      case PatternType.image: return isKorean ? '이미지 도안' : 'Image pattern';
      case PatternType.pdf: return isKorean ? 'PDF 도안' : 'PDF pattern';
      case PatternType.chart:
        final modeLabel = chart.mode == ChartMode.color
            ? (isKorean ? '컬러' : 'Color')
            : (isKorean ? '기호' : 'Symbol');
        return '${chart.rows} × ${chart.cols}  |  $modeLabel';
    }
  }

  bool get _isNew {
    final created = chart.createdAt;
    if (created == null) return false;
    return DateTime.now().difference(created).inHours < 24;
  }

  /// #687 — 청사진 visibility 배지 (없으면 null). 라이브러리 카드 좌측에 표시.
  /// 이슈 #701 — 부모 stream 데이터 (StepBlueprint.visibility) 를 직접 사용. Firestore 재호출 제거.
  Widget? _visibilityBadge() {
    if (chart.id.isEmpty) return null;
    final v = blueprintVisibility;
    if (v == null) return null;
    // draft 배지는 chart.isComplete 기반으로 이미 표시 중 → 중복 방지.
    if (v == BlueprintVisibility.draft) return null;
    final (Color bg, Color fg, String label) = switch (v) {
      BlueprintVisibility.private => (
          C.mu.withValues(alpha: 0.12),
          C.mu,
          isKorean ? '비공개' : 'PRIVATE',
        ),
      BlueprintVisibility.unlisted => (
          C.lv.withValues(alpha: 0.10),
          C.lvD,
          isKorean ? '링크' : 'UNLISTED',
        ),
      BlueprintVisibility.public => (
          C.lm.withValues(alpha: 0.18),
          C.lmD,
          isKorean ? '공개' : 'PUBLIC',
        ),
      BlueprintVisibility.marketplace => (
          C.pkD,
          Colors.white,
          isKorean ? '마켓' : 'MARKET',
        ),
      _ => (C.mu.withValues(alpha: 0.10), C.mu, v.name.toUpperCase()),
    };
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibilityBadge = _visibilityBadge();
    return MoriLibraryCard(
      title: chart.title,
      subtitle1: _subtitleText(isKorean),
      // 이슈 #648 — 모든 도안 타입에서 imageUrl을 커버로 표시
      // (image=원본, pdf=첫페이지 추출, chart=사용자 설정/캡처)
      thumbnailUrl: chart.imageUrl.isNotEmpty ? chart.imageUrl : null,
      fallbackIcon: _typeIcon,
      fallbackIconBg: _iconBgColor.withValues(alpha: 0.12),
      fallbackIconColor: _iconBgColor,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 이슈 #687 — 청사진 visibility 배지 (private/unlisted/public/marketplace)
          ?visibilityBadge,
          // 이슈 #626 — draft 배지 (초안)
          if (!chart.isComplete)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.og.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.og.withValues(alpha: 0.4)),
              ),
              child: Text(
                isKorean ? '초안' : 'DRAFT',
                style: TextStyle(
                  fontSize: 10,
                  color: C.og,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          if (_isNew)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.lv,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'NEW',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          // #653 — AI 변환도안 (단계로그 보유) 배지
          if (chart.aiSections != null && chart.aiSections!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.pkD,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isKorean ? 'AI변환' : 'AI',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          // 이슈 #644 — Ravelry 도안 배지 (ravelryPatternId 있을 때)
          if (chart.ravelryPatternId != null)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.lv.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Ravelry',
                style: TextStyle(
                  fontSize: 10,
                  color: C.lvD,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final PatternFile file;
  final bool isKorean;
  final VoidCallback onTap;
  const _FileRow({required this.file, required this.isKorean, required this.onTap});

  IconData get _icon {
    if (file.mimeType == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (file.mimeType.startsWith('image/')) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color get _iconColor {
    if (file.mimeType == 'application/pdf') return const Color(0xFFE53935);
    if (file.mimeType.startsWith('image/')) return const Color(0xFF43A047);
    return C.mu;
  }

  String get _sourceLabel {
    switch (file.source) {
      case PatternFileSource.dropbox: return 'Dropbox';
      case PatternFileSource.ravelry: return 'Ravelry';
      case PatternFileSource.upload: return isKorean ? '업로드' : 'Upload';
      case PatternFileSource.gallery: return isKorean ? '갤러리' : 'Gallery';
      case PatternFileSource.camera: return isKorean ? '카메라' : 'Camera';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MoriLibraryCard(
      title: file.fileName,
      subtitle1: _sourceLabel,
      fallbackIcon: _icon,
      fallbackIconBg: _iconColor.withValues(alpha: 0.12),
      fallbackIconColor: _iconColor,
      onTap: onTap,
      trailing: Icon(Icons.chevron_right_rounded, color: C.mu),
    );
  }
}

// ── PatternFile 전용 뷰어 + 팝업메뉴 ──────────────────────────────────────────
class _PatternFileViewerScreen extends ConsumerStatefulWidget {
  final PatternFile file;
  const _PatternFileViewerScreen({required this.file});

  @override
  ConsumerState<_PatternFileViewerScreen> createState() => _PatternFileViewerScreenState();
}

class _PatternFileViewerScreenState extends ConsumerState<_PatternFileViewerScreen> {
  late PatternFile _file;

  // PDF state
  String? _pdfLocalPath;
  bool _pdfLoading = false;
  String? _pdfError;
  int _currentPage = 0;
  int _totalPages = 0;

  // 세로 헤어라인
  bool _hairlineEnabled = false;
  double _hairlineX = 0.5; // 화면 너비 비율 (0.0~1.0)

  @override
  void initState() {
    super.initState();
    _file = widget.file;
    if (_isPdf && !kIsWeb) _loadPdf();
  }

  bool get _isPdf => _file.mimeType == 'application/pdf';
  bool get _isImage => _file.mimeType.startsWith('image/');

  Future<void> _loadPdf() async {
    setState(() { _pdfLoading = true; _pdfError = null; });
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(_file.storageUrl));
      final response = await request.close();
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final bytes = await response.expand((b) => b).toList();
      client.close();
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/pattern_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await f.writeAsBytes(bytes);
      if (mounted) setState(() { _pdfLocalPath = f.path; _pdfLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _pdfError = '$e'; _pdfLoading = false; });
    }
  }

  Future<void> _rename() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final ctrl = TextEditingController(text: _file.fileName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '파일명 변경' : 'Rename file'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: isKorean ? '새 파일명' : 'New name'),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(isKorean ? '확인' : 'OK')),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(patternFileRepositoryProvider).rename(_file.id, result),
      );
      if (!mounted) return;
      setState(() => _file = _file.copyWith(fileName: result));
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '수정됐어요.' : 'Renamed.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _duplicate() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      await runWithMoriLoadingDialog<void>(context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(patternFileRepositoryProvider).duplicate(_file.id),
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '복사됐어요.' : 'Duplicated.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _linkToProject() {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final allProjects = cRef.watch(projectListProvider).valueOrNull ?? [];
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder: (_, scrollCtrl) => Column(children: [
              const SizedBox(height: 8),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(isKorean ? '프로젝트에 연결' : 'Link to Project', style: T.bodyBold),
              ),
              if (allProjects.isEmpty)
                Expanded(child: Center(child: Text(isKorean ? '등록된 프로젝트가 없어요.' : 'No projects available.', style: T.body.copyWith(color: C.mu))))
              else
                Expanded(child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: allProjects.length,
                  itemBuilder: (_, i) {
                    final project = allProjects[i];
                    return ListTile(
                      leading: project.coverPhotoUrl.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(project.coverPhotoUrl, width: 40, height: 40, fit: BoxFit.cover))
                          : Container(width: 40, height: 40, decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(6)), child: Icon(Icons.folder_rounded, color: C.lv)),
                      title: Text(project.title, style: T.bodyBold),
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await runWithMoriLoadingDialog<void>(context,
                            message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                            subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                            task: () => ref.read(patternFileRepositoryProvider).linkToProject(_file.id, project.id),
                          );
                          if (!mounted) return;
                          showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '프로젝트에 연결됐어요.' : 'Linked to project.');
                        } catch (e) {
                          if (!mounted) return;
                          showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                        }
                      },
                    );
                  },
                )),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _delete() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '파일 삭제' : 'Delete file', style: T.h3),
        content: Text(isKorean ? '이 파일을 삭제할까요? 되돌릴 수 없어요.' : 'Delete this file? Cannot be undone.', style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(patternFileRepositoryProvider).delete(_file.id),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Widget _buildHairline(BoxConstraints constraints) {
    final x = _hairlineX * constraints.maxWidth;
    return Stack(
      children: [
        Positioned(
          left: x - 0.75,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SizedBox(
              width: 1.5,
              child: Container(color: const Color(0xFFF59E0B).withValues(alpha: 0.85)),
            ),
          ),
        ),
        Positioned(
          left: x - 18,
          top: 4,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _hairlineX = (_hairlineX + details.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
              });
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfBody() {
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text('웹에서는 PDF를 직접 볼 수 없어요', style: T.body.copyWith(color: Colors.white70)),
          ],
        ),
      );
    }
    if (_pdfLoading) return Center(child: CircularProgressIndicator(color: C.lv));
    if (_pdfError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text('파일을 불러올 수 없어요', style: T.body.copyWith(color: Colors.white70)),
          ],
        ),
      );
    }
    if (_pdfLocalPath == null) return Center(child: CircularProgressIndicator(color: C.lv));
    return PDFView(
      filePath: _pdfLocalPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onPageChanged: (page, total) {
        if (mounted) setState(() { _currentPage = (page ?? 0) + 1; _totalPages = total ?? 0; });
      },
      onError: (e) {
        if (mounted) setState(() => _pdfError = '$e');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    return Scaffold(
      backgroundColor: _isPdf ? const Color(0xFF1A1A2E) : Colors.black,
      appBar: AppBar(
        backgroundColor: _isPdf ? const Color(0xFF1A1A2E) : Colors.black,
        foregroundColor: Colors.white,
        title: Text(_file.fileName, style: T.bodyBold.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              Icons.straighten_rounded,
              color: _hairlineEnabled ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.55),
            ),
            tooltip: isKorean ? '세로 헤어라인' : 'Vertical hairline',
            onPressed: () => setState(() => _hairlineEnabled = !_hairlineEnabled),
          ),
          IconButton(
            icon: Icon(
              Icons.menu_book_rounded,
              color: (_file.parsedChartId != null && _file.parseStatus == PatternParseStatus.done)
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
            tooltip: isKorean ? '텍스트 뷰어' : 'Text Viewer',
            onPressed: (_file.parsedChartId != null && _file.parseStatus == PatternParseStatus.done)
                ? () => context.push('${Routes.toolsMyParsedPatterns}/${_file.parsedChartId}/text')
                : null,
          ),
          if (_isPdf && _totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text('$_currentPage / $_totalPages', style: T.caption.copyWith(color: Colors.white70))),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (v) {
              if (v == 'rename') _rename();
              if (v == 'copy') _duplicate();
              if (v == 'link_project') _linkToProject();
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '수정' : 'Rename')])),
              PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '복사' : 'Duplicate')])),
              PopupMenuItem(value: 'link_project', child: Row(children: [Icon(Icons.folder_outlined, size: 18, color: C.lv), const SizedBox(width: 8), Text(isKorean ? '프로젝트 연결' : 'Link to project')])),
              PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: C.og), const SizedBox(width: 8), Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))])),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(
              child: _isPdf
                  ? _buildPdfBody()
                  : _isImage
                      ? InteractiveViewer(child: Center(child: Image.network(_file.storageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64))))
                      : Center(child: Text(_file.fileName, style: const TextStyle(color: Colors.white))),
            ),
            if (_hairlineEnabled) _buildHairline(constraints),
          ],
        ),
      ),
    );
  }
}


// ── Ravelry 도안 라이브러리 섹션 ──────────────────────────
class _RavelryLibrarySection extends ConsumerWidget {
  final bool isKorean;
  const _RavelryLibrarySection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(ravelryAuthProvider);

    return MoriBlockShell(
      label: isKorean ? '나의 도안 라이브러리 (Ravelry)' : 'My Pattern Library (Ravelry)',
      icon: Icons.library_books_rounded,
      accent: C.pk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!auth.isLoggedIn)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.pk.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, color: C.pk, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    isKorean ? 'Ravelry 연결 시 구입한 도안이 표시돼요' : 'Connect Ravelry to see your purchased patterns',
                    style: T.caption.copyWith(color: C.mu),
                  )),
                ],
              ),
            )
          else
            _RavelryLibraryList(isKorean: isKorean),
        ],
      ),
    );
  }
}

class _RavelryLibraryList extends ConsumerWidget {
  final bool isKorean;
  const _RavelryLibraryList({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(ravelryLibraryProvider);
    return libraryAsync.when(
      loading: () => AsyncLoadingFriendly(
        isKorean: isKorean,
        onRetry: () => ref.invalidate(ravelryLibraryProvider),
        padding: const EdgeInsets.all(16),
        compact: true,
      ),
      // 이슈 #699 — 친화 메시지 + 재시도 버튼 (통일 헬퍼)
      error: (e, _) => AsyncDelayedFriendly(
        isKorean: isKorean,
        onRetry: () => ref.invalidate(ravelryLibraryProvider),
        padding: const EdgeInsets.symmetric(vertical: 20),
        compact: true,
      ),
      data: (patterns) {
        if (patterns.isEmpty) {
          return Text(isKorean ? 'Ravelry 도안 라이브러리가 비어있어요.' : 'Your Ravelry library is empty.',
              style: T.body.copyWith(color: C.mu));
        }
        // 통합 블록 셸이 양끝 옅은 보더 + 둥근 모서리를 제공 → 내부 독립 스크롤만 유지
        return SizedBox(
          height: 400,
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              itemCount: patterns.length,
              itemBuilder: (_, i) => _RavelryPatternCard(pattern: patterns[i], isKorean: isKorean),
            ),
          ),
        );
      },
    );
  }
}

class _RavelryPatternCard extends StatelessWidget {
  final RavelryLibraryPattern pattern;
  final bool isKorean;
  const _RavelryPatternCard({required this.pattern, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return MoriLibraryCard(
      title: pattern.name,
      subtitle1: pattern.authorName,
      subtitle2: pattern.categories.isNotEmpty ? pattern.categories.take(2).join(' · ') : null,
      thumbnailUrl: pattern.thumbnailUrl,
      fallbackIcon: Icons.menu_book_rounded,
      fallbackIconBg: C.lvL,
      fallbackIconColor: C.lvD,
      onTap: () => _showDetail(context),
      trailing: pattern.isFree
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: C.lmG, borderRadius: BorderRadius.circular(8)),
              child: Text(isKorean ? '무료' : 'Free', style: T.caption.copyWith(color: C.lmD, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  void _showDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RavelryPatternDetailScreen(
          patternId: pattern.id,
          patternName: pattern.name,
        ),
      ),
    );
  }
}
