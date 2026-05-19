import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/dropbox_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../features/pattern/data/pattern_repository.dart';
import '../../../features/pattern/domain/pattern_chart.dart';
import '../../../features/pattern/presentation/pattern_editor_screen.dart';
import '../../../features/project/domain/raglan_pattern_builder.dart';
import '../../../features/project/domain/raglan_template.dart';
import '../../../providers/parsed_pattern_provider.dart';
import '../../dropbox/data/dropbox_auth_provider.dart';
import '../data/ai_error_mapper.dart';
import '../data/pattern_converter_repository.dart';
import 'ai_pattern_edit_screen.dart';
import 'my_pattern_library_picker_sheet.dart';
import 'pattern_translator_screen.dart' show DropboxPickerScreen, DropboxPickResult;
import 'widgets/import_option_tile.dart';

class PatternConverterScreen extends ConsumerStatefulWidget {
  final Uint8List? preloadedBytes;
  final String? preloadedFileName;
  final String? preloadedMimeType;

  const PatternConverterScreen({
    super.key,
    this.preloadedBytes,
    this.preloadedFileName,
    this.preloadedMimeType,
  });

  @override
  ConsumerState<PatternConverterScreen> createState() =>
      _PatternConverterScreenState();
}

class _PatternConverterScreenState
    extends ConsumerState<PatternConverterScreen> {
  bool _isUploading = false;
  double _progress = 0;
  int _stage = 1; // 1=업로드, 2=AI분석, 3=저장
  String _statusMessage = '';
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedBytes != null && widget.preloadedFileName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runParsing(
          bytes: widget.preloadedBytes!,
          fileName: widget.preloadedFileName!,
          mimeType: widget.preloadedMimeType ?? 'application/pdf',
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 이슈 #714 — messenger 참조를 컨텍스트 유효할 때 캐시. dispose에서 안전하게 사용.
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // 이슈 #714 — 화면 이탈 시 모든 SnackBar(AI 사용량 알림 포함) 큐 전체 제거.
    // ScaffoldMessenger는 루트에 살아있어 페이지 전환에도 SnackBar가 남는 문제 방지.
    _messenger?.clearSnackBars();
    super.dispose();
  }

  Future<void> _showSourceSheet() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    // 이슈 #628 (B-7) — AI 자동 분석 토글 (closure로 시트 세션 내 유지)
    bool aiAnalysis = true;
    // 이슈 #800 — 외부 클라우드 4종(Dropbox/Drive/iCloud/OneDrive)을 1개 항목으로 묶고 펼침.
    bool cloudExpanded = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      isScrollControlled: true, // #628 — 7개 카드 오버플로우 방지
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(isKorean ? '도안 추가' : 'Add Pattern', style: T.h3),
              ),
              const SizedBox(height: 6),
              // 이슈 #628 (B-7) — AI 자동 분석 토글
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: aiAnalysis ? C.lvL : C.gx,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: aiAnalysis
                          ? C.lv.withValues(alpha: 0.4)
                          : C.bd,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: aiAnalysis ? C.lvD : C.mu,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isKorean ? 'AI 자동 분석' : 'AI Auto Analysis',
                              style: T.caption.copyWith(
                                color: aiAnalysis ? C.lvD : C.tx,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              aiAnalysis
                                  ? (isKorean
                                      ? '업로드 시 섹션을 자동 생성해요'
                                      : 'Auto-generate sections on upload')
                                  : (isKorean
                                      ? '단순 저장 — 섹션 없이 draft 상태로 (지원 예정)'
                                      : 'Save only — draft state, no sections (coming soon)'),
                              style: T.caption.copyWith(
                                color: C.mu,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: aiAnalysis,
                        onChanged: (v) => setSheetState(() => aiAnalysis = v),
                        activeThumbColor: C.lv,
                      ),
                    ],
                  ),
                ),
              ),
              // 이슈 #628 — 3가지 진입점 안내
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  isKorean
                      ? '파일·외부 클라우드는 AI로 분석되어 섹션이 자동 생성됩니다.'
                      : 'Files & cloud imports are analyzed by AI with auto-generated sections.',
                  style: T.caption.copyWith(color: C.mu, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            // ① 파일 (내 기기) — #869 공통 위젯 적용
            ImportOptionTile(
              icon: kIsWeb ? Icons.computer_rounded : Icons.smartphone_rounded,
              title: kIsWeb
                  ? (isKorean ? '내 컴퓨터' : 'My Computer')
                  : (isKorean ? '내 핸드폰' : 'My Device'),
              subtitle: 'PDF, JPG, PNG',
              onTap: () async {
                if (!aiAnalysis) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isKorean
                          ? 'AI 분석 없이 단순 저장은 곧 지원돼요. 지금은 AI 분석을 켜주세요.'
                          : 'Save without AI analysis is coming soon. Please enable AI analysis for now.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                await Future.microtask(() {});
                _pickFromPhone();
              },
            ),
            // ①-2 내 도안 라이브러리 (이슈 #860)
            //   `users/{uid}/pattern_charts` 에서 PDF/이미지가 첨부된 도안만 노출.
            //   탭 → 다운로드 → 변환기 입력으로 전달.
            //   #869 — 다른 옵션과 동일 라벤더 톤 (lm → lv).
            ImportOptionTile(
              icon: Icons.bookmark_rounded,
              title: isKorean ? '내 도안 라이브러리' : 'My Pattern Library',
              subtitle: isKorean
                  ? '내 도안에 저장된 PDF/이미지에서 가져오기'
                  : 'Import from saved PDF/image patterns',
              onTap: () async {
                if (!aiAnalysis) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isKorean
                          ? 'AI 분석 없이 단순 저장은 곧 지원돼요. 지금은 AI 분석을 켜주세요.'
                          : 'Save without AI analysis is coming soon. Please enable AI analysis for now.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                await Future.microtask(() {});
                _pickFromMyLibrary();
              },
            ),
            // ② 외부 클라우드 — 4종 그룹화 (이슈 #800)
            // Dropbox(활성) + Google Drive/iCloud/OneDrive(준비 중)을 ExpansionTile로 묶음.
            // 펼침 시 기존 4개 옵션 동일 UI 유지.
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: cloudExpanded,
                onExpansionChanged: (v) => setSheetState(() => cloudExpanded = v),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: C.lvL,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cloud_rounded, color: C.lvD, size: 22),
                ),
                title: Text(
                  isKorean ? '외부 클라우드' : 'External Cloud',
                  style: T.bodyBold,
                ),
                subtitle: Text(
                  isKorean ? '4개 서비스 · 탭하여 펼치기' : '4 services · tap to expand',
                  style: T.caption.copyWith(color: C.mu),
                ),
                children: [
                  // ②-1 Dropbox (활성) — #869 공통 위젯 + Dropbox 브랜드 톤 유지
                  ImportOptionTile(
                    leftPadding: 16,
                    icon: DropboxTheme.of(context).icon,
                    iconColor: DropboxTheme.of(context).brandColor,
                    iconBackground: DropboxTheme.of(context).brandColor.withValues(
                          alpha: DropboxTheme.of(context).iconBoxBgAlpha,
                        ),
                    title: 'Dropbox',
                    subtitle: isKorean ? '드롭박스에서 파일 선택' : 'Pick from Dropbox',
                    onTap: () async {
                      if (!aiAnalysis) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isKorean
                                ? 'AI 분석 없이 단순 저장은 곧 지원돼요. 지금은 AI 분석을 켜주세요.'
                                : 'Save without AI analysis is coming soon. Please enable AI analysis for now.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      await Future.microtask(() {});
                      _pickFromDropbox();
                    },
                  ),
                  // ②-2 Google Drive (준비 중)
                  _buildComingSoonCloud(
                    context,
                    isKorean: isKorean,
                    label: 'Google Drive',
                    icon: Icons.cloud_rounded,
                  ),
                  // ②-3 iCloud (준비 중)
                  _buildComingSoonCloud(
                    context,
                    isKorean: isKorean,
                    label: 'iCloud',
                    icon: Icons.cloud_rounded,
                  ),
                  // ②-4 OneDrive (준비 중)
                  _buildComingSoonCloud(
                    context,
                    isKorean: isKorean,
                    label: 'OneDrive',
                    icon: Icons.cloud_rounded,
                  ),
                ],
              ),
            ),
            // ③ 도안에디터 (신규 — 이슈 #628). #869 공통 위젯 + 핑크 톤 유지(변환기 특화).
            ImportOptionTile(
              icon: Icons.edit_rounded,
              iconColor: C.pkD,
              iconBackground: C.pk.withValues(alpha: 0.12),
              title: isKorean ? '도안에디터로 새로 만들기' : 'Create in Pattern Editor',
              subtitle: isKorean
                  ? '차트 + 서술형을 직접 작성해요'
                  : 'Compose chart + narrative directly',
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.toolsPattern);
              },
            ),
            // ④ 래글런 샘플 도안 (이슈 #637 — 빌트인 레시피). #869 공통 위젯 + 핑크 톤 유지.
            ImportOptionTile(
              icon: Icons.checkroom_rounded,
              iconColor: C.pkD,
              iconBackground: C.pkD.withValues(alpha: 0.12),
              title: isKorean
                  ? '래글런 샘플 도안에서 시작'
                  : 'Start from Raglan Sample Pattern',
              subtitle: isKorean
                  ? 'Banul 크롭 레글런 탑다운 샘플 (7사이즈)'
                  : 'Banul Crop Raglan Topdown sample (7 sizes)',
              onTap: () async {
                Navigator.pop(context);
                await Future.microtask(() {});
                if (!mounted) return;
                await _startFromRaglanSample();
              },
            ),
              const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromPhone() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;
    final fileName = picked.name;
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'pdf' ? 'application/pdf' : ext == 'png' ? 'image/png' : 'image/jpeg';
    await _runParsing(bytes: bytes, fileName: fileName, mimeType: mimeType);
  }

  /// 이슈 #860 — 내 도안 라이브러리에서 PDF/이미지 가져오기.
  /// 공통 시트 [showMyPatternLibraryPickerSheet] 호출 → 다운로드 후 변환기로 전달.
  Future<void> _pickFromMyLibrary() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final picked = await showMyPatternLibraryPickerSheet(
      context,
      isKorean: isKorean,
    );
    if (picked == null || !mounted) return;
    final ext = picked.fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'png'
            ? 'image/png'
            : 'image/jpeg';
    await _runParsing(
      bytes: picked.bytes,
      fileName: picked.fileName,
      mimeType: mimeType,
    );
  }

  /// 이슈 #631 — 외부 클라우드 준비 중 카드 (탭 시 안내만).
  /// #869 — `ImportOptionTile` + `ComingSoonBadge` 공통 위젯 사용.
  Widget _buildComingSoonCloud(
    BuildContext context, {
    required bool isKorean,
    required String label,
    required IconData icon,
  }) {
    return ImportOptionTile(
      leftPadding: 16,
      icon: icon,
      iconColor: C.lv.withValues(alpha: 0.6),
      iconBackground: C.lv.withValues(alpha: 0.1),
      title: label,
      titleColor: C.mu,
      trailingBadge: ComingSoonBadge(isKorean: isKorean),
      showChevron: false,
      subtitle: isKorean
          ? '지원 예정 · 지금은 Dropbox를 이용해 주세요'
          : 'Planned · use Dropbox for now',
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean
                  ? '$label 연동은 곧 지원될 예정이에요.'
                  : '$label integration is coming soon.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  /// 이슈 #637 — 래글런 샘플 도안(빌트인 템플릿) → 실제 PatternChart 저장 → 에디터 진입.
  Future<void> _startFromRaglanSample() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);

    final sizeName = await _showRaglanSizePicker(context, isKorean);
    if (sizeName == null || !mounted) return;

    try {
      final saved = await runWithMoriLoadingDialog<PatternChart>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          // 1) 템플릿 + 사이즈 → PatternChart 빌드
          final chart = buildPatternChartFromRaglanTemplate(
            banulCropRaglanDk,
            sizeName,
            isKorean: isKorean,
          );

          // 2) 기본 저장 — id 발급 + aiSections/grid/narrativeText 저장
          final repo = ref.read(patternRepositoryProvider);
          final base = await repo.save(chart);

          // 3) repository.save()가 누락하는 필드(narrativeBlocks · repeatRegions ·
          //    knittingDirection · gauge · category 등)를 직접 Firestore merge로 보완.
          //    (raglan 샘플 도안은 이 필드들이 필수 — 누락 시 반복구간·게이지 정보가 사라짐)
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null || uid.isEmpty) {
            throw Exception(isKorean ? '로그인이 필요해요.' : 'Login required.');
          }
          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('pattern_charts')
              .doc(base.id);
          final full = chart.copyWith(id: base.id);
          await docRef.set({
            ...full.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return full;
        },
      );

      if (!mounted) return;
      showSavedSnackBar(
        messenger,
        message: isKorean ? '샘플 도안을 저장했어요.' : 'Sample pattern saved.',
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatternEditorScreen(patternId: saved.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showAiErrorFeedback(messenger, e, isKorean: isKorean);
    }
  }

  /// 이슈 #688 — raw 에러 노출 차단. [AiErrorMapper]로 분류 후 친화 메시지 표시.
  /// rate_limit 등 결제 한도 케이스에는 마이페이지(구독 카드) 이동 액션 추가.
  void _showAiErrorFeedback(
    ScaffoldMessengerState messenger,
    Object error, {
    required bool isKorean,
  }) {
    final info = AiErrorMapper.map(error, isKorean: isKorean);
    if (info.action == AiErrorAction.upgradeSubscription) {
      // 이슈 #714 — SnackBar는 루트 ScaffoldMessenger에 남아 화면 전환 후에도 잔존.
      // 다이얼로그로 전환: 현재 Navigator 스택에 push되어 페이지 pop 시 같이 사라짐.
      messenger.clearSnackBars();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isKorean ? 'AI 사용량 한도' : 'AI Usage Limit'),
          content: Text(info.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(isKorean ? '닫기' : 'Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                context.push(Routes.my);
              },
              child: Text(isKorean ? '구독하기' : 'Upgrade'),
            ),
          ],
        ),
      );
    } else {
      showSaveErrorSnackBar(messenger, message: info.message);
    }
  }

  /// 이슈 #637 — 래글런 사이즈 선택 다이얼로그.
  Future<String?> _showRaglanSizePicker(
    BuildContext ctx,
    bool isKorean,
  ) async {
    const tmpl = banulCropRaglanDk;
    return showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: C.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.bd,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isKorean ? '사이즈 선택' : 'Pick Size',
                  style: T.h3,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isKorean ? tmpl.nameKo : tmpl.nameEn,
                  style: T.caption.copyWith(color: C.mu, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final s in tmpl.sizes)
                        _RaglanSizeTile(
                          size: s,
                          common: tmpl.common,
                          isKorean: isKorean,
                          onTap: () => Navigator.pop(sheetCtx, s.name),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromDropbox() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final auth = ref.read(dropboxAuthProvider);
    if (!auth.isLoggedIn) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isKorean ? 'Dropbox 연결 필요' : 'Dropbox Required', style: T.h3),
          content: Text(
            isKorean ? 'Dropbox 연결 후 이용할 수 있어요.' : 'Please connect Dropbox first.',
            style: T.body.copyWith(color: C.tx2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(isKorean ? '닫기' : 'Close', style: TextStyle(color: C.mu)),
            ),
            TextButton(
              onPressed: () { Navigator.pop(dialogContext); context.push(Routes.dropbox); },
              child: Text(isKorean ? '연결하기' : 'Connect', style: TextStyle(color: C.lv, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    final selected = await Navigator.push<DropboxPickResult>(
      context,
      MaterialPageRoute(builder: (_) => DropboxPickerScreen(isKorean: isKorean)),
    );
    if (selected == null || !mounted) return;
    final ext = selected.fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'pdf' ? 'application/pdf' : ext == 'png' ? 'image/png' : 'image/jpeg';
    await _runParsing(bytes: selected.bytes, fileName: selected.fileName, mimeType: mimeType);
  }

  Future<void> _runParsing({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);

    // 파일 크기 제한 (10MB)
    const maxBytes = 10 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        messenger,
        message: isKorean
            ? '파일 크기가 너무 큽니다. 10MB 이하의 파일을 사용해 주세요.'
            : 'File too large. Please use a file under 10MB.',
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0;
      _stage = 1;
      _statusMessage = isKorean ? 'AI 서버 접속 중...' : 'Connecting to AI server...';
    });

    try {
      final repo = PatternConverterRepository();
      final savedChart = await repo.uploadAndParse(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            if (p < 0.5) {
              _stage = 1;
              _statusMessage = isKorean ? 'AI 서버 접속 중...' : 'Connecting to AI server...';
            } else if (p < 0.9) {
              _stage = 2;
              _statusMessage = isKorean ? 'AI가 도안을 분석하는 중...' : 'AI is analyzing...';
            } else if (p < 1.0) {
              _stage = 3;
              _statusMessage = isKorean ? 'AI 분석이 완료됐어요!' : 'AI analysis complete!';
            } else {
              _stage = 4;
              _statusMessage = isKorean ? '한글로 변환 중...' : 'Converting...';
            }
          });
        },
      );

      // 분석 완료 단계 잠깐 표시
      if (mounted) {
        setState(() {
          _stage = 3;
          _progress = 0.95;
          _statusMessage = isKorean ? 'AI 분석이 완료됐어요!' : 'AI analysis complete!';
        });
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(() {
          _stage = 4;
          _progress = 1.0;
          _statusMessage = isKorean ? '한글로 변환 중...' : 'Converting...';
        });
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiPatternEditScreen(
            unsavedChart: savedChart,
            onGoToLibrary: () => context.push(Routes.toolsMyParsedPatterns),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showAiErrorFeedback(messenger, e, isKorean: isKorean);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return AppShellScaffold(
      title: isKorean ? '도안 변환기' : 'Pattern Converter',
      subtitle: isKorean ? 'PDF/이미지 도안을 AI로 변환' : 'AI converts PDF/image patterns',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: C.lv.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: C.lv, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isKorean
                            ? 'AI 도안 변환기'
                            : 'AI Pattern Converter',
                        style: T.h3.copyWith(color: C.lv),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isKorean
                        ? 'PDF 또는 이미지로 된 뜨개 도안을\n단계별로 따라하기 쉽게 변환해 드려요.\n\n저작권 보호를 위해 앱 내에서만 볼 수 있어요.'
                        : 'Convert your knitting pattern PDF or image\ninto easy step-by-step instructions.\n\nFor copyright protection, only visible within the app.',
                    style: T.sm.copyWith(color: C.tx2, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SectionTitle(
                title: isKorean ? '지원 형식' : 'Supported Formats'),
            const SizedBox(height: 12),
            Row(
              children: [
                _FormatChip(
                    label: 'PDF', icon: Icons.picture_as_pdf),
                const SizedBox(width: 8),
                _FormatChip(
                    label: 'JPG', icon: Icons.image_rounded),
                const SizedBox(width: 8),
                _FormatChip(
                    label: 'PNG', icon: Icons.image_rounded),
              ],
            ),
            const SizedBox(height: 32),

            if (_isUploading)
              _UploadProgress(
                  progress: _progress,
                  message: _statusMessage,
                  stage: _stage)
            else
              _UploadButton(onTap: _showSourceSheet),

            const SizedBox(height: 32),

            // 변환된 도안 리스트 인라인 표시
            _InlinePatternList(isKorean: isKorean),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FormatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.lv.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: C.lvD),
          const SizedBox(width: 4),
          Text(label, style: T.caption.copyWith(color: C.lvD)),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: C.lv.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file_rounded, size: 48, color: C.lv),
            const SizedBox(height: 12),
            Text(
              '파일을 선택해 주세요',
              style: T.body
                  .copyWith(color: C.lv, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'PDF, JPG, PNG 지원',
              style: T.caption.copyWith(color: C.tx2),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  final double progress;
  final String message;
  final int stage; // 1=업로드, 2=AI분석, 3=분석완료, 4=변환중

  const _UploadProgress({
    required this.progress,
    required this.message,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('1', '업로드'),
      ('2', 'AI 분석'),
      ('3', '분석 완료'),
      ('4', '변환'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.lv.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // 단계 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < stages.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 1,
                      color: i + 1 <= stage ? C.lv : C.lv.withValues(alpha: 0.2),
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i + 1 <= stage ? C.lv : C.lv.withValues(alpha: 0.15),
                        border: Border.all(
                          color: i + 1 <= stage ? C.lv : C.lv.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: i + 1 < stage
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                stages[i].$1,
                                style: T.caption.copyWith(
                                  color: i + 1 == stage ? Colors.white : C.lv.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stages[i].$2,
                      style: T.caption.copyWith(
                        color: i + 1 <= stage ? C.lv : C.tx2,
                        fontWeight: i + 1 == stage ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // 단계별 아이콘/인디케이터
          if (stage == 3)
            Icon(Icons.check_circle_rounded, color: C.lv, size: 52)
          else
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: stage == 1 ? progress * 2 : null,
                    strokeWidth: 5,
                    backgroundColor: C.lv.withValues(alpha: 0.15),
                    color: C.lv,
                  ),
                  if (stage == 1)
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          Text(message, style: T.sm.copyWith(color: C.tx2), textAlign: TextAlign.center),

          // AI 분석 중 → 선형 프로그레스 바
          if (stage == 2) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: C.lv.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(C.lv),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: C.og.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.og.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: C.og),
                  const SizedBox(width: 5),
                  Text('도안 크기에 따라 최대 3분이 소요될 수 있어요.', style: T.caption.copyWith(color: C.og)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InlinePatternList extends ConsumerWidget {
  final bool isKorean;
  const _InlinePatternList({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(aiPatternsProvider);

    return patternsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (patterns) {
        if (patterns.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isKorean ? '변환된 도안' : 'Converted Patterns',
                  style: T.captionBold.copyWith(color: C.mu),
                ),
                Text(
                  '${patterns.length}개',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...patterns.map((p) => _PatternRow(
                  pattern: p,
                  isKorean: isKorean,
                  // #825 — 변환 결과 진입 통일: universal_pattern_viewer (도안 라이브러리와 동일 경로)
                  onTap: () => context.push('/pattern-view/${p.id}'),
                )),
          ],
        );
      },
    );
  }
}

class _PatternRow extends StatelessWidget {
  final PatternChart pattern;
  final bool isKorean;
  final VoidCallback onTap;

  const _PatternRow({required this.pattern, required this.isKorean, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sections = pattern.aiSections ?? [];
    final totalSteps = sections.fold<int>(0, (a, s) => a + s.steps.length);
    final done = sections.fold<int>(0, (a, s) => a + s.steps.where((st) => st.isCompleted).length);
    final pct = totalSteps == 0 ? 0 : (done / totalSteps * 100).toInt();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.description_rounded, color: C.lv, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pattern.title,
                      style: T.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${sections.length}섹션 · $totalSteps단계 · $pct% 완료',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.tx2, size: 18),
          ],
        ),
      ),
    );
  }
}

/// 이슈 #637 — 래글런 사이즈 선택 타일.
/// 사이즈 이름 + 가슴둘레·반복횟수·최종 몸통 코수 요약 표시.
class _RaglanSizeTile extends StatelessWidget {
  final RaglanSize size;
  final RaglanCommonSpec common;
  final bool isKorean;
  final VoidCallback onTap;

  const _RaglanSizeTile({
    required this.size,
    required this.common,
    required this.isKorean,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bodyTotal = size.bodyTotalStitches(common);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.pkD.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: C.pkD.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                size.name,
                style: T.bodyBold.copyWith(color: C.pkD),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isKorean
                        ? '가슴둘레 ${size.chestCm.toStringAsFixed(0)}cm · 길이 ${size.bodyLengthCm.toStringAsFixed(0)}cm'
                        : 'Chest ${size.chestCm.toStringAsFixed(0)}cm · Length ${size.bodyLengthCm.toStringAsFixed(0)}cm',
                    style: T.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isKorean
                        ? '래글런 늘림 ${size.raglanRepeat}회 · 몸통 $bodyTotal코'
                        : 'Raglan inc ${size.raglanRepeat}× · Body $bodyTotal st',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
          ],
        ),
      ),
    );
  }
}
