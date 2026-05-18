import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/async_loading_state.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/memo_lock_provider.dart';
import '../../../providers/memo_provider.dart';
import '../domain/memo_model.dart';
import 'widgets/memo_drawing_canvas.dart';

// ── Hive 마이그레이션 ─────────────────────────────────────
const _hiveBoxName = 'tool_memo_box_v2';
const _hiveListKey = 'memos';

Future<void> migrateMemoFromHiveIfNeeded(WidgetRef ref) async {
  if (kIsWeb) return;
  try {
    final prefs = await _MigrationPrefs.load();
    if (prefs) return; // 이미 마이그레이션 완료

    final box = await Hive.openBox(_hiveBoxName);
    final raw = box.get(_hiveListKey);
    if (raw is List && raw.isNotEmpty) {
      final items = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      await ref.read(memoRepositoryProvider).migrateFromHive(items);
    }
    await box.delete(_hiveListKey);
    await box.close();
    await _MigrationPrefs.markDone();
  } catch (e) {
    debugPrint('[ToolMemo] Hive 마이그레이션 오류: $e');
  }
}

class _MigrationPrefs {
  static bool _done = false;
  static Future<bool> load() async => _done;
  static Future<void> markDone() async => _done = true;
}

// ── 메인 화면 ─────────────────────────────────────────────
class ToolMemoScreen extends ConsumerStatefulWidget {
  const ToolMemoScreen({super.key});

  @override
  ConsumerState<ToolMemoScreen> createState() => _ToolMemoScreenState();
}

class _ToolMemoScreenState extends ConsumerState<ToolMemoScreen> {
  bool _migrated = false;
  bool _isLocked = false;
  bool _lockChecked = false;
  int _tabIndex = 0; // 0=전체, 1=사진, 2=음성
  bool _isRecording = false;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentPlayingUrl;

  @override
  void initState() {
    super.initState();
    _runMigration();
  }

  Future<void> _runMigration() async {
    await migrateMemoFromHiveIfNeeded(ref);
    if (mounted) setState(() => _migrated = true);
    await _checkLock();
  }

  Future<void> _checkLock() async {
    // SharedPreferences에서 직접 읽어 비동기 초기화 타이밍 문제 회피
    final hasPin = await ref.read(memoLockProvider.notifier).hasPin();
    final isEnabled = await ref.read(memoLockProvider.notifier).isEnabled();
    if (mounted) {
      setState(() {
        _isLocked = isEnabled && hasPin;
        _lockChecked = true;
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _openEditor({MemoModel? existing}) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MemoEditScreen(
          initial: existing,
          uid: uid,
        ),
      ),
    );
  }

  // ── 음성 녹음 토글 ─────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null || !mounted) return;
      final scaffoldMsg = ScaffoldMessenger.of(context);
      try {
        // dart:io — 웹에서는 path_provider + recorder 자체가 불가하므로 모바일 전용
        final bytes = await _readVoiceBytes(path);
        if (bytes == null || bytes.isEmpty) return;
        if (!mounted) return;
        final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
        final memo = MemoModel.empty(uid: uid);
        await runWithMoriLoadingDialog<void>(
          context,
          message: '음성 메모를 저장하는 중입니다.',
          subtitle: '잠시만 기다려 주세요.',
          task: () async {
            await ref
                .read(memoNotifierProvider.notifier)
                .createVoiceMemo(memo, bytes);
          },
        );
        if (!mounted) return;
        showSavedSnackBar(scaffoldMsg, message: '음성 메모가 저장됐어요.');
      } catch (e) {
        if (!mounted) return;
        showSaveErrorSnackBar(scaffoldMsg, message: '$e');
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('마이크 권한이 필요합니다')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  /// 녹음 파일을 bytes로 읽습니다 (모바일 전용 — 웹은 null 반환).
  Future<Uint8List?> _readVoiceBytes(String path) async {
    if (kIsWeb) return null;
    try {
      // ignore: avoid_dynamic_calls
      return await _readIoFile(path);
    } catch (e) {
      debugPrint('[ToolMemo] 음성 파일 읽기 실패: $e');
      return null;
    }
  }

  Future<Uint8List> _readIoFile(String path) => io.File(path).readAsBytes();

  // ── 음성 재생 토글 ─────────────────────────────────────────
  Future<void> _togglePlayback(String url) async {
    if (_currentPlayingUrl == url) {
      await _audioPlayer.stop();
      setState(() => _currentPlayingUrl = null);
    } else {
      setState(() => _currentPlayingUrl = url);
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _currentPlayingUrl = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(memoListProvider);

    return AppShellScaffold(
      title: '나만의 메모장',
      subtitle: '도안, 재료, 아이디어를 자유롭게 기록해요',
      showBgOrbs: false,
      // 즐겨찾기 ⭐ 자동 prepend (이슈 #723 Phase B)
      favoriteScreenId: 'tools_memo',
      favoriteTitle: '메모장',
      favoriteIcon: Icons.sticky_note_2_rounded,
      favoritePath: Routes.toolsMemo,
      favoriteAccent: C.og,
      favoriteIsKorean: true,
      body: !_migrated || !_lockChecked
          ? Center(child: CircularProgressIndicator(color: C.lv))
          : _isLocked
              ? _buildLockScreen()
              : memosAsync.when(
                  loading: () => AsyncLoadingFriendly(
                    isKorean: true,
                    onRetry: () => ref.invalidate(memoListProvider),
                  ),
                  error: (e, _) => AsyncDelayedFriendly(
                    isKorean: true,
                    onRetry: () => ref.invalidate(memoListProvider),
                  ),
                  data: (memos) => _buildList(memos),
                ),
    );
  }

  final _lockPinCtrl = TextEditingController();
  String _lockError = '';

  Widget _buildLockScreen() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(32, 32, 32, 32 + bottom),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.lock_rounded, color: C.lv, size: 36),
            ),
            const SizedBox(height: 20),
            Text('메모장 잠금', style: T.h3),
            const SizedBox(height: 8),
            Text('PIN을 입력해주세요', style: T.body.copyWith(color: C.mu)),
            const SizedBox(height: 20),
            TextField(
              controller: _lockPinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: T.h3,
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
                filled: true,
              ),
            ),
            if (_lockError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_lockError, style: T.caption.copyWith(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  final ok = await ref.read(memoLockProvider.notifier).verifyPin(_lockPinCtrl.text);
                  if (ok) {
                    _lockPinCtrl.clear();
                    setState(() { _isLocked = false; _lockError = ''; });
                  } else {
                    _lockPinCtrl.clear();
                    setState(() => _lockError = '잘못된 PIN입니다. 다시 시도해주세요.');
                  }
                },
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      );
  }

  Future<void> _toggleLock(bool currentlyEnabled) async {
    if (currentlyEnabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('잠금 해제'),
          content: const Text('메모장 잠금을 해제할까요? PIN도 함께 삭제됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('해제'),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await ref.read(memoLockProvider.notifier).clearPin();
      }
    } else {
      await _showSetPinDialog();
    }
  }

  Future<void> _showSetPinDialog() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN 설정'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PIN (4-6자리)'),
                validator: (v) =>
                    (v == null || v.length < 4) ? '4자리 이상 입력해주세요' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PIN 확인'),
                validator: (v) =>
                    v != pinCtrl.text ? 'PIN이 일치하지 않아요' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await ref.read(memoLockProvider.notifier).setPin(pinCtrl.text);
              await ref.read(memoLockProvider.notifier).setEnabled(true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  static const _tabLabels = ['전체', '사진', '음성'];

  Widget _buildList(List<MemoModel> memos) {
    // 탭 필터 적용
    final filtered = _tabIndex == 1
        ? memos.where((m) => m.imageUrls.isNotEmpty).toList()
        : _tabIndex == 2
            ? memos.where((m) => m.voiceUrl != null).toList()
            : memos;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        // ── 요약 카드 ────────────────────────────────────────
        SummaryCard_Detail(
          headers: const ['전체', '사진', '음성'],
          rows: [
            LibrarySummaryRowData(
              badge: '메모',
              badgeColor: C.pkD,
              values: [
                '${memos.length}',
                '${memos.where((m) => m.imageUrls.isNotEmpty).length}',
                '${memos.where((m) => m.voiceUrl != null).length}',
              ],
              valueColors: [C.tx, C.lv, C.og],
            ),
          ],
          addLabel: '추가',
          onAdd: () => _openEditor(),
        ),
        const SizedBox(height: 12),

        // ── 탭 필터 ──────────────────────────────────────────
        Row(
          children: [
            for (int i = 0; i < _tabLabels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _tabIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _tabIndex == i ? C.lv : C.lvL,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tabLabels[i],
                      style: T.caption.copyWith(
                        color: _tabIndex == i ? Colors.white : C.lvD,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 잠금 설정 ────────────────────────────────────────
        GlassCard(
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: C.lvL, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.lock_outline_rounded, color: C.lvD, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('메모장 잠금', style: T.bodyBold),
                    Text('앱 시작 시 PIN으로 잠궈요',
                        style: T.caption.copyWith(color: C.mu)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleLock(ref.read(memoLockProvider)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ref.watch(memoLockProvider) ? C.lv : C.lvL,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ref.watch(memoLockProvider) ? '잠금 ON' : '잠금 OFF',
                    style: T.caption.copyWith(
                      color:
                          ref.watch(memoLockProvider) ? Colors.white : C.lvD,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 메모 목록 ────────────────────────────────────────
        // 사용자 보고 (#618) — 빈 상태에서도 음성 녹음 버튼 노출되어야 함.
        // 헤더(녹음+새 메모)를 항상 표시하고 본문만 빈 상태/리스트로 분기.
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('메모 목록', style: T.bodyBold)),
                  // 음성 녹음 버튼 (모바일 전용) — 빈 상태에서도 항상 표시
                  if (!kIsWeb)
                    IconButton(
                      icon: Icon(
                        _isRecording
                            ? Icons.stop_circle_rounded
                            : Icons.mic_rounded,
                        color: _isRecording ? C.og : C.lv,
                      ),
                      onPressed: _toggleRecording,
                      tooltip: _isRecording ? '녹음 중지' : '음성 녹음',
                    ),
                  // '+ 새 메모' 버튼은 상단 SummaryCard_Detail "추가" 버튼과 중복 — 제거 (이슈 #743)
                ],
              ),
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.fiber_manual_record, color: C.og, size: 12),
                      const SizedBox(width: 6),
                      Text('녹음 중...', style: T.caption.copyWith(color: C.og)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                MoriEmptyState(
                  icon: _tabIndex == 2
                      ? Icons.mic_outlined
                      : Icons.edit_note_rounded,
                  iconColor: C.pk,
                  title: _tabIndex == 0
                      ? '아직 메모가 없어요'
                      : (_tabIndex == 2
                          ? '음성 메모가 없어요'
                          : '해당 메모가 없어요'),
                  subtitle: _tabIndex == 2 && !kIsWeb
                      ? '위 🎤 버튼을 눌러서 음성을 녹음할 수 있어요.'
                      : (_tabIndex == 0
                          ? '생각을 자유롭게 기록해보세요.'
                          : '다른 탭을 확인해보세요.'),
                  buttonLabel: _tabIndex == 0 ? '첫 메모 작성하기' : null,
                  onAction: _tabIndex == 0 ? () => _openEditor() : null,
                )
              else
                ...filtered.map((memo) => _MemoListTile(
                      memo: memo,
                      isPlaying: _currentPlayingUrl == memo.voiceUrl,
                      onTap: () => _openEditor(existing: memo),
                      onPlayVoice: memo.voiceUrl != null
                          ? () => _togglePlayback(memo.voiceUrl!)
                          : null,
                    )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 목록 타일 ─────────────────────────────────────────────
class _MemoListTile extends StatelessWidget {
  final MemoModel memo;
  final VoidCallback onTap;
  final VoidCallback? onPlayVoice;
  final bool isPlaying;

  const _MemoListTile({
    required this.memo,
    required this.onTap,
    this.onPlayVoice,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final firstLine = memo.content
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final dateStr = DateFormat('yyyy.MM.dd').format(memo.createdAt);
    final firstImageUrl = memo.imageUrls.isNotEmpty ? memo.imageUrls.first : null;
    final hasVoice = memo.voiceUrl != null;

    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: hasVoice
                ? GestureDetector(
                    onTap: onPlayVoice,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? C.og.withValues(alpha: 0.15)
                            : C.lvL,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: isPlaying ? C.og : C.lv,
                        size: 28,
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: firstImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: firstImageUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _noImageBox(),
                          )
                        : _noImageBox(),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasVoice) ...[
                      Icon(Icons.mic_rounded, size: 14, color: C.og),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        hasVoice
                            ? '음성 메모'
                            : (firstLine.isEmpty ? '(내용 없음)' : firstLine),
                        style: T.bodyBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }

  Widget _noImageBox() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
            color: C.pkL, borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.edit_note_rounded, color: C.pkD, size: 24),
      );
}

// ── 편집 화면 ─────────────────────────────────────────────
class _MemoEditScreen extends ConsumerStatefulWidget {
  final MemoModel? initial;
  final String uid;

  const _MemoEditScreen({this.initial, required this.uid});

  @override
  ConsumerState<_MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends ConsumerState<_MemoEditScreen> {
  late final TextEditingController _controller;

  /// 기존 Storage URL 목록 (수정 시 유지할 항목)
  late List<String> _existingUrls;

  /// 새로 선택한 이미지 bytes (웹/모바일 공통)
  final List<Uint8List> _newImageBytes = [];

  /// 미리보기용 (새 이미지)
  final List<Uint8List> _newImagePreviews = [];

  bool _saving = false;

  // ── 음성 녹음 (모바일 전용) ──────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.content ?? '');
    _existingUrls = List<String>.from(widget.initial?.imageUrls ?? []);
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 86);
    if (picked.isEmpty) return;
    final remaining = 6 - _existingUrls.length - _newImageBytes.length;
    final toAdd = picked.take(remaining < 0 ? 0 : remaining).toList();
    for (final xFile in toAdd) {
      final bytes = await xFile.readAsBytes();
      if (!mounted) break;
      setState(() {
        _newImageBytes.add(bytes);
        _newImagePreviews.add(bytes);
      });
    }
  }

  /// 그리기 캔버스 모달을 열어 PNG bytes 받아 사진 목록에 추가
  Future<void> _addDrawing() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => const MemoDrawingCanvas(),
        fullscreenDialog: true,
      ),
    );
    if (bytes == null || !mounted) return;
    final remaining = 6 - _existingUrls.length - _newImageBytes.length;
    if (remaining <= 0) return;
    setState(() {
      _newImageBytes.add(bytes);
      _newImagePreviews.add(bytes);
    });
  }

  /// 음성 녹음 토글 — 완료 시 voiceUrl 업데이트 저장
  Future<void> _toggleRecording() async {
    if (kIsWeb) return;
    final scaffoldMsg = ScaffoldMessenger.of(context);

    if (_isRecording) {
      // 정지
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (path == null) return;

      try {
        final bytes = await _readVoiceBytes(path);
        if (bytes == null || bytes.isEmpty) return;
        if (!mounted) return;
        await _saveVoiceToMemo(bytes);
      } catch (e) {
        if (!mounted) return;
        showSaveErrorSnackBar(scaffoldMsg, message: '$e');
      }
      return;
    }

    // 시작 전: 기존 voiceUrl이 있으면 덮어쓰기 확인
    final hasExistingVoice = (widget.initial?.voiceUrl != null);
    if (hasExistingVoice) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('재녹음'),
          content: const Text('기존 음성이 새 녹음으로 덮어써집니다. 진행할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('재녹음'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이크 권한이 필요합니다')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/memo_edit_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() => _isRecording = true);
  }

  Future<Uint8List?> _readVoiceBytes(String path) async {
    if (kIsWeb) return null;
    try {
      return await io.File(path).readAsBytes();
    } catch (e) {
      debugPrint('[MemoEdit] 음성 파일 읽기 실패: $e');
      return null;
    }
  }

  /// 녹음된 bytes를 Storage 업로드 후 현재 메모(또는 새 메모)에 voiceUrl 저장.
  Future<void> _saveVoiceToMemo(Uint8List bytes) async {
    final scaffoldMsg = ScaffoldMessenger.of(context);
    final repo = ref.read(memoRepositoryProvider);
    final notifier = ref.read(memoNotifierProvider.notifier);
    final isNew = widget.initial == null;

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '음성 메모를 저장하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () async {
          final voiceUrl = await repo.uploadVoice(bytes);
          if (isNew) {
            // 새 메모 — 현재 입력값 + 음성으로 함께 생성
            final memo = MemoModel(
              id: '',
              uid: widget.uid,
              content: _controller.text.trim(),
              imageUrls: const [],
              voiceUrl: voiceUrl,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await notifier.create(memo, newImages: _newImageBytes);
          } else {
            // 기존 메모 — voiceUrl만 갱신
            final updated = widget.initial!.copyWith(voiceUrl: voiceUrl);
            await repo.updateMemo(updated);
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(scaffoldMsg, message: '음성 메모가 저장됐어요.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(scaffoldMsg, message: '$e');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final notifier = ref.read(memoNotifierProvider.notifier);
    final isNew = widget.initial == null;

    final memo = MemoModel(
      id: widget.initial?.id ?? '',
      uid: widget.uid,
      content: _controller.text.trim(),
      imageUrls: _existingUrls,
      voiceUrl: widget.initial?.voiceUrl,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await runWithMoriLoadingDialog<void>(
      context,
      message: '저장하는 중입니다.',
      task: () async {
        if (isNew) {
          await notifier.create(memo, newImages: _newImageBytes);
        } else {
          await notifier.save(memo, newImages: _newImageBytes);
        }
      },
    );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.initial == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await runWithMoriLoadingDialog<void>(
      context,
      message: '삭제하는 중입니다.',
      task: () => ref.read(memoNotifierProvider.notifier).delete(widget.initial!.id),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    final totalImages = _existingUrls.length + _newImageBytes.length;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        title: Text(isNew ? '새 메모' : '메모 수정', style: T.h3),
        actions: [
          if (!isNew)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: C.og),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('사진', style: T.bodyBold)),
                      if (totalImages < 6) ...[
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickImages,
                          icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 18),
                          label: const Text('사진 추가'),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _addDrawing,
                          icon: const Icon(Icons.brush_rounded, size: 18),
                          label: const Text('그림 추가'),
                        ),
                      ],
                      if (!kIsWeb) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            _isRecording
                                ? Icons.stop_circle_rounded
                                : Icons.mic_rounded,
                            color: _isRecording ? C.og : C.lv,
                          ),
                          tooltip: _isRecording
                              ? '녹음 중지'
                              : (widget.initial?.voiceUrl != null
                                  ? '음성 재녹음'
                                  : '음성 녹음'),
                          onPressed: _saving ? null : _toggleRecording,
                        ),
                      ],
                    ],
                  ),
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 2),
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record,
                              color: C.og, size: 12),
                          const SizedBox(width: 6),
                          Text('녹음 중...',
                              style: T.caption.copyWith(color: C.og)),
                        ],
                      ),
                    ),
                  if (totalImages > 0) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 84,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // 기존 URL 이미지
                          ..._existingUrls.asMap().entries.map((entry) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: entry.value,
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => _imagePlaceholder(),
                                      ),
                                    ),
                                    _removeButton(() => setState(() =>
                                        _existingUrls.removeAt(entry.key))),
                                  ],
                                ),
                              )),
                          // 새로 선택한 이미지 (bytes 미리보기)
                          ..._newImagePreviews.asMap().entries.map((entry) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        entry.value,
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    _removeButton(() => setState(() {
                                          _newImageBytes.removeAt(entry.key);
                                          _newImagePreviews.removeAt(entry.key);
                                        })),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    maxLines: 18,
                    decoration: InputDecoration(
                      hintText: '도안 아이디어, 재료 메모, 작업 노트...',
                      filled: true,
                      fillColor: C.gx,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd),
        ),
        child: const Icon(Icons.image_outlined),
      );

  Widget _removeButton(VoidCallback onTap) => Positioned(
        top: 4,
        right: 4,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      );
}
