import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dm_provider.dart';
import '../domain/dm_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final user = ref.watch(authStateProvider).valueOrNull;
    final messagesAsync = ref.watch(dmMessagesProvider(widget.roomId));

    // Resolve other user name from room data
    final roomsAsync = ref.watch(dmRoomsProvider(user?.uid ?? ''));
    final room = roomsAsync.valueOrNull?.where((r) => r.id == widget.roomId).firstOrNull;
    final otherName = room?.otherName(user?.uid ?? '') ?? '';

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
        title: Text(
          otherName.isEmpty ? (isKorean ? '대화' : 'Chat') : otherName,
          style: T.h3,
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == user?.uid;
                        return _MessageBubble(message: msg, isMe: isMe);
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
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? C.lv : C.gx,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: C.bd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: T.body.copyWith(
                color: isMe ? Colors.white : C.tx,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(message.createdAt),
              style: T.caption.copyWith(
                color: isMe ? Colors.white.withValues(alpha: 0.7) : C.mu,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
