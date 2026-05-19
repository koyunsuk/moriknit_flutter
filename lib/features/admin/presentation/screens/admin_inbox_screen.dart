// 이슈 #837 — @moriknit 인박스 (웹 어드민 데스크탑 화면).
//
// 레이아웃: Row([좌측 InboxUserList 35%, VerticalDivider, 우측 InboxChatPanel 65%])
// admin_screen.dart 의 _buildTabContent case 28 에서 사용.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/system_users.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers/dm_provider.dart';
import '../../../dm/domain/dm_model.dart';
import '../widgets/inbox/inbox_chat_panel.dart';
import '../widgets/inbox/inbox_user_list.dart';

class AdminInboxScreen extends ConsumerStatefulWidget {
  final bool isKorean;
  const AdminInboxScreen({super.key, this.isKorean = true});

  @override
  ConsumerState<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends ConsumerState<AdminInboxScreen> {
  String? _selectedRoomId;
  DmRoom? _selectedRoom;

  @override
  Widget build(BuildContext context) {
    // 좌측에서 선택된 룸이 사라진 경우를 대비해 stream 에서 다시 룩업.
    final roomsAsync = ref.watch(adminMoriknitInboxRoomsProvider);
    final rooms = roomsAsync.valueOrNull ?? const <DmRoom>[];
    DmRoom? current;
    if (_selectedRoomId != null) {
      try {
        current = rooms.firstWhere((r) => r.id == _selectedRoomId);
      } catch (_) {
        current = _selectedRoom;
      }
    }
    // 최초 진입 시 첫 번째 룸 자동 선택 (있을 때).
    if (current == null && rooms.isNotEmpty) {
      current = rooms.first;
      _selectedRoomId = current.id;
      _selectedRoom = current;
    }

    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 좌측 — 사용자 목록 35%
          Expanded(
            flex: 35,
            child: _Panel(
              header: _PanelHeader(
                title: widget.isKorean ? '받은편지함' : 'Inbox',
                subtitle: widget.isKorean
                    ? '@moriknit 으로 들어온 사용자 메시지'
                    : 'Incoming user messages to @moriknit',
                icon: Icons.inbox_rounded,
              ),
              child: InboxUserList(
                selectedRoomId: _selectedRoomId,
                isKorean: widget.isKorean,
                onSelect: (roomId, room) {
                  setState(() {
                    _selectedRoomId = roomId;
                    _selectedRoom = room;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 우측 — 채팅 패널 65%
          Expanded(
            flex: 65,
            child: _Panel(
              child: current == null
                  ? _EmptySelection(isKorean: widget.isKorean)
                  : _buildChat(current),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat(DmRoom room) {
    final userUid = room.otherUid(SystemUsers.moriknitUid);
    final name = room.participantNames[userUid] ?? '';
    final handle = room.participantHandles[userUid] ?? '';
    final photo = room.participantPhotos[userUid] ?? '';
    return InboxChatPanel(
      key: ValueKey(room.id),
      userUid: userUid,
      displayName: name,
      handle: handle,
      photoUrl: photo,
      isKorean: widget.isKorean,
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Widget? header;
  const _Panel({required this.child, this.header});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ?header,
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFF8A00), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: T.bodyBold.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: T.caption.copyWith(color: C.mu)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySelection extends StatelessWidget {
  final bool isKorean;
  const _EmptySelection({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: C.mu),
            const SizedBox(height: 12),
            Text(
              isKorean
                  ? '좌측에서 사용자를 선택하면\n@moriknit 명의로 답장할 수 있습니다.'
                  : 'Select a user on the left\nto reply as @moriknit.',
              style: T.body.copyWith(color: C.mu, height: 1.45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
