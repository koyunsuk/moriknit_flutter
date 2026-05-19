// 이슈 #837 — @moriknit 인박스 (모바일 어드민 풀스크린).
//
// 화면 1: 사용자 목록 (InboxUserList) 풀스크린.
// 카드 탭 → AdminMobileInboxChatScreen 으로 push (풀스크린 채팅).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/system_users.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../dm/domain/dm_model.dart';
import '../widgets/inbox/inbox_user_list.dart';
import 'admin_mobile_inbox_chat_screen.dart';

class AdminMobileInboxScreen extends ConsumerWidget {
  const AdminMobileInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: Text('@moriknit 인박스', style: T.h3),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: InboxUserList(
                  isKorean: true,
                  onSelect: (roomId, room) => _openChat(context, room),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, DmRoom room) {
    final userUid = room.otherUid(SystemUsers.moriknitUid);
    final name = room.participantNames[userUid] ?? '';
    final handle = room.participantHandles[userUid] ?? '';
    final photo = room.participantPhotos[userUid] ?? '';
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminMobileInboxChatScreen(
          userUid: userUid,
          displayName: name,
          handle: handle,
          photoUrl: photo,
        ),
      ),
    );
  }
}
