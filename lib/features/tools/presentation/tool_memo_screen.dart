import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/memo_lock_provider.dart';
import '../../../providers/memo_provider.dart';
import '../domain/memo_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(memoListProvider);

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: '나만의 메모장',
                subtitle: '도안, 재료, 아이디어를 자유롭게 기록해요',
              ),
            ),
            Expanded(
              child: !_migrated || !_lockChecked
                  ? Center(child: CircularProgressIndicator(color: C.lv))
                  : _isLocked
                      ? _buildLockScreen()
                      : memosAsync.when(
                          loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
                          error: (e, _) => Center(child: Text('오류: $e', style: T.caption.copyWith(color: C.og))),
                          data: (memos) => _buildList(memos),
                        ),
            ),
          ],
        ),
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

  Widget _buildList(List<MemoModel> memos) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        // 통계
        GlassCard(
          child: Row(
            children: [
              Expanded(
                child: _MemoStatCell(
                  label: '전체 메모',
                  value: '${memos.length}',
                  color: C.pkD,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MemoStatCell(
                  label: '사진 포함',
                  value: '${memos.where((m) => m.imageUrls.isNotEmpty).length}',
                  color: C.lvD,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 잠금 설정
        GlassCard(
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.lock_outline_rounded, color: C.lvD, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('메모장 잠금', style: T.bodyBold),
                    Text('앱 시작 시 PIN으로 잠궈요', style: T.caption.copyWith(color: C.mu)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleLock(ref.read(memoLockProvider)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ref.watch(memoLockProvider) ? C.lv : C.lvL,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ref.watch(memoLockProvider) ? '잠금 ON' : '잠금 OFF',
                    style: T.caption.copyWith(
                      color: ref.watch(memoLockProvider) ? Colors.white : C.lvD,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 리스트
        GlassCard(
          child: memos.isEmpty
              ? MoriEmptyState(
                  icon: Icons.edit_note_rounded,
                  iconColor: C.pk,
                  title: '아직 메모가 없어요',
                  subtitle: '생각을 자유롭게 기록해보세요.',
                  buttonLabel: '첫 메모 작성하기',
                  onAction: () => _openEditor(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('메모 목록', style: T.bodyBold)),
                        TextButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text('새 메모'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...memos.map((memo) => _MemoListTile(
                          memo: memo,
                          onTap: () => _openEditor(existing: memo),
                        )),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── 통계 셀 ───────────────────────────────────────────────
class _MemoStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MemoStatCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.caption.copyWith(color: C.mu)),
          const SizedBox(height: 4),
          Text(value, style: T.bodyBold.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── 목록 타일 ─────────────────────────────────────────────
class _MemoListTile extends StatelessWidget {
  final MemoModel memo;
  final VoidCallback onTap;
  const _MemoListTile({required this.memo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final firstLine = memo.content
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final dateStr = DateFormat('yyyy.MM.dd').format(memo.createdAt);
    final firstImageUrl = memo.imageUrls.isNotEmpty ? memo.imageUrls.first : null;

    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: firstImageUrl != null
                  ? Image.network(
                      firstImageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _noImageBox(),
                    )
                  : _noImageBox(),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstLine.isEmpty ? '(내용 없음)' : firstLine,
                  style: T.bodyBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        decoration: BoxDecoration(color: C.pkL, borderRadius: BorderRadius.circular(10)),
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.content ?? '');
    _existingUrls = List<String>.from(widget.initial?.imageUrls ?? []);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 86);
    if (picked.isEmpty) return;
    final remaining = 6 - _existingUrls.length - _newImageBytes.length;
    final toAdd = picked.take(remaining < 0 ? 0 : remaining).toList();
    for (final xFile in toAdd) {
      final bytes = await xFile.readAsBytes();
      setState(() {
        _newImageBytes.add(bytes);
        _newImagePreviews.add(bytes);
      });
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
                      if (totalImages < 6)
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickImages,
                          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                          label: const Text('사진 추가'),
                        ),
                    ],
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
                                      child: Image.network(
                                        entry.value,
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => _imagePlaceholder(),
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
