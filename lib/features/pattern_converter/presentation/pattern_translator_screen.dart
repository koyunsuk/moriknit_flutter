import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../dropbox/data/dropbox_auth_provider.dart';
import '../../dropbox/domain/dropbox_file_entry.dart';
import '../../../providers/dropbox_provider.dart';
import '../../../features/pattern/domain/pattern_chart.dart';
import '../../../providers/parsed_pattern_provider.dart';
import '../data/pattern_converter_repository.dart';
import 'ai_pattern_edit_screen.dart';

class PatternTranslatorScreen extends ConsumerStatefulWidget {
  final Uint8List? preloadedBytes;
  final String? preloadedFileName;
  final bool preloadedTranslateToKorean;

  const PatternTranslatorScreen({
    super.key,
    this.preloadedBytes,
    this.preloadedFileName,
    this.preloadedTranslateToKorean = true,
  });

  @override
  ConsumerState<PatternTranslatorScreen> createState() =>
      _PatternTranslatorScreenState();
}

class _PatternTranslatorScreenState
    extends ConsumerState<PatternTranslatorScreen> {
  bool _isUploading = false;
  double _progress = 0;
  int _stage = 1; // 1=업로드, 2=AI분석, 3=분석완료, 4=번역중
  String _statusMessage = '';
  String _currentFileName = '';

  @override
  void initState() {
    super.initState();
    if (widget.preloadedBytes != null && widget.preloadedFileName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = ScaffoldMessenger.of(context);
        final isKorean = ref.read(appLanguageProvider).isKorean;
        _runTranslate(
          bytes: widget.preloadedBytes!,
          fileName: widget.preloadedFileName!,
          messenger: messenger,
          isKorean: isKorean,
        );
      });
    }
  }

  // 소스 선택 bottom sheet
  Future<void> _showSourceSheet() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isKorean ? '파일 불러오기' : 'Import File',
                style: T.h3,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(12)),
                child: Icon(kIsWeb ? Icons.computer_rounded : Icons.smartphone_rounded, color: C.lvD, size: 22),
              ),
              title: Text(kIsWeb ? (isKorean ? '내 PC' : 'My PC') : (isKorean ? '내 핸드폰' : 'My Device'), style: T.bodyBold),
              subtitle: Text('PDF, JPG, PNG', style: T.caption.copyWith(color: C.mu)),
              trailing: Icon(Icons.chevron_right_rounded, color: C.mu),
              onTap: () {
                Navigator.pop(context);
                _pickFromPhone();
              },
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFF0061FF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.cloud_rounded, color: Color(0xFF0061FF), size: 22),
              ),
              title: Text('Dropbox', style: T.bodyBold),
              subtitle: Text(isKorean ? '드롭박스에서 파일 선택' : 'Pick from Dropbox', style: T.caption.copyWith(color: C.mu)),
              trailing: Icon(Icons.chevron_right_rounded, color: C.mu),
              onTap: () {
                Navigator.pop(context);
                _pickFromDropbox();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromPhone() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;

    await _runTranslate(bytes: bytes, fileName: picked.name, messenger: messenger, isKorean: isKorean);
  }

  Future<void> _pickFromDropbox() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final auth = ref.read(dropboxAuthProvider);
    if (!auth.isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isKorean ? 'Dropbox 연결 후 이용할 수 있어요.' : 'Please connect Dropbox first.'),
        action: SnackBarAction(
          label: isKorean ? '연결하기' : 'Connect',
          onPressed: () => context.push(Routes.dropbox),
        ),
      ));
      return;
    }

    final selected = await Navigator.push<DropboxPickResult>(
      context,
      MaterialPageRoute(builder: (_) => DropboxPickerScreen(isKorean: isKorean)),
    );
    if (selected == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await _runTranslate(bytes: selected.bytes, fileName: selected.fileName, messenger: messenger, isKorean: isKorean);
  }

  Future<void> _runTranslate({
    required Uint8List bytes,
    required String fileName,
    required ScaffoldMessengerState messenger,
    required bool isKorean,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'png'
            ? 'image/png'
            : 'image/jpeg';

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
      _currentFileName = fileName;
      _statusMessage = isKorean ? 'AI 서버 접속 중...' : 'Connecting to AI server...';
    });

    try {
      final repo = PatternConverterRepository();
      final savedChart = await repo.uploadAndParse(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        translateToKorean: true,
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
              _statusMessage = isKorean ? '한국어로 번역 중...' : 'Translating to Korean...';
            }
          });
        },
      );

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
          _statusMessage = isKorean ? '한국어로 번역 중...' : 'Translating to Korean...';
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
      final errMsg = e
          .toString()
          .split('\n')
          .first
          .replaceAll(RegExp(r'^\[firebase_functions/[^\]]+\]\s*'), '');
      showSaveErrorSnackBar(
        messenger,
        message: isKorean ? '오류가 발생했어요: $errMsg' : 'Error: $errMsg',
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => context.pop(),
        ),
        title: Text(
          isKorean ? 'AI 영문도안 번역기' : 'Pattern Translator',
          style: T.h3,
        ),
        backgroundColor: C.bg,
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
                          Icon(Icons.translate_rounded,
                              color: C.lv, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isKorean
                                ? 'AI 영문도안 번역기'
                                : 'AI Pattern Translator',
                            style: T.h3.copyWith(color: C.lv),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isKorean
                            ? 'Ravelry/Etsy 등 영문 도안을 한국어로 변환합니다.\n\n저작권 보호를 위해 앱 내에서만 볼 수 있어요.'
                            : 'Translate English knitting patterns from Ravelry/Etsy into Korean.\n\nFor copyright protection, only visible within the app.',
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
                  _TranslateProgress(
                      progress: _progress,
                      message: _statusMessage,
                      stage: _stage,
                      fileName: _currentFileName,
                      isKorean: isKorean)
                else
                  _UploadButton(onTap: _showSourceSheet, isKorean: isKorean),
                const SizedBox(height: 32),
                _InlineTranslatedList(isKorean: isKorean),
              ],
            ),
          ),
        ],
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
  final bool isKorean;
  const _UploadButton({required this.onTap, required this.isKorean});

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
            Icon(Icons.translate_rounded, size: 48, color: C.lv),
            const SizedBox(height: 12),
            Text(
              isKorean ? '영문 도안 파일을 선택해 주세요' : 'Select English pattern file',
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

class _TranslateProgress extends StatelessWidget {
  final double progress;
  final String message;
  final int stage; // 1=업로드, 2=AI분석, 3=분석완료, 4=번역중
  final String fileName;
  final bool isKorean;

  const _TranslateProgress({
    required this.progress,
    required this.message,
    required this.stage,
    required this.fileName,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('1', isKorean ? '업로드' : 'Upload'),
      ('2', isKorean ? 'AI 분석' : 'AI Analysis'),
      ('3', isKorean ? '분석 완료' : 'Done'),
      ('4', isKorean ? '번역' : 'Translate'),
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

          if (fileName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: C.lv.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file_rounded, size: 13, color: C.lv),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      fileName,
                      style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

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
                  Text(
                    isKorean
                        ? '도안 크기에 따라 최대 3분이 소요될 수 있어요.'
                        : 'May take up to 3 minutes depending on pattern size.',
                    style: T.caption.copyWith(color: C.og),
                  ),
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

// ── 번역된 도안 목록 ────────────────────────────────────────────────────────────
class _InlineTranslatedList extends ConsumerWidget {
  final bool isKorean;
  const _InlineTranslatedList({required this.isKorean});

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
                Text(isKorean ? '번역된 도안' : 'Translated Patterns', style: T.captionBold.copyWith(color: C.mu)),
                Text('${patterns.length}개', style: T.caption.copyWith(color: C.mu)),
              ],
            ),
            const SizedBox(height: 10),
            ...patterns.map((p) {
              final sections = p.aiSections ?? [];
              final totalSteps = sections.fold<int>(0, (a, s) => a + s.steps.length);
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AiPatternEditScreen(patternId: p.id),
                  )),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.translate_rounded, color: C.lvD, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, style: T.sm.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(isKorean ? '$totalSteps 단계' : '$totalSteps steps', style: T.caption.copyWith(color: C.mu)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── Dropbox 파일 선택 결과 ────────────────────────────────────────────────────
class DropboxPickResult {
  final Uint8List bytes;
  final String fileName;
  const DropboxPickResult({required this.bytes, required this.fileName});
}

// ── Dropbox 파일 피커 화면 ────────────────────────────────────────────────────
final _dropboxPickerFolderProvider = FutureProvider.family<List<DropboxFileEntry>, String>(
  (ref, path) => ref.watch(dropboxApiClientProvider).listFolder(path),
);

class DropboxPickerScreen extends ConsumerStatefulWidget {
  final bool isKorean;
  const DropboxPickerScreen({required this.isKorean});

  @override
  ConsumerState<DropboxPickerScreen> createState() => DropboxPickerScreenState();
}

class DropboxPickerScreenState extends ConsumerState<DropboxPickerScreen> {
  final List<String> _pathStack = [''];
  String get _currentPath => _pathStack.last;

  static const Color _blue = Color(0xFF0061FF);

  static bool _isSupported(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.pdf') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png');
  }

  Future<void> _selectFile(DropboxFileEntry entry) async {
    try {
      final bytes = await runWithMoriLoadingDialog<Uint8List>(
        context,
        message: widget.isKorean ? '파일을 불러오는 중입니다.' : 'Loading file...',
        subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref.read(dropboxApiClientProvider).downloadFile(entry.path),
      );
      if (!mounted) return;
      Navigator.pop(context, DropboxPickResult(bytes: bytes, fileName: entry.name));
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(_dropboxPickerFolderProvider(_currentPath));
    final displayPath = _pathStack.length == 1 ? '/' : _currentPath;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () {
            if (_pathStack.length > 1) {
              setState(() => _pathStack.removeLast());
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dropbox', style: T.h3),
            Text(displayPath, style: T.caption.copyWith(color: C.mu, fontSize: 11), overflow: TextOverflow.ellipsis),
          ],
        ),
        backgroundColor: C.bg,
        elevation: 0,
      ),
      body: entriesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: _blue)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: C.og, size: 40),
              const SizedBox(height: 12),
              Text('$e', style: T.caption.copyWith(color: C.og), textAlign: TextAlign.center, maxLines: 4),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(_dropboxPickerFolderProvider(_currentPath)),
                child: Text(widget.isKorean ? '다시 시도' : 'Retry'),
              ),
            ],
          ),
        ),
        data: (entries) => entries.isEmpty
            ? Center(child: Text(widget.isKorean ? '이 폴더는 비어 있어요.' : 'This folder is empty.', style: T.body.copyWith(color: C.mu)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entries.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: C.bd),
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final supported = !e.isFolder && _isSupported(e.name);
                  final color = e.isFolder ? C.pk : supported ? C.lv : C.mu;
                  return ListTile(
                    enabled: e.isFolder || supported,
                    leading: Icon(
                      e.isFolder ? Icons.folder_rounded : e.name.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      color: color, size: 26,
                    ),
                    title: Text(e.name, style: T.body.copyWith(fontSize: 14, color: e.isFolder || supported ? C.tx : C.mu)),
                    subtitle: e.isFolder
                        ? Text(widget.isKorean ? '폴더' : 'Folder', style: T.caption.copyWith(color: C.mu))
                        : Text(supported ? 'PDF / JPG / PNG' : widget.isKorean ? '지원하지 않는 형식' : 'Unsupported', style: T.caption.copyWith(color: C.mu)),
                    trailing: e.isFolder ? Icon(Icons.chevron_right_rounded, color: C.mu) : null,
                    onTap: e.isFolder
                        ? () => setState(() => _pathStack.add(e.path))
                        : supported ? () => _selectFile(e) : null,
                  );
                },
              ),
      ),
    );
  }
}
