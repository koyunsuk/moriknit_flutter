import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/course_provider.dart';
import '../domain/course_item.dart';

String? _extractVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  }
  return uri.queryParameters['v'];
}

String _thumbnailUrl(String videoUrl) {
  final id = _extractVideoId(videoUrl);
  if (id == null) return '';
  return 'https://img.youtube.com/vi/$id/mqdefault.jpg';
}

class CourseScreen extends ConsumerStatefulWidget {
  const CourseScreen({super.key});

  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends ConsumerState<CourseScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final user = ref.watch(authStateProvider).valueOrNull;
    final coursesAsync = ref.watch(courseProvider);

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '클라스' : 'Class',
                subtitle: isKorean ? '유튜브 링크로 뜨개 강의를 모아두는 임시 보드예요.' : 'A temporary board for knitting lessons with YouTube links.',
              ),
            ),
            Expanded(
              child: coursesAsync.when(
                loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                error: (_, _) => _CourseFallback(isKorean: isKorean, canAdd: user != null, onAdd: () => _showCourseStartSheet(context, ref, isKorean)),
                data: (courses) {
                  if (courses.isEmpty) {
                    return _CourseFallback(isKorean: isKorean, canAdd: user != null, onAdd: () => _showCourseStartSheet(context, ref, isKorean));
                  }
                  final filtered = _query.isEmpty
                      ? courses
                      : courses.where((c) {
                          final q = _query.toLowerCase();
                          return c.title.toLowerCase().contains(q) ||
                              c.titleEn.toLowerCase().contains(q) ||
                              c.category.toLowerCase().contains(q);
                        }).toList();
                  final categories = filtered.map((c) => c.category).toSet().toList();
                  final sortedCourses = [...courses]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final recentCourse = sortedCourses.isNotEmpty ? sortedCourses.first : null;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      // 통계 카드
                      GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          isKorean
                              ? '전체 ${courses.length}개 클라스 · 카테고리 ${courses.map((c) => c.category).toSet().length}개'
                              : 'Total ${courses.length} classes · ${courses.map((c) => c.category).toSet().length} categories',
                          style: T.bodyBold.copyWith(color: C.lvD),
                        ),
                      ),
                      // 검색창
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: isKorean ? '강의 제목, 카테고리 검색' : 'Search classes',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () { _searchController.clear(); setState(() => _query = ''); },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.bd)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      if (filtered.isEmpty && _query.isNotEmpty)
                        Center(child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(isKorean ? '검색 결과가 없어요' : 'No results found', style: T.body.copyWith(color: C.mu)),
                        )),
                      // 최근 추가 하이라이트 카드 (대형 썸네일) — 검색 없을 때만
                      if (_query.isEmpty && recentCourse != null) ...[
                        Row(
                          children: [
                            Expanded(child: Text(isKorean ? '최근 강의' : 'Recent', style: T.h3.copyWith(color: C.lvD))),
                            if (user != null)
                              TextButton.icon(
                                onPressed: () => _showCourseStartSheet(context, ref, isKorean),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: Text(isKorean ? '새 강의 추가' : 'Add class'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _RecentCourseCard(
                          item: recentCourse,
                          isKorean: isKorean,
                          onTap: () => _openDetail(context, recentCourse, isKorean),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // 카테고리별 목록
                      ...categories.map((cat) {
                        final items = filtered.where((c) => c.category == cat).toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
                              child: Text(cat, style: T.h3.copyWith(color: C.lvD)),
                            ),
                            ...items.map((item) => _CourseTitleRow(
                              item: item,
                              isKorean: isKorean,
                              onTap: () => _openDetail(context, item, isKorean),
                            )),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, CourseItem item, bool isKorean) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourseDetailScreen(item: item, isKorean: isKorean),
    ));
  }

  Future<void> _showCourseStartSheet(BuildContext context, WidgetRef ref, bool isKorean) async {
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
                  decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(isKorean ? '클라스 추가' : 'Add class', style: T.h3),
              const SizedBox(height: 16),
              // 옵션 1: 유튜브에서 가져오기
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddClassSheet(context, ref, isKorean);
                },
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: C.lv.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.smart_display_rounded, color: C.lv),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isKorean ? '유튜브에서 가져오기' : 'From YouTube', style: T.bodyBold),
                      const SizedBox(height: 4),
                      Text(isKorean ? 'YouTube 링크로 강의를 추가해요' : 'Add class with YouTube link', style: T.caption.copyWith(color: C.mu)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              // 옵션 2: 내 동영상 직접 올리기
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadFile(context, ref, isKorean, FileType.video);
                },
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: C.og.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.video_file_rounded, color: C.og),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isKorean ? '내 동영상 직접 올리기' : 'Upload video file', style: T.bodyBold),
                      const SizedBox(height: 4),
                      Text(isKorean ? '내 모바일에 있는 동영상 파일을 올려요' : 'Pick a video from your device', style: T.caption.copyWith(color: C.mu)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.mu),
                ]),
              ),
              const SizedBox(height: 10),
              // 옵션 3: 녹음파일 올리기
              GlassCard(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadFile(context, ref, isKorean, FileType.audio);
                },
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: C.pk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.mic_rounded, color: C.pk),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isKorean ? '녹음파일 올리기' : 'Upload audio file', style: T.bodyBold),
                      const SizedBox(height: 4),
                      Text(isKorean ? '녹음 파일을 직접 업로드해요' : 'Pick an audio recording from your device', style: T.caption.copyWith(color: C.mu)),
                    ]),
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

  Future<void> _pickAndUploadFile(BuildContext context, WidgetRef ref, bool isKorean, FileType fileType) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(type: fileType);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    final path = file.path;
    if (bytes == null && path == null) return;
    if (!context.mounted) return;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final storageRef = FirebaseStorage.instance.ref().child('courses/${user.uid}/$fileName');

    try {
      String downloadUrl;
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '업로드하는 중입니다.' : 'Uploading...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          UploadTask uploadTask;
          if (bytes != null) {
            uploadTask = storageRef.putData(bytes);
          } else {
            uploadTask = storageRef.putData(await File(path!).readAsBytes());
          }
          final snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();
          final category = isKorean ? '입문' : 'Beginner';
          final mediaType = fileType == FileType.video ? 'video' : 'audio';
          final item = CourseItem(
            id: '',
            title: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
            description: '',
            videoUrl: downloadUrl,
            mediaType: mediaType,
            category: category,
            isPublished: true,
            createdAt: DateTime.now(),
          );
          await ref.read(courseRepositoryProvider).createCourse(item);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(context, message: isKorean ? '클라스가 등록됐어요.' : 'Class saved.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(context, message: '$e');
      }
    }
  }

  Future<void> _showAddClassSheet(BuildContext context, WidgetRef ref, bool isKorean) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String category = isKorean ? '입문' : 'Beginner';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? '클라스 추가' : 'Add class', style: T.h3),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(labelText: isKorean ? '강의 제목' : 'Class title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(labelText: isKorean ? '동영상 (유튜브 링크)' : 'Video (YouTube link)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                menuMaxHeight: 280,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  labelText: isKorean ? '분류' : 'Category',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.bd)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.bd)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: [
                  DropdownMenuItem(value: isKorean ? '입문' : 'Beginner', child: Text(isKorean ? '입문' : 'Beginner')),
                  DropdownMenuItem(value: isKorean ? '중급' : 'Intermediate', child: Text(isKorean ? '중급' : 'Intermediate')),
                  DropdownMenuItem(value: isKorean ? '고급' : 'Advanced', child: Text(isKorean ? '고급' : 'Advanced')),
                ],
                onChanged: (value) => setState(() => category = value ?? category),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) return;
                    final item = CourseItem(
                      id: '',
                      title: titleCtrl.text.trim(),
                      description: '',
                      videoUrl: urlCtrl.text.trim(),
                      mediaType: 'youtube',
                      category: category,
                      isPublished: true,
                      createdAt: DateTime.now(),
                    );
                    await runWithMoriLoadingDialog<void>(
                      ctx,
                      message: isKorean ? '저장하는 중입니다.' : 'Saving...',
                      subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                      task: () => ref.read(courseRepositoryProvider).createCourse(item),
                    );
                    if (ctx.mounted) {
                      showSavedSnackBar(ctx, message: isKorean ? '클라스가 등록됐어요.' : 'Class saved.');
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(isKorean ? '등록하기' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 최근 추가 대형 카드 ─────────────────────────────────────────────────────────
class _RecentCourseCard extends StatelessWidget {
  final CourseItem item;
  final bool isKorean;
  final VoidCallback onTap;

  const _RecentCourseCard({required this.item, required this.isKorean, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbnailUrl(item.videoUrl);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                  if (thumbUrl.isNotEmpty)
                    Image.network(
                      thumbUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _ThumbPlaceholder(height: 200),
                    )
                  else
                    _ThumbPlaceholder(height: 200),
                  // 재생 버튼 오버레이
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                  // 최근 추가 배지
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.lv,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isKorean ? '최근 추가' : 'Recently added',
                        style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
            // 정보
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: C.lvL,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(item.category, style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    isKorean ? item.title : (item.titleEn.isNotEmpty ? item.titleEn : item.title),
                    style: T.h3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.videoUrl.contains('firebasestorage.googleapis.com')
                        ? '모리니트 서버에 저장되었습니다.'
                        : item.videoUrl,
                    style: T.caption.copyWith(color: C.mu),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 강의 카드 (홈탭 스타일) ──────────────────────────────────────────────────
class _CourseTitleRow extends StatelessWidget {
  final CourseItem item;
  final bool isKorean;
  final VoidCallback onTap;

  const _CourseTitleRow({required this.item, required this.isKorean, required this.onTap});

  static String? _videoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return uri.queryParameters['v'];
  }

  static bool _isFirebaseUrl(String url) => url.contains('firebasestorage.googleapis.com');

  Color get _catColor {
    switch (item.category) {
      case '중급':
      case 'Intermediate':
        return C.pkD;
      case '고급':
      case 'Advanced':
        return C.og;
      default:
        return C.lvD;
    }
  }

  IconData get _mediaIcon {
    switch (item.mediaType) {
      case 'video': return Icons.play_circle_filled_rounded;
      case 'audio': return Icons.music_note_rounded;
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'file': return Icons.attach_file_rounded;
      default: return Icons.smart_display_rounded;
    }
  }

  Color get _mediaColor {
    switch (item.mediaType) {
      case 'video': return C.og;
      case 'audio': return C.pk;
      case 'pdf': return C.og;
      default: return C.lvD;
    }
  }

  String get _mediaLabel {
    switch (item.mediaType) {
      case 'video': return '동영상';
      case 'audio': return '음성';
      case 'pdf': return 'PDF';
      case 'file': return '파일';
      default: return '유튜브';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isKorean ? item.title : (item.titleEn.isNotEmpty ? item.titleEn : item.title);
    final videoId = _videoId(item.videoUrl);
    final thumbUrl = videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : '';
    final isFirebase = _isFirebaseUrl(item.videoUrl);
    final isAudio = item.mediaType == 'audio';
    final isVideo = item.mediaType == 'video';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.bd),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (thumbUrl.isNotEmpty)
                    Image.network(
                      thumbUrl,
                      width: 100,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Container(
                        width: 100, height: 70,
                        color: C.lvL,
                        child: Icon(isAudio ? Icons.music_note_rounded : Icons.play_circle_filled_rounded, color: C.lvD, size: 28),
                      ),
                    )
                  else
                    Container(
                      width: 100, height: 70,
                      color: isVideo ? C.og.withValues(alpha: 0.08) : C.lvL,
                      child: Icon(isAudio ? Icons.music_note_rounded : Icons.play_circle_filled_rounded, color: isAudio ? C.pk : C.lvD, size: 28),
                    ),
                  if (!isAudio)
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: _mediaColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_mediaIcon, size: 10, color: _mediaColor),
                            const SizedBox(width: 3),
                            Text(_mediaLabel, style: T.caption.copyWith(color: _mediaColor, fontWeight: FontWeight.w700, fontSize: 10)),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(item.category, style: T.caption.copyWith(color: _catColor, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: T.bodyBold, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (isFirebase) ...[
                      const SizedBox(height: 2),
                      Text('모리니트 서버에 저장되었습니다.', style: T.caption.copyWith(color: C.mu)),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}


// ── 썸네일 플레이스홀더 ────────────────────────────────────────────────────────
class _ThumbPlaceholder extends StatelessWidget {
  final double height;
  const _ThumbPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: C.lvD.withValues(alpha: 0.12),
      child: Icon(Icons.play_circle_outline_rounded, color: C.lvD, size: height * 0.4),
    );
  }
}

// ── 빈 상태 ────────────────────────────────────────────────────────────────────
class _CourseFallback extends StatelessWidget {
  final bool isKorean;
  final bool canAdd;
  final VoidCallback onAdd;

  const _CourseFallback({required this.isKorean, required this.canAdd, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.school_rounded, color: C.lvD, size: 32),
          ),
          const SizedBox(height: 14),
          Text(isKorean ? '아직 등록된 클라스가 없어요' : 'No classes yet', style: T.bodyBold),
          const SizedBox(height: 6),
          Text(
            isKorean ? '유튜브 링크를 붙여서 임시 강의 보드를 채울 수 있어요.' : 'You can fill this board with YouTube links for now.',
            style: T.caption.copyWith(color: C.mu),
          ),
          if (canAdd) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(isKorean ? '클라스 추가' : 'Add class'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 강의 세부 화면 ──────────────────────────────────────────────────────────────
class CourseDetailScreen extends ConsumerStatefulWidget {
  final CourseItem item;
  final bool isKorean;
  const CourseDetailScreen({super.key, required this.item, required this.isKorean});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  YoutubePlayerController? _controller;
  final _memoCtrl = TextEditingController();
  bool _memoLoading = false;
  bool _memoSaving = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    final videoId = _extractVideoId(widget.item.videoUrl);
    if (videoId != null && !kIsWeb) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }
    _loadMemo();
  }

  Future<void> _loadMemo() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || widget.item.id.isEmpty) return;
    _uid = user.uid;
    setState(() => _memoLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('course_memos')
          .doc('${user.uid}_${widget.item.id}')
          .get();
      if (snap.exists && mounted) {
        _memoCtrl.text = snap.data()?['memo'] as String? ?? '';
      }
    } finally {
      if (mounted) setState(() => _memoLoading = false);
    }
  }

  Future<void> _saveMemo() async {
    if (_uid == null || widget.item.id.isEmpty) return;
    setState(() => _memoSaving = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '저장하는 중입니다.',
        subtitle: '',
        task: () async {
          await FirebaseFirestore.instance
              .collection('course_memos')
              .doc('${_uid}_${widget.item.id}')
              .set({'memo': _memoCtrl.text.trim(), 'updatedAt': FieldValue.serverTimestamp()});
        },
      );
      if (mounted) {
        showSavedSnackBar(context, message: widget.isKorean ? '메모가 저장됐어요.' : 'Memo saved.');
      }
    } finally {
      if (mounted) setState(() => _memoSaving = false);
    }
  }

  Future<void> _showEditSheet(BuildContext context) async {
    final titleCtrl = TextEditingController(text: widget.item.title);
    final urlCtrl = TextEditingController(text: widget.item.videoUrl);
    String category = widget.item.category;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setLocalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isKorean ? '클라스 수정' : 'Edit class', style: T.h3),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(labelText: widget.isKorean ? '강의 제목' : 'Class title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(labelText: widget.isKorean ? '동영상 (유튜브 링크)' : 'Video (YouTube link)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                menuMaxHeight: 280,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  labelText: widget.isKorean ? '분류' : 'Category',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.bd)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.bd)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: [
                  DropdownMenuItem(value: widget.isKorean ? '입문' : 'Beginner', child: Text(widget.isKorean ? '입문' : 'Beginner')),
                  DropdownMenuItem(value: widget.isKorean ? '중급' : 'Intermediate', child: Text(widget.isKorean ? '중급' : 'Intermediate')),
                  DropdownMenuItem(value: widget.isKorean ? '고급' : 'Advanced', child: Text(widget.isKorean ? '고급' : 'Advanced')),
                ],
                onChanged: (value) => setLocalState(() => category = value ?? category),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final updated = CourseItem(
                      id: widget.item.id,
                      title: titleCtrl.text.trim(),
                      titleEn: widget.item.titleEn,
                      description: widget.item.description,
                      videoUrl: urlCtrl.text.trim(),
                      thumbnailUrl: widget.item.thumbnailUrl,
                      category: category,
                      order: widget.item.order,
                      isPublished: widget.item.isPublished,
                      createdAt: widget.item.createdAt,
                    );
                    await runWithMoriLoadingDialog<void>(
                      ctx,
                      message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
                      subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                      task: () => ref.read(courseRepositoryProvider).updateCourse(updated),
                    );
                    if (ctx.mounted) {
                      showSavedSnackBar(ctx, message: widget.isKorean ? '수정되었습니다.' : 'Updated.');
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(widget.isKorean ? '저장' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isKorean ? '클라스 삭제' : 'Delete class', style: T.h3),
        content: Text(
          widget.isKorean ? '"${widget.item.title}" 클라스를 삭제할까요?' : 'Delete "${widget.item.title}"?',
          style: T.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(widget.isKorean ? '취소' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        task: () async {
          await ref.read(courseRepositoryProvider).deleteCourse(widget.item.id);
        },
      );
      if (context.mounted) {
        showSavedSnackBar(context, message: widget.isKorean ? '삭제되었습니다.' : 'Deleted.');
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoId = _extractVideoId(widget.item.videoUrl);
    final thumbUrl = _thumbnailUrl(widget.item.videoUrl);

    Widget playerWidget;
    if (kIsWeb) {
      // 웹: 썸네일 + 외부 링크 버튼
      playerWidget = GestureDetector(
        onTap: () {
          if (videoId != null) {
            launchUrl(Uri.parse('https://www.youtube.com/embed/$videoId'), mode: LaunchMode.platformDefault);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (thumbUrl.isNotEmpty)
              Image.network(thumbUrl, width: double.infinity, height: 220, fit: BoxFit.cover)
            else
              Container(height: 220, color: Colors.black),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),
          ],
        ),
      );
    } else if (_controller != null) {
      playerWidget = YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
        ),
        builder: (ctx, player) => player,
      );
    } else {
      // Firebase Storage file — in-app playback
      final isAudio = widget.item.mediaType == 'audio';
      playerWidget = GestureDetector(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => _VideoPlayerDialog(
              url: widget.item.videoUrl,
              isAudio: isAudio,
              isKorean: widget.isKorean,
            ),
          );
        },
        child: Container(
          height: isAudio ? 120 : 220,
          decoration: BoxDecoration(
            color: isAudio ? C.pk.withValues(alpha: 0.08) : C.lvD.withValues(alpha: 0.08),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAudio ? Icons.music_note_rounded : Icons.play_circle_filled_rounded,
                color: isAudio ? C.pk : C.lvD,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                isAudio
                    ? (widget.isKorean ? '탭하여 음성 재생' : 'Tap to play audio')
                    : (widget.isKorean ? '탭하여 동영상 재생' : 'Tap to play video'),
                style: T.body.copyWith(color: isAudio ? C.pk : C.lvD),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isKorean ? '인앱 재생' : 'In-app playback',
                style: T.caption.copyWith(color: C.mu),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 플레이어 영역
            playerWidget,
            // 세부 내용 + 메모 (스크롤)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 뒤로가기 + 제목
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.isKorean
                              ? widget.item.title
                              : (widget.item.titleEn.isNotEmpty ? widget.item.titleEn : widget.item.title),
                          style: T.h3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: C.mu),
                        onSelected: (value) {
                          if (value == 'edit') _showEditSheet(context);
                          if (value == 'delete') _confirmDelete(context);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: C.lvD), const SizedBox(width: 8), Text(widget.isKorean ? '수정' : 'Edit')])),
                          PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), const SizedBox(width: 8), Text(widget.isKorean ? '삭제' : 'Delete', style: const TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(6)),
                          child: Text(widget.item.category, style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.item.videoUrl.contains('firebasestorage.googleapis.com')
                                ? '모리니트 서버에 저장되었습니다.'
                                : widget.item.videoUrl,
                            style: T.caption.copyWith(color: C.mu),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 28),
                  // 메모 섹션
                  Text(
                    widget.isKorean ? '나만의 메모' : 'My notes',
                    style: T.bodyBold.copyWith(color: C.lvD),
                  ),
                  const SizedBox(height: 8),
                  if (_memoLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    TextField(
                      controller: _memoCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: widget.isKorean ? '강의를 보면서 메모를 남겨보세요.' : 'Take notes while watching.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_uid != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _memoSaving ? null : _saveMemo,
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: Text(widget.isKorean ? '메모 저장' : 'Save notes'),
                        style: ElevatedButton.styleFrom(backgroundColor: C.lv, foregroundColor: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 인앱 동영상/음성 재생 다이얼로그 ──────────────────────────────────────────────
class _VideoPlayerDialog extends StatefulWidget {
  final String url;
  final bool isAudio;
  final bool isKorean;

  const _VideoPlayerDialog({
    required this.url,
    required this.isAudio,
    required this.isKorean,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    }).catchError((_) {
      if (mounted) setState(() => _hasError = true);
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // 닫기 버튼
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_hasError)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.isKorean ? '재생할 수 없습니다.' : 'Cannot play this file.',
                style: const TextStyle(color: Colors.white),
              ),
            )
          else if (!_initialized)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else ...[
            if (!widget.isAudio)
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Icon(Icons.music_note_rounded, color: C.pk, size: 64),
              ),
            // 컨트롤
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: C.lv,
                      bufferedColor: C.lv.withValues(alpha: 0.3),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_controller.value.position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      IconButton(
                        icon: Icon(
                          _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () {
                          _controller.value.isPlaying ? _controller.pause() : _controller.play();
                        },
                      ),
                      Text(
                        _formatDuration(_controller.value.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
          ),
        ),
      ),
    );
  }
}
