// 이슈 #817 — FCM Phase 1: 어드민 푸시 발송 패널.
//
// 흐름:
//   1) 어드민이 제목/본문/딥링크/대상 입력
//   2) "발송" → runWithMoriLoadingDialog 로 Cloud Function 호출
//   3) 발송 결과 (성공/실패/무효토큰 정리/총 토큰) SnackBar 표시
//   4) 최근 발송 이력 (notifications 컬렉션 최근 20건) 하단 리스트
//
// admin_screen.dart 의 _buildTabContent() 에서 새 case 로 노출.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';

/// 최근 발송 이력 — notifications 컬렉션 (어드민만 read)
final _pushHistoryProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collection('notifications')
      .orderBy('sentAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs);
});

class AdminPushPanel extends ConsumerStatefulWidget {
  final bool isKorean;
  const AdminPushPanel({super.key, required this.isKorean});

  @override
  ConsumerState<AdminPushPanel> createState() => _AdminPushPanelState();
}

class _AdminPushPanelState extends ConsumerState<AdminPushPanel> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _deepLinkCtrl = TextEditingController();
  String _audience = 'all';

  bool _sending = false;

  static const _audienceOptions = <String, String>{
    'all': '전체',
    'free': 'Free 사용자',
    'starter': 'Starter 사용자',
    'pro': 'Pro 사용자',
    'business': 'Business 사용자',
  };

  static const _audienceOptionsEn = <String, String>{
    'all': 'All users',
    'free': 'Free users',
    'starter': 'Starter users',
    'pro': 'Pro users',
    'business': 'Business users',
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _deepLinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    final history = ref.watch(_pushHistoryProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 발송 폼 ──────────────────────────────────────────────────────────
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.send_rounded, size: 18, color: C.lv),
                  const SizedBox(width: 8),
                  Text(
                    isKorean ? '푸시 메시지 발송' : 'Send push notification',
                    style: T.bodyBold.copyWith(color: C.tx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isKorean
                    ? '입력한 제목·본문이 선택한 대상의 모든 디바이스에 즉시 발송됩니다. 무효 토큰은 자동으로 정리됩니다.'
                    : 'Sends to every device of the selected audience. Invalid tokens are pruned automatically.',
                style: T.caption.copyWith(color: C.mu, height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleCtrl,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: isKorean ? '제목' : 'Title',
                  hintText: isKorean ? '예) 모리니트 신기능 안내' : 'e.g. New feature launched',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyCtrl,
                maxLength: 240,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: isKorean ? '본문' : 'Body',
                  hintText: isKorean
                      ? '알림 잠금화면에 표시될 본문을 입력하세요.'
                      : 'Enter the body shown on the lock screen.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _deepLinkCtrl,
                decoration: InputDecoration(
                  labelText: isKorean ? '딥링크 경로 (선택)' : 'Deep link (optional)',
                  hintText: '/community  또는  /tools/encyclopedia',
                  helperText: isKorean
                      ? '앱 내부 경로만 사용. http(s) URL은 무시됩니다.'
                      : 'Use in-app paths only. http(s) URLs are ignored.',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    isKorean ? '대상' : 'Audience',
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _audience,
                    isDense: true,
                    dropdownColor: Colors.white,
                    style: T.body.copyWith(color: C.tx),
                    items: (isKorean ? _audienceOptions : _audienceOptionsEn)
                        .entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                style: T.body.copyWith(color: C.tx),
                              ),
                            ))
                        .toList(),
                    onChanged: _sending
                        ? null
                        : (v) => setState(() => _audience = v ?? 'all'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.campaign_rounded, size: 18),
                  label: Text(isKorean ? '발송' : 'Send'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 최근 발송 이력 ───────────────────────────────────────────────────
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: C.tx2),
                  const SizedBox(width: 8),
                  Text(
                    isKorean ? '최근 발송 이력 (최신 20건)' : 'Recent broadcasts (latest 20)',
                    style: T.bodyBold.copyWith(color: C.tx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              history.when(
                data: (docs) {
                  if (docs.isEmpty) {
                    return _placeholder(isKorean
                        ? '아직 발송 이력이 없습니다.'
                        : 'No broadcasts yet.');
                  }
                  return Column(
                    children: docs.map((d) => _HistoryRow(doc: d, isKorean: isKorean)).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  e.toString(),
                  style: T.caption.copyWith(color: C.og),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder(String text) {
    // CLAUDE.md 플레이스홀더 원칙 — 데이터 없을 때도 공간 유지 (빈 행 + 안내).
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: C.lv.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(text, style: T.caption.copyWith(color: C.mu)),
      ],
    );
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final deepLink = _deepLinkCtrl.text.trim();
    if (title.isEmpty && body.isEmpty) {
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '제목 또는 본문을 입력해 주세요.' : 'Title or body is required.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isKorean ? '발송 확인' : 'Confirm broadcast'),
        content: Text(
          widget.isKorean
              ? '대상: ${_audienceOptions[_audience]}\n\n해당 대상의 모든 디바이스에 즉시 발송됩니다. 계속할까요?'
              : 'Audience: ${_audienceOptionsEn[_audience]}\n\nThis will send immediately to every device. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(widget.isKorean ? '취소' : 'Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(widget.isKorean ? '발송' : 'Send')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _sending = true);
    try {
      final result = await runWithMoriLoadingDialog<Map<String, dynamic>>(
        context,
        message: widget.isKorean ? '발송하는 중입니다.' : 'Sending...',
        subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'sendBroadcastPush',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 540)),
          );
          final res = await callable.call(<String, dynamic>{
            'title': title,
            'body': body,
            if (deepLink.isNotEmpty) 'deepLink': deepLink,
            'audience': _audience,
          });
          final data = res.data;
          if (data is Map) {
            return Map<String, dynamic>.from(data);
          }
          return <String, dynamic>{};
        },
      );

      if (!mounted) return;
      final total = (result['totalTokens'] ?? 0) as int;
      final success = (result['successCount'] ?? 0) as int;
      final failure = (result['failureCount'] ?? 0) as int;
      final pruned = (result['prunedCount'] ?? 0) as int;
      // 이슈 #834 — DM fanout 결과 함께 표시
      final recipientCount = (result['recipientCount'] ?? 0) as int;
      final dmCount = (result['dmCount'] ?? 0) as int;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean
            ? '발송 완료 · 전체 $total · 성공 $success · 실패 $failure · 정리 $pruned · 대상 $recipientCount명 · DM $dmCount건'
            : 'Sent · total $total · success $success · failed $failure · pruned $pruned · recipients $recipientCount · DMs $dmCount',
      );

      // 입력 초기화
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _deepLinkCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _HistoryRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isKorean;
  const _HistoryRow({required this.doc, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['title'] as String?)?.trim() ?? '';
    final body = (data['body'] as String?)?.trim() ?? '';
    final audience = (data['audience'] as String?) ?? 'all';
    final total = (data['totalTokens'] as int?) ?? 0;
    final success = (data['successCount'] as int?) ?? 0;
    final failure = (data['failureCount'] as int?) ?? 0;
    // 이슈 #834 — 읽음 통계 (recipientCount 기준 — 디바이스 수 아님)
    final recipientCount = (data['recipientCount'] as int?) ?? 0;
    final readCount = (data['readCount'] as int?) ?? 0;
    final readPercent = recipientCount > 0
        ? ((readCount / recipientCount) * 100).round()
        : 0;
    final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
    final timeText = sentAt == null ? '-' : DateFormat('yyyy.MM.dd HH:mm').format(sentAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.lv.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? (isKorean ? '(제목 없음)' : '(no title)') : title,
                    style: T.bodyBold.copyWith(color: C.tx),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: C.lvL,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    audience,
                    style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                body,
                style: T.caption.copyWith(color: C.tx2, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: C.mu),
                const SizedBox(width: 4),
                Text(timeText, style: T.caption.copyWith(color: C.mu)),
                const SizedBox(width: 12),
                Icon(Icons.send_rounded, size: 12, color: C.mu),
                const SizedBox(width: 4),
                Text(
                  isKorean
                      ? '전체 $total · 성공 $success · 실패 $failure'
                      : 'total $total · ok $success · fail $failure',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ],
            ),
            // 이슈 #834 — 읽음 추적 (사용자 단위)
            if (recipientCount > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.mark_email_read_rounded, size: 12, color: C.lvD),
                  const SizedBox(width: 4),
                  Text(
                    isKorean
                        ? '대상 $recipientCount명 · 읽음 $readCount명 ($readPercent%)'
                        : '$recipientCount recipients · $readCount read ($readPercent%)',
                    style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
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
