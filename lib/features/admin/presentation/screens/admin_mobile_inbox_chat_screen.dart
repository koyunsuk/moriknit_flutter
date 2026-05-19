// 이슈 #837 — @moriknit 인박스 채팅 화면 (모바일 어드민 풀스크린).
//
// AdminMobileInboxScreen 에서 사용자 카드 탭 시 push.
// 뒤로가기 버튼으로 목록 복귀. 키보드 자동 올라옴 (입력 포커스 시).

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../widgets/inbox/inbox_chat_panel.dart';

class AdminMobileInboxChatScreen extends StatelessWidget {
  final String userUid;
  final String displayName;
  final String handle;
  final String photoUrl;

  const AdminMobileInboxChatScreen({
    super.key,
    required this.userUid,
    required this.displayName,
    required this.handle,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
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
                displayName.isEmpty ? '(이름 없음)' : displayName,
                style: T.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (handle.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '@$handle',
                  style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: InboxChatPanel(
              userUid: userUid,
              displayName: displayName,
              handle: handle,
              photoUrl: photoUrl,
              isKorean: true,
            ),
          ),
        ],
      ),
    );
  }
}
