import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../ravelry/data/ravelry_auth_provider.dart';
import '../../ravelry/data/ravelry_repository.dart';
import '../../ravelry/domain/ravelry_models.dart';
import '../data/pattern_repository.dart';
import '../domain/pattern_chart.dart';
import 'pattern_detail_screen.dart';

class PatternListScreen extends ConsumerWidget {
  const PatternListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final patternsAsync = ref.watch(patternListProvider);

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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  // 도안 요약 카드 (MoriKnit + Ravelry 뱃지)
                  GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: C.pk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                child: Text('MoriKnit', style: T.caption.copyWith(color: C.pkD, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 4),
                              patternsAsync.maybeWhen(
                                data: (patterns) => Text('${patterns.length}', style: T.h3.copyWith(color: C.pkD)),
                                orElse: () => Text('-', style: T.h3.copyWith(color: C.pkD)),
                              ),
                              Text(isKorean ? '내 도안' : 'My patterns', style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 40, color: C.bd),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                child: Text('Ravelry', style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 4),
                              Consumer(
                                builder: (ctx, ref, _) {
                                  final libraryAsync = ref.watch(ravelryLibraryProvider);
                                  return Text(
                                    libraryAsync.maybeWhen(data: (p) => '${p.length}', orElse: () => '-'),
                                    style: T.h3.copyWith(color: C.lv),
                                  );
                                },
                              ),
                              Text(isKorean ? '라이브러리' : 'Library', style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 모리니트 도안 라이브러리
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: C.pk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text('MoriKnit', style: T.caption.copyWith(color: C.pkD, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(isKorean ? '📄 나의 도안' : '📄 My Patterns', style: T.bodyBold),
                          ],
                        ),
                        const SizedBox(height: 12),
                        patternsAsync.when(
                      loading: () => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(color: C.lv),
                        ),
                      ),
                      error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                      data: (patterns) {
                        if (patterns.isEmpty) {
                          return MoriEmptyState(
                            icon: Icons.grid_on_rounded,
                            iconColor: C.lvD,
                            title: isKorean ? '아직 도안이 없어요' : 'No patterns yet',
                            subtitle: isKorean ? '나만의 도안을 만들어보세요.' : 'Create your own pattern.',
                            buttonLabel: isKorean ? '새 도안 만들기' : 'Create new',
                            onAction: () => _showPatternStartSheet(context, ref),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isKorean ? '내 도안 ${patterns.length}개' : '${patterns.length} patterns',
                                    style: T.bodyBold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showPatternStartSheet(context, ref),
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(isKorean ? '새 도안' : 'New pattern'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...patterns.map((p) => _PatternRow(
                              chart: p,
                              isKorean: isKorean,
                              onTap: () => _openPattern(context, p),
                            )),
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

  void _openPattern(BuildContext context, PatternChart chart) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PatternDetailScreen(chart: chart),
    ));
  }

  Future<void> _showImageSourceDialog(BuildContext context, WidgetRef ref, bool isKorean) async {
    if (kIsWeb) {
      showSavedSnackBar(context, message: isKorean ? '모바일에서만 사용 가능해요.' : 'Available on mobile only.');
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
                  final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (picked != null && context.mounted) {
                    await _saveImageFile(context, ref, File(picked.path), isKorean);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: C.lv),
                title: Text(isKorean ? '갤러리에서 선택' : 'Choose from gallery', style: T.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (picked != null && context.mounted) {
                    await _saveImageFile(context, ref, File(picked.path), isKorean);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveImageFile(BuildContext context, WidgetRef ref, File file, bool isKorean) async {
    // async gap 이전에 repo 캡처 → ref가 disposed된 이후 접근 방지
    final repo = ref.read(patternRepositoryProvider);
    final title = await _askPatternTitle(context, isKorean);
    if (title == null || !context.mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repo.saveImagePattern(title: title, imageFile: file),
      );
      if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '저장됐어요.' : 'Saved.');
    } catch (e) {
      if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<void> _savePdfFile(BuildContext context, WidgetRef ref, File file, bool isKorean) async {
    // async gap 이전에 repo 캡처 → ref가 disposed된 이후 접근 방지
    final repo = ref.read(patternRepositoryProvider);
    final title = await _askPatternTitle(context, isKorean);
    if (title == null || !context.mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => repo.savePdfPattern(title: title, pdfFile: file),
      );
      if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: isKorean ? '저장됐어요.' : 'Saved.');
    } catch (e) {
      if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  Future<String?> _askPatternTitle(BuildContext context, bool isKorean) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isKorean ? '도안 이름' : 'Pattern name', style: T.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isKorean ? '도안 이름을 입력하세요' : 'Enter pattern name',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim().isEmpty ? (isKorean ? '내 도안' : 'My Pattern') : v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(ctx, v.isEmpty ? (isKorean ? '내 도안' : 'My Pattern') : v);
            },
            child: Text(isKorean ? '등록' : 'Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _showPatternStartSheet(BuildContext context, WidgetRef ref) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final scrollCtrl = ScrollController();
        return Padding(
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
              const SizedBox(height: 16),
              // 1. 사진에서 만들기
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  _showImageSourceDialog(context, ref, isKorean);
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
                        Text(
                          isKorean ? '사진에서 만들기' : 'From photo',
                          style: T.bodyBold,
                        ),
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
              // 2. PDF에서 만들기
              GlassCard(
                onTap: () async {
                  Navigator.pop(ctx);
                  if (kIsWeb) {
                    showSavedSnackBar(context, message: isKorean ? '모바일에서만 사용 가능해요.' : 'Available on mobile only.');
                    return;
                  }
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );
                  if (result != null && result.files.first.path != null && context.mounted) {
                    await _savePdfFile(context, ref, File(result.files.first.path!), isKorean);
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
                        Text(
                          isKorean ? 'PDF에서 만들기' : 'From PDF',
                          style: T.bodyBold,
                        ),
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
              // 3. 도안에디터로 만들기 (신규)
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(Routes.toolsPattern);
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
                          isKorean ? '모리앱 도안 에디터로 직접 만들어요' : 'Draw directly with MoriKnit editor',
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

}

class _PatternRow extends StatelessWidget {
  final PatternChart chart;
  final bool isKorean;
  final VoidCallback onTap;
  const _PatternRow({required this.chart, required this.isKorean, required this.onTap});

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

  @override
  Widget build(BuildContext context) {
    return MoriLibraryCard(
      title: chart.title,
      subtitle1: _subtitleText(isKorean),
      thumbnailUrl: chart.type == PatternType.image && chart.imageUrl.isNotEmpty ? chart.imageUrl : null,
      fallbackIcon: _typeIcon,
      fallbackIconBg: _iconBgColor.withValues(alpha: 0.12),
      fallbackIconColor: _iconBgColor,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
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

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text('Ravelry', style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(isKorean ? '📚 나의 도안 라이브러리' : '📚 My Pattern Library', style: T.bodyBold),
            ],
          ),
          const SizedBox(height: 12),
          if (!auth.isLoggedIn)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, color: C.lv, size: 20),
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
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (e, _) => Text(isKorean ? '도안을 불러올 수 없어요: $e' : 'Failed to load: $e',
          style: T.caption.copyWith(color: C.og)),
      data: (patterns) {
        if (patterns.isEmpty) {
          return Text(isKorean ? 'Ravelry 도안 라이브러리가 비어있어요.' : 'Your Ravelry library is empty.',
              style: T.body.copyWith(color: C.mu));
        }
        return Column(
          children: patterns.map((p) => _RavelryPatternCard(pattern: p, isKorean: isKorean)).toList(),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: C.lvL,
                      borderRadius: BorderRadius.circular(12),
                      image: pattern.thumbnailUrl != null
                          ? DecorationImage(image: NetworkImage(pattern.thumbnailUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: pattern.thumbnailUrl == null ? Icon(Icons.menu_book_rounded, color: C.lvD, size: 28) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pattern.name, style: T.h3),
                        if (pattern.authorName != null)
                          Text(pattern.authorName!, style: T.caption.copyWith(color: C.mu)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pattern.categories.isNotEmpty) ...[
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: pattern.categories.map((cat) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(cat, style: T.caption.copyWith(color: C.lv)),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (pattern.craft != null)
                _DetailRow(label: isKorean ? '공예' : 'Craft', value: pattern.craft!),
              if (pattern.difficultyAverage != null)
                _DetailRow(
                  label: isKorean ? '난이도' : 'Difficulty',
                  value: pattern.difficultyAverage!.toStringAsFixed(1),
                ),
              _DetailRow(
                label: isKorean ? '가격' : 'Price',
                value: pattern.isFree ? (isKorean ? '무료' : 'Free') : '\$${pattern.price?.toStringAsFixed(2) ?? '-'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: T.caption.copyWith(color: C.mu)),
          const Spacer(),
          Text(value, style: T.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
