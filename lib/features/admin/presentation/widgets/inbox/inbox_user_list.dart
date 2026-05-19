// 이슈 #837 — @moriknit 인박스 사용자 목록 (웹·모바일 어드민 공용).
//
// adminMoriknitInboxRoomsProvider 를 watch 하여 @moriknit 시스템 봇과의 모든
// DM 룸을 한 줄 카드로 표시. 미응답 우선 정렬 + 빨간 점 + 미응답 시간.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/system_users.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/async_data_view.dart';
import '../../../../../providers/dm_provider.dart';
import '../../../../dm/domain/dm_model.dart';

class InboxUserList extends ConsumerWidget {
  /// 현재 선택된 roomId — 카드 하이라이트.
  final String? selectedRoomId;

  /// 카드 탭 콜백. (roomId, room) 전달.
  final void Function(String roomId, DmRoom room) onSelect;

  /// 빈 데이터 / 로딩 안내 한국어 여부.
  final bool isKorean;

  const InboxUserList({
    super.key,
    required this.onSelect,
    this.selectedRoomId,
    this.isKorean = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(adminMoriknitInboxRoomsProvider);
    return AsyncDataView<List<DmRoom>>(
      async: roomsAsync,
      isEmpty: (rooms) => rooms.isEmpty,
      emptyBuilder: () => EmptyBlockPlaceholder(
        message: isKorean
            ? '@moriknit 인박스에 사용자 메시지가 없습니다.'
            : 'No messages in @moriknit inbox.',
        rows: 4,
      ),
      builder: (rooms) => ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: rooms.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: C.bd.withValues(alpha: 0.4)),
        itemBuilder: (context, i) {
          final room = rooms[i];
          final isSelected = room.id == selectedRoomId;
          return _InboxUserTile(
            room: room,
            isSelected: isSelected,
            isKorean: isKorean,
            onTap: () => onSelect(room.id, room),
          );
        },
      ),
    );
  }
}

class _InboxUserTile extends StatelessWidget {
  final DmRoom room;
  final bool isSelected;
  final bool isKorean;
  final VoidCallback onTap;

  const _InboxUserTile({
    required this.room,
    required this.isSelected,
    required this.isKorean,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final userUid = room.otherUid(SystemUsers.moriknitUid);
    final name = room.participantNames[userUid] ?? '';
    final handle = room.participantHandles[userUid] ?? '';
    final photo = room.participantPhotos[userUid] ?? '';
    final unread = room.unreadByAdmin;
    final unrespondedLabel = room.unrespondedLabel(isKorean: isKorean);
    final hasUnresponded = room.unrespondedSince != null;

    return Material(
      color: isSelected ? C.lvL.withValues(alpha: 0.5) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(photoUrl: photo, displayName: name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name.isEmpty ? (isKorean ? '(이름 없음)' : '(no name)') : name,
                            style: T.bodyBold.copyWith(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (handle.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '@$handle',
                              style: T.caption.copyWith(
                                color: C.lvD,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: C.og,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unread',
                              style: T.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.lastMessage.isEmpty
                          ? (isKorean ? '(메시지 없음)' : '(no messages)')
                          : room.lastMessage,
                      style: T.caption.copyWith(color: C.mu, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasUnresponded) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            unrespondedLabel,
                            style: T.caption.copyWith(
                              color: const Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ] else if (room.lastMessageAt.year > 2000) ...[
                      const SizedBox(height: 4),
                      Text(
                        room.timeAgo,
                        style: T.caption.copyWith(color: C.mu, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  const _Avatar({required this.photoUrl, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';
    if (photoUrl.isEmpty) {
      return CircleAvatar(
        radius: 18,
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
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => CircleAvatar(
          radius: 18,
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
