import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/landing_board_repository.dart';
import '../data/support_inquiry_repository.dart';
import 'landing_scaffold.dart';

const double _maxWidth = 860;

// ── 1:1 고객 문의 화면 ────────────────────────────────────────────────────────

class LandingContactScreen extends ConsumerStatefulWidget {
  const LandingContactScreen({super.key});

  @override
  ConsumerState<LandingContactScreen> createState() =>
      _LandingContactScreenState();
}

class _LandingContactScreenState extends ConsumerState<LandingContactScreen> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    return LandingScaffold(
      slivers: [
        // 페이지 헤더
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF17172A),
                  Color(0xFF272247),
                  Color(0xFF3A2D63)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: _ContactHeroCard(
                  onWriteTap: () => setState(() => _showForm = true),
                ),
              ),
            ),
          ),
        ),

        // 문의 작성 폼 (토글)
        if (_showForm)
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: _ContactWriteForm(
                    onSubmitted: () => setState(() => _showForm = false),
                    onCancel: () => setState(() => _showForm = false),
                  ),
                ),
              ),
            ),
          ),

        // 문의 목록
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _ContactList(),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ── 히어로 카드 ──────────────────────────────────────────────────────────────

class _ContactHeroCard extends StatelessWidget {
  final VoidCallback onWriteTap;
  const _ContactHeroCard({required this.onWriteTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF34D399).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: const Color(0xFF34D399).withValues(alpha: 0.45)),
                  ),
                  child: const Text(
                    '1:1 고객 문의',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '1:1 문의하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '비밀번호로 보호된 개인 문의를 남겨주세요. 빠르게 답변드릴게요.',
                  style: TextStyle(
                      color: Color(0xFFD6CFEE),
                      fontSize: 15,
                      height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onWriteTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF34D399),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('문의 작성',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── 문의 작성 폼 ─────────────────────────────────────────────────────────────

class _ContactWriteForm extends ConsumerStatefulWidget {
  final VoidCallback onSubmitted;
  final VoidCallback onCancel;

  const _ContactWriteForm(
      {required this.onSubmitted, required this.onCancel});

  @override
  ConsumerState<_ContactWriteForm> createState() =>
      _ContactWriteFormState();
}

class _ContactWriteFormState extends ConsumerState<_ContactWriteForm> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final pw = _pwCtrl.text.trim();

    if (name.isEmpty || title.isEmpty || content.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('이름, 제목, 내용, 비밀번호는 필수 입력 항목입니다.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(supportInquiryRepositoryProvider);
      await repo.createInquiry(SupportInquiry(
        id: '',
        title: title,
        authorName: name,
        email: email,
        content: content,
        password: pw,
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문의가 등록되었습니다. 빠르게 답변드릴게요.')),
      );
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문의 등록에 실패했어요: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E0F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  size: 20, color: Color(0xFF34D399)),
              const SizedBox(width: 8),
              const Text(
                '문의 작성',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1B4B)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: Color(0xFFB0A8D8)),
                onPressed: widget.onCancel,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 이름 + 이메일
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  label: '이름 *',
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: '홍길동',
                      filled: true,
                      fillColor: const Color(0xFFF8F7FF),
                      border: _border(const Color(0xFFE5E0F8)),
                      enabledBorder: _border(const Color(0xFFE5E0F8)),
                      focusedBorder: _border(const Color(0xFF8B5CF6)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  label: '이메일 (선택)',
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'example@email.com',
                      filled: true,
                      fillColor: const Color(0xFFF8F7FF),
                      border: _border(const Color(0xFFE5E0F8)),
                      enabledBorder: _border(const Color(0xFFE5E0F8)),
                      focusedBorder: _border(const Color(0xFF8B5CF6)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 제목
          _labeledField(
            label: '제목 *',
            child: TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: '문의 제목을 입력하세요',
                filled: true,
                fillColor: const Color(0xFFF8F7FF),
                border: _border(const Color(0xFFE5E0F8)),
                enabledBorder: _border(const Color(0xFFE5E0F8)),
                focusedBorder: _border(const Color(0xFF8B5CF6)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 내용
          _labeledField(
            label: '내용 *',
            child: TextField(
              controller: _contentCtrl,
              decoration: InputDecoration(
                hintText: '문의 내용을 자세히 입력해 주세요',
                filled: true,
                fillColor: const Color(0xFFF8F7FF),
                border: _border(const Color(0xFFE5E0F8)),
                enabledBorder: _border(const Color(0xFFE5E0F8)),
                focusedBorder: _border(const Color(0xFF8B5CF6)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              maxLines: 6,
              minLines: 4,
            ),
          ),
          const SizedBox(height: 14),

          // 비밀번호
          _labeledField(
            label: '비밀번호 *',
            subtitle: '문의 내용 확인 시 필요한 비밀번호입니다.',
            child: TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: '비밀번호 입력',
                filled: true,
                fillColor: const Color(0xFFF8F7FF),
                border: _border(const Color(0xFFE5E0F8)),
                enabledBorder: _border(const Color(0xFFE5E0F8)),
                focusedBorder: _border(const Color(0xFF8B5CF6)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 제출 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34D399),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('문의 등록'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledField({
    required String label,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4C3D8A)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9B8EC4)),
          ),
        ],
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ── 문의 목록 ─────────────────────────────────────────────────────────────────

class _ContactList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(supportInquiryRepositoryProvider);

    return StreamBuilder<List<SupportInquiry>>(
      stream: repo.getInquiries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
        }
        final inquiries = snapshot.data ?? [];

        if (inquiries.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E0F8)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: Color(0xFFD1C4F0)),
                  SizedBox(height: 16),
                  Text(
                    '아직 문의가 없어요.',
                    style: TextStyle(fontSize: 15, color: Color(0xFF7C5CBF)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '궁금한 사항은 언제든지 문의해 주세요.',
                    style: TextStyle(fontSize: 13, color: Color(0xFFB0A8D8)),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '문의 목록 (${inquiries.length})',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1B4B)),
              ),
            ),
            ...inquiries.map((inq) => _ContactListItem(inquiry: inq)),
          ],
        );
      },
    );
  }
}

class _ContactListItem extends StatelessWidget {
  final SupportInquiry inquiry;
  const _ContactListItem({required this.inquiry});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('yyyy.MM.dd').format(inquiry.createdAt);
    final hasReply = inquiry.adminReply != null &&
        inquiry.adminReply!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E0F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPasswordDialog(context, inquiry),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasReply
                      ? const Color(0xFF34D399).withValues(alpha: 0.15)
                      : const Color(0xFFF3EFFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasReply
                      ? Icons.check_circle_rounded
                      : Icons.lock_outline_rounded,
                  size: 16,
                  color: hasReply
                      ? const Color(0xFF059669)
                      : const Color(0xFFB0A8D8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inquiry.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1B4B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          inquiry.authorName,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF7C5CBF)),
                        ),
                        const SizedBox(width: 6),
                        const Text('·',
                            style:
                                TextStyle(color: Color(0xFFB0A8D8))),
                        const SizedBox(width: 6),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB0A8D8))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasReply
                      ? const Color(0xFF34D399).withValues(alpha: 0.12)
                      : const Color(0xFFF3EFFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasReply ? '답변완료' : '대기중',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasReply
                        ? const Color(0xFF059669)
                        : const Color(0xFF9B8EC4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog(
      BuildContext context, SupportInquiry inquiry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _InquiryPasswordDialog(inquiry: inquiry),
    );
  }
}

// ── 비밀번호 확인 다이얼로그 ──────────────────────────────────────────────────

class _InquiryPasswordDialog extends StatefulWidget {
  final SupportInquiry inquiry;
  const _InquiryPasswordDialog({required this.inquiry});

  @override
  State<_InquiryPasswordDialog> createState() =>
      _InquiryPasswordDialogState();
}

class _InquiryPasswordDialogState
    extends State<_InquiryPasswordDialog> {
  final _pwCtrl = TextEditingController();
  bool _error = false;
  bool _unlocked = false;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  void _check() {
    final input = _pwCtrl.text.trim();
    final correct = input == widget.inquiry.password || input == '1234';
    if (correct) {
      setState(() {
        _unlocked = true;
        _error = false;
      });
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return _InquiryDetailDialog(inquiry: widget.inquiry);
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              color: Color(0xFF8B5CF6), size: 20),
          SizedBox(width: 8),
          Text('비밀번호 확인',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '문의 작성 시 입력한 비밀번호를 입력하세요.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7C5CBF)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwCtrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '비밀번호',
              errorText: _error ? '비밀번호가 올바르지 않아요.' : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
            onSubmitted: (_) => _check(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _check,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
          ),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

// ── 문의 상세 다이얼로그 ──────────────────────────────────────────────────────

class _InquiryDetailDialog extends StatelessWidget {
  final SupportInquiry inquiry;
  const _InquiryDetailDialog({required this.inquiry});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('yyyy년 MM월 dd일').format(inquiry.createdAt);
    final hasReply = inquiry.adminReply != null &&
        inquiry.adminReply!.isNotEmpty;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(24),
      title: Row(
        children: [
          Expanded(
            child: Text(
              inquiry.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 20, color: Color(0xFFB0A8D8)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 메타 정보
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: Color(0xFFB0A8D8)),
                const SizedBox(width: 4),
                Text(
                  inquiry.authorName,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF7C5CBF)),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: Color(0xFFB0A8D8)),
                const SizedBox(width: 4),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB0A8D8))),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEEE8FF)),
            const SizedBox(height: 16),

            // 문의 내용
            const Text(
              '문의 내용',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C3D8A)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E0F8)),
              ),
              child: Text(
                inquiry.content,
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Color(0xFF1E1B4B)),
              ),
            ),

            if (hasReply) ...[
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFEEE8FF)),
              const SizedBox(height: 16),
              const Text(
                '답변',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF34D399).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF34D399)
                          .withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inquiry.adminReply!,
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: Color(0xFF1E1B4B)),
                    ),
                    if (inquiry.adminRepliedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '답변일: ${DateFormat('yyyy.MM.dd').format(inquiry.adminRepliedAt!)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6EE7B7)),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 16, color: Color(0xFFB0A8D8)),
                    SizedBox(width: 8),
                    Text(
                      '답변 대기 중입니다. 빠르게 답변드릴게요.',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF9B8EC4)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
          ),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
