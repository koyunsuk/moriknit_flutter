// 이슈 #837 — @moriknit 인박스 채팅 패널 (웹·모바일 어드민 공용).
//
// 우측/풀스크린 채팅 영역. dmMessagesProvider 로 메시지 스트림 표시 + 하단
// 입력창에서 어드민이 답장 발송. 발송은 Cloud Function
// `sendAdminReplyAsMoriknit` 호출 — 시스템 명의로 메시지 작성됨.
//
// 메시지 버블:
//   - 사용자 메시지: 좌측, C.gx 배경
//   - @moriknit 시스템 답장: 우측, C.lv 배경 + "어드민 답장" 작은 라벨

import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/system_users.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/async_data_view.dart';
import '../../../../../core/widgets/common_widgets.dart';
import '../../../../../core/widgets/rich_broadcast_card.dart';
import '../../../../../providers/dm_provider.dart';
import '../../../../dm/domain/dm_model.dart';
import '../../../../dm/presentation/widgets/dm_attachment_chip.dart';

class InboxChatPanel extends ConsumerStatefulWidget {
  /// 선택된 사용자 uid (수신자).
  final String userUid;
  /// 헤더에 표시할 사용자 이름.
  final String displayName;
  /// 헤더에 표시할 사용자 핸들.
  final String handle;
  /// 헤더 아바타 photo URL.
  final String photoUrl;
  /// 헤더 좌측 leading (모바일 풀스크린에서 뒤로가기 버튼 자리). null 이면 미표시.
  final Widget? leading;
  /// 한국어 UI 여부.
  final bool isKorean;

  const InboxChatPanel({
    super.key,
    required this.userUid,
    required this.displayName,
    required this.handle,
    required this.photoUrl,
    this.leading,
    this.isKorean = true,
  });

  @override
  ConsumerState<InboxChatPanel> createState() => _InboxChatPanelState();
}

class _InboxChatPanelState extends ConsumerState<InboxChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  /// 이슈 #845 — 첨부 대기 (전송 시 함께 발송).
  /// 이미지 또는 파일 둘 중 하나만 보유.
  _PendingAttachment? _pendingAttachment;

  /// dm_rooms deterministic ID — moriknit_system 과 user uid 알파벳 정렬 후 __ 조인.
  String get _roomId {
    final ids = [SystemUsers.moriknitUid, widget.userUid]..sort();
    return ids.join('__');
  }

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

  Future<void> _send() async {
    final text = _controller.text.trim();
    final attachment = _pendingAttachment;
    // 이슈 #845 — 본문이 비어도 첨부가 있으면 전송 허용.
    if (_sending) return;
    if (text.isEmpty && attachment == null) return;
    setState(() => _sending = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '답장을 전송하는 중입니다.' : 'Sending reply...',
        subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          String imageUrl = '';
          String attachmentUrl = '';
          String attachmentName = '';
          // 1) 첨부가 있으면 Firebase Storage 업로드 → URL 확보
          if (attachment != null) {
            final ext = attachment.fileExtension;
            final ts = DateTime.now().millisecondsSinceEpoch;
            final safeRoom = _roomId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
            final path =
                'dm/admin_attachments/$safeRoom/${ts}_${attachment.fileName}';
            final ref = FirebaseStorage.instance.ref().child(path);
            UploadTask task;
            if (attachment.bytes != null) {
              task = ref.putData(
                attachment.bytes!,
                SettableMetadata(contentType: attachment.contentType),
              );
            } else {
              task = ref.putFile(
                File(attachment.localPath!),
                SettableMetadata(contentType: attachment.contentType),
              );
            }
            final snap = await task;
            final url = await snap.ref.getDownloadURL();
            if (attachment.isImage) {
              imageUrl = url;
            } else {
              attachmentUrl = url;
              attachmentName = attachment.fileName;
            }
            // ext 는 metadata 결정용으로만 사용 (전송 payload 와 무관).
            ext;
          }

          // 2) Cloud Function 호출
          final callable = FirebaseFunctions.instance
              .httpsCallable('sendAdminReplyAsMoriknit');
          await callable.call<Map<String, dynamic>>(<String, dynamic>{
            'userUid': widget.userUid,
            'text': text,
            if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
            if (attachmentUrl.isNotEmpty) 'attachmentUrl': attachmentUrl,
            if (attachmentName.isNotEmpty) 'attachmentName': attachmentName,
          });
        },
      );
      if (!mounted) return;
      _controller.clear();
      setState(() => _pendingAttachment = null);
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '답장이 전송됐어요.' : 'Reply sent.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 이슈 #845 — 첨부 선택 시트 (이미지 갤러리/카메라 + 파일 PDF 등).
  Future<void> _pickAttachment() async {
    if (_sending) return;
    final source = await showModalBottomSheet<_AttachKind>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
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
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: C.lv),
              title: Text(
                widget.isKorean ? '갤러리에서 선택' : 'Choose from gallery',
                style: T.body,
              ),
              onTap: () => Navigator.pop(sheetCtx, _AttachKind.gallery),
            ),
            if (!kIsWeb)
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: C.lv),
                title: Text(
                  widget.isKorean ? '카메라로 촬영' : 'Take a photo',
                  style: T.body,
                ),
                onTap: () => Navigator.pop(sheetCtx, _AttachKind.camera),
              ),
            ListTile(
              leading: Icon(Icons.attach_file_rounded, color: C.lv),
              title: Text(
                widget.isKorean ? '파일 선택 (PDF 등)' : 'Pick file (PDF, etc.)',
                style: T.body,
              ),
              onTap: () => Navigator.pop(sheetCtx, _AttachKind.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      _PendingAttachment? next;
      if (source == _AttachKind.gallery || source == _AttachKind.camera) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: source == _AttachKind.gallery
              ? ImageSource.gallery
              : ImageSource.camera,
          maxWidth: 1800,
          imageQuality: 88,
        );
        if (picked == null) return;
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          next = _PendingAttachment.image(
            bytes: bytes,
            fileName: picked.name,
            contentType: picked.mimeType ?? 'image/jpeg',
          );
        } else {
          next = _PendingAttachment.image(
            localPath: picked.path,
            fileName: picked.name,
            contentType: picked.mimeType ?? 'image/jpeg',
          );
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: kIsWeb,
        );
        if (result == null || result.files.isEmpty) return;
        final f = result.files.single;
        final name = f.name;
        final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
        final mime = _mimeForExt(ext);
        if (kIsWeb) {
          final bytes = f.bytes;
          if (bytes == null) return;
          next = _PendingAttachment.file(
            bytes: bytes,
            fileName: name,
            contentType: mime,
          );
        } else {
          final path = f.path;
          if (path == null) return;
          next = _PendingAttachment.file(
            localPath: path,
            fileName: name,
            contentType: mime,
          );
        }
      }
      if (!mounted) return;
      setState(() => _pendingAttachment = next);
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  String _mimeForExt(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  /// 이슈 #845 — 메시지 길게 누름 → 삭제 옵션 시트.
  void _showMessageOptions(DmMessage message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
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
                widget.isKorean ? '메시지 삭제' : 'Delete message',
                style: T.body.copyWith(color: C.og),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _confirmDeleteMessage(message);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMessage(DmMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          widget.isKorean ? '메시지를 삭제할까요?' : 'Delete message?',
          style: T.h3,
        ),
        content: Text(
          widget.isKorean
              ? '삭제된 메시지는 복구할 수 없습니다.'
              : 'This action cannot be undone.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              widget.isKorean ? '취소' : 'Cancel',
              style: TextStyle(color: C.mu),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.og,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.isKorean ? '삭제' : 'Delete',
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
        message: widget.isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(dmRepositoryProvider).deleteMessage(
              roomId: _roomId,
              messageId: message.id,
            ),
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '메시지가 삭제됐어요.' : 'Message deleted.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(dmMessagesProvider(_roomId));
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: AsyncDataView<List<DmMessage>>(
            async: messagesAsync,
            isEmpty: (list) => list.isEmpty,
            emptyBuilder: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.isKorean
                      ? '아직 메시지가 없습니다.\n첫 답장을 보내보세요.'
                      : 'No messages yet.\nSend the first reply.',
                  style: T.body.copyWith(color: C.mu),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            builder: (messages) {
              _scrollToBottom();
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  // @moriknit 시스템(어드민 답장 + 브로드캐스트 포함) 메시지는 우측,
                  // 사용자 메시지는 좌측.
                  final isAdminSide = msg.senderId == SystemUsers.moriknitUid;
                  // 이슈 #845 — 어드민은 모든 메시지(사용자/시스템) 길게 누름 → 삭제 가능.
                  return GestureDetector(
                    onLongPress: () => _showMessageOptions(msg),
                    child: _MessageBubble(
                      message: msg,
                      isAdminSide: isAdminSide,
                      userPhoto: widget.photoUrl,
                      userDisplayName: widget.displayName,
                      isKorean: widget.isKorean,
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildInput(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.gx,
        border: Border(bottom: BorderSide(color: C.bd)),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 4),
          ],
          _Avatar(photoUrl: widget.photoUrl, displayName: widget.displayName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.displayName.isEmpty
                            ? (widget.isKorean ? '(이름 없음)' : '(no name)')
                            : widget.displayName,
                        style: T.bodyBold.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.handle.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '@${widget.handle}',
                          style: T.caption.copyWith(
                            color: C.lvD,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isKorean
                      ? '@moriknit 명의로 답장이 전송됩니다.'
                      : 'Replies are sent as @moriknit.',
                  style: T.caption.copyWith(color: C.mu, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).viewInsets.bottom > 0
            ? MediaQuery.of(context).viewInsets.bottom + 8
            : MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.bd)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 이슈 #845 — 첨부 미리보기 (대기 중일 때만).
          if (_pendingAttachment != null) _buildAttachmentPreview(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 이슈 #845 — 첨부 클립 아이콘 (입력창 좌측).
              IconButton(
                onPressed: _sending ? null : _pickAttachment,
                icon: Icon(Icons.attach_file_rounded, color: C.lv),
                tooltip:
                    widget.isKorean ? '파일 첨부' : 'Attach file',
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.newline,
                  maxLines: 4,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: widget.isKorean
                        ? '@moriknit 명의로 답장 작성…'
                        : 'Reply as @moriknit…',
                    filled: true,
                    fillColor: C.gx,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sending ? null : _send,
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
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    final att = _pendingAttachment!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.lv.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            att.isImage
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined,
            color: C.lvD,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              att.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.body.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: _sending
                ? null
                : () => setState(() => _pendingAttachment = null),
            icon: Icon(Icons.close_rounded, color: C.lvD, size: 18),
            tooltip: widget.isKorean ? '첨부 취소' : 'Remove attachment',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

/// 이슈 #845 — 첨부 시트의 선택 종류.
enum _AttachKind { gallery, camera, file }

/// 이슈 #845 — 전송 대기 중인 첨부 파일.
/// 웹은 [bytes], 네이티브는 [localPath] 사용.
class _PendingAttachment {
  final String fileName;
  final String contentType;
  final bool isImage;
  final String? localPath;
  final Uint8List? bytes;

  const _PendingAttachment._({
    required this.fileName,
    required this.contentType,
    required this.isImage,
    this.localPath,
    this.bytes,
  });

  factory _PendingAttachment.image({
    String? localPath,
    Uint8List? bytes,
    required String fileName,
    required String contentType,
  }) =>
      _PendingAttachment._(
        fileName: fileName,
        contentType: contentType,
        isImage: true,
        localPath: localPath,
        bytes: bytes,
      );

  factory _PendingAttachment.file({
    String? localPath,
    Uint8List? bytes,
    required String fileName,
    required String contentType,
  }) =>
      _PendingAttachment._(
        fileName: fileName,
        contentType: contentType,
        isImage: false,
        localPath: localPath,
        bytes: bytes,
      );

  String get fileExtension {
    final i = fileName.lastIndexOf('.');
    return i >= 0 ? fileName.substring(i + 1).toLowerCase() : '';
  }
}

class _MessageBubble extends StatelessWidget {
  final DmMessage message;
  final bool isAdminSide;
  final String userPhoto;
  final String userDisplayName;
  final bool isKorean;

  const _MessageBubble({
    required this.message,
    required this.isAdminSide,
    required this.userPhoto,
    required this.userDisplayName,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    // 이슈 #848 — 어드민이 발송한 풍부한 브로드캐스트 카드는 별도 위젯으로 렌더링.
    // 어드민 인박스에서 어드민 자신이 발송한 브로드캐스트 메시지를 다시 확인할 수
    // 있도록 라벤더 강조 톤(useAccentBackground) 카드로 표시.
    final Widget bubble = message.isRichBroadcast
        ? RichBroadcastCard(
            text: message.text,
            imageUrl: message.imageUrl,
            bodyDelta: message.bodyDelta,
            linkUrl: message.linkUrl,
            isKorean: isKorean,
            useAccentBackground: isAdminSide,
            maxWidth: 360,
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isAdminSide ? C.lv : C.gx,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isAdminSide
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isAdminSide
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                border: isAdminSide ? null : Border.all(color: C.bd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdminSide && message.isAdminReply) ...[
                    Text(
                      isKorean ? '어드민 답장' : 'Admin reply',
                      style: T.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: T.body.copyWith(
                        color: isAdminSide ? Colors.white : C.tx,
                        height: 1.45,
                      ),
                    ),
                  // 이슈 #845 — 첨부(비이미지 PDF 등) 칩.
                  if (message.hasAttachment) ...[
                    if (message.text.isNotEmpty) const SizedBox(height: 8),
                    DmAttachmentChip(
                      url: message.attachmentUrl,
                      name: message.attachmentName,
                      isAdminSide: isAdminSide,
                      isKorean: isKorean,
                    ),
                  ],
                ],
              ),
            ),
          );

    final timeText = Text(
      _formatTime(message.createdAt),
      style: T.caption.copyWith(color: C.mu, fontSize: 10),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isAdminSide ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isAdminSide
            ? [
                timeText,
                const SizedBox(width: 6),
                bubble,
              ]
            : [
                _Avatar(photoUrl: userPhoto, displayName: userDisplayName),
                const SizedBox(width: 6),
                bubble,
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
    final initial =
        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';
    if (photoUrl.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: C.lvL,
        child: Text(
          initial,
          style: TextStyle(color: C.lvD, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => CircleAvatar(
          radius: 16,
          backgroundColor: C.lvL,
          child: Text(
            initial,
            style: TextStyle(color: C.lvD, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
