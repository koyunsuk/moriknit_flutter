import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/rich_broadcast_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dm_provider.dart';
import '../domain/dm_model.dart';
import 'widgets/dm_attachment_chip.dart';

class DmChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  const DmChatScreen({super.key, required this.roomId});

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _didMarkRead = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final profile = ref.read(currentUserProvider).valueOrNull;
    final senderName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (user.displayName ?? user.email ?? '');

    // Find the recipient UID from room data
    final rooms = ref.read(dmRoomsProvider(user.uid)).valueOrNull ?? [];
    final room = rooms.where((r) => r.id == widget.roomId).firstOrNull;
    final recipientId = room?.otherUid(user.uid) ?? '';

    if (recipientId.isEmpty) return;

    _controller.clear();

    try {
      await ref.read(dmRepositoryProvider).sendMessage(
            roomId: widget.roomId,
            senderId: user.uid,
            senderName: senderName,
            text: text,
            recipientId: recipientId,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: C.og),
      );
    }
  }

  /// 자기 메시지 길게 누를 때 팝업 옵션 표시.
  void _showMessageOptions(DmMessage message, bool isKorean) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: C.bd,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: C.og),
              title: Text(
                isKorean ? '메시지 삭제' : 'Delete message',
                style: T.body.copyWith(color: C.og),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDeleteMessage(message, isKorean);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 메시지 삭제 확인 다이얼로그.
  Future<void> _confirmDeleteMessage(DmMessage message, bool isKorean) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isKorean ? '메시지를 삭제할까요?' : 'Delete message?', style: T.h3),
        content: Text(
          isKorean
              ? '삭제된 메시지는 복구할 수 없습니다.'
              : 'This action cannot be undone.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isKorean ? '취소' : 'Cancel', style: TextStyle(color: C.mu)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.og,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isKorean ? '삭제' : 'Delete',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(dmRepositoryProvider).deleteMessage(
              roomId: widget.roomId,
              messageId: message.id,
            ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '메시지가 삭제됐습니다.' : 'Message deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: C.og),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final user = ref.watch(authStateProvider).valueOrNull;
    final messagesAsync = ref.watch(dmMessagesProvider(widget.roomId));

    // Resolve other user name from room data
    final roomsAsync = ref.watch(dmRoomsProvider(user?.uid ?? ''));
    final room = roomsAsync.valueOrNull?.where((r) => r.id == widget.roomId).firstOrNull;
    final myUid = user?.uid ?? '';
    final otherName = room?.otherName(myUid) ?? '';
    // 이슈 #771 — 상대방 핸들 (AppBar 타이틀 옆 작은 표시)
    final otherHandle = room?.otherHandle(myUid) ?? '';
    // 채팅 버블 아바타용 — room 스냅샷에 저장된 photoURL.
    final otherPhoto = room?.otherPhoto(myUid) ?? '';
    // 이슈 #834 — @moriknit 공식 채널 여부
    final isSystemChannel = room?.isSystemChannel ?? false;
    final myProfile = ref.watch(currentUserProvider).valueOrNull;
    final myPhoto = myProfile?.photoURL ?? '';
    final myDisplayName = (myProfile?.displayName.isNotEmpty == true)
        ? myProfile!.displayName
        : (user?.displayName ?? user?.email ?? '');

    // Mark as read once
    if (!_didMarkRead && user != null) {
      _didMarkRead = true;
      ref.read(dmRepositoryProvider).markAsRead(roomId: widget.roomId, uid: user.uid);
    }

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                otherName.isEmpty ? (isKorean ? '대화' : 'Chat') : otherName,
                style: T.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (otherHandle.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '@$otherHandle',
                  style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            // 이슈 #834 — @moriknit 공식 채널 배지
            if (isSystemChannel) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: C.lv.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isKorean ? '공식' : 'Official',
                  style: T.caption.copyWith(
                    color: C.lvD,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (messages) {
                    if (messages.isNotEmpty) _scrollToBottom();
                    // 이슈 #834 — 어드민 브로드캐스트 메시지 읽음 마킹 (build 외부 호출).
                    if (user != null && messages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        ref.read(dmRepositoryProvider).markBroadcastMessagesRead(
                              roomId: widget.roomId,
                              uid: user.uid,
                              messages: messages,
                            );
                      });
                    }
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          isKorean ? '아직 메시지가 없어요.\n첫 메시지를 보내보세요!' : 'No messages yet.\nSend the first message!',
                          textAlign: TextAlign.center,
                          style: T.body.copyWith(color: C.mu),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == user?.uid;
                        // 같은 발신자의 연속 메시지인지 — 마지막 메시지에만 아바타/이름 표시.
                        final next = index + 1 < messages.length ? messages[index + 1] : null;
                        final isLastInGroup = next == null || next.senderId != msg.senderId;
                        return GestureDetector(
                          onLongPress: isMe
                              ? () => _showMessageOptions(msg, isKorean)
                              : null,
                          child: _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            photoUrl: isMe ? myPhoto : otherPhoto,
                            displayName: isMe ? myDisplayName : otherName,
                            showAvatar: isLastInGroup,
                            isKorean: isKorean,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputBar(context, isKorean),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, bool isKorean) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom > 0
            ? MediaQuery.of(context).viewInsets.bottom + 8
            : MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.bd)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: isKorean ? '메시지를 입력하세요' : 'Type a message',
                filled: true,
                fillColor: C.gx,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DmMessage message;
  final bool isMe;
  final String photoUrl;
  final String displayName;
  /// 같은 발신자 메시지 묶음의 마지막일 때만 true → 아바타 표시.
  /// 위쪽 묶음은 빈 자리(SizedBox)로 정렬만 유지.
  final bool showAvatar;
  /// 이슈 #848 — 리치 카드 버튼 라벨 등 로케일 분기.
  final bool isKorean;
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.photoUrl,
    required this.displayName,
    required this.showAvatar,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = _Avatar(photoUrl: photoUrl, displayName: displayName);
    final spacer = const SizedBox(width: 32);
    final timeText = Text(
      _formatTime(message.createdAt),
      style: T.caption.copyWith(color: C.mu, fontSize: 10),
    );

    // 이슈 #848 — 어드민 브로드캐스트 풍부한 카드 메시지는 별도 위젯으로 렌더링.
    final Widget bubble = message.isRichBroadcast
        ? Flexible(
            child: RichBroadcastCard(
              text: message.text,
              imageUrl: message.imageUrl,
              bodyDelta: message.bodyDelta,
              linkUrl: message.linkUrl,
              isKorean: isKorean,
              // 일반 텍스트 버블 톤과 자연스럽게 어울리도록 회색 배경 사용.
              useAccentBackground: false,
              maxWidth: 260,
            ),
          )
        : Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? C.lv : C.gx,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight:
                      isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                border: isMe ? null : Border.all(color: C.bd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: T.body.copyWith(
                        color: isMe ? Colors.white : C.tx,
                        height: 1.5,
                      ),
                    ),
                  // 이슈 #845 — 비이미지 첨부(PDF 등) 칩.
                  if (message.hasAttachment) ...[
                    if (message.text.isNotEmpty) const SizedBox(height: 8),
                    DmAttachmentChip(
                      url: message.attachmentUrl,
                      name: message.attachmentName,
                      // 상대방(어드민) 측에서 보낸 첨부는 라벤더 톤(isAdminSide=false→
                      // C.lvL 칩), 내 첨부는 라벤더 배경 위 흰색 톤.
                      isAdminSide: isMe,
                      isKorean: isKorean,
                    ),
                  ],
                ],
              ),
            ),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: showAvatar ? 10 : 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMe
            ? [
                // 내 메시지: [시간] [버블] [아바타]
                timeText,
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: bubble,
                ),
                const SizedBox(width: 6),
                if (showAvatar) avatar else spacer,
              ]
            : [
                // 상대 메시지: [아바타] [버블] [시간]
                if (showAvatar) avatar else spacer,
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: bubble,
                ),
                const SizedBox(width: 6),
                timeText,
              ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  const _Avatar({required this.photoUrl, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: C.lvL,
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Text(
              initial,
              style: TextStyle(color: C.lvD, fontWeight: FontWeight.w700, fontSize: 13),
            )
          : null,
    );
  }
}
