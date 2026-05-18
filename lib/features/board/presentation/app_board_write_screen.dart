// 이슈 #783 — 게시판 글 작성 화면 (QnA 사용자 작성 + admin은 FAQ/릴리즈).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../landing/data/landing_board_repository.dart';

class AppBoardWriteScreen extends ConsumerStatefulWidget {
  final String boardType;
  const AppBoardWriteScreen({super.key, required this.boardType});

  @override
  ConsumerState<AppBoardWriteScreen> createState() => _AppBoardWriteScreenState();
}

class _AppBoardWriteScreenState extends ConsumerState<AppBoardWriteScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해 주세요.')),
      );
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    final profile = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '글을 등록하는 중입니다.',
        task: () async {
          await ref.read(landingBoardRepositoryProvider).createPost(
                LandingPost(
                  id: '',
                  title: title,
                  content: content,
                  authorUid: user.uid,
                  authorName: profile?.displayName ?? user.displayName ?? '익명',
                  createdAt: DateTime.now(),
                  type: widget.boardType,
                ),
              );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context), message: '글이 등록됐어요.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQna = widget.boardType == 'qa';
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isQna ? '문의 작성' : '글쓰기', style: T.h3),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: '제목',
                  filled: true,
                  fillColor: C.gx,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: isQna ? '문의 내용을 자세히 작성해 주세요.' : '내용',
                    filled: true,
                    fillColor: C.gx,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(isQna ? '문의 등록' : '글 등록'),
            ),
          ),
        ),
      ),
    );
  }
}
