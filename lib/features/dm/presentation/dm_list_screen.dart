import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dm_provider.dart';
import '../../../providers/ui_copy_provider.dart';

/// @moriknit 공식 상담 계정의 displayName. 게스트도 이 계정에는 메시지 전송 가능.
const String _kMoriKnitSupportName = 'moriknit';

class DmListScreen extends ConsumerStatefulWidget {
  const DmListScreen({super.key});

  @override
  ConsumerState<DmListScreen> createState() => _DmListScreenState();
}

class _DmListScreenState extends ConsumerState<DmListScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<Map<String, String>> _searchResults = [];
  bool _searching = false;
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String q, String myUid) async {
    // @ 접두사 제거 (UI prefix 위젯이 있어 사용자가 @를 직접 입력할 수 있음)
    final cleanQ = q.replaceAll(RegExp(r'^@+'), '').trim();
    if (cleanQ.isEmpty) {
      setState(() { _searchResults = []; _searching = false; });
      return;
    }
    setState(() { _searching = true; _searchLoading = true; });
    final repo = ref.read(dmRepositoryProvider);
    final results = await repo.searchUsers(cleanQ, excludeUid: myUid);
    if (mounted) setState(() { _searchResults = results; _searchLoading = false; });
  }

  Future<void> _openDm(Map<String, String> targetUser, String myUid, String myName, {String myHandle = ''}) async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final isAnonymous = ref.read(isAnonymousUserProvider);

    // 게스트 사용자는 @moriknit 상담 채널 외에는 메시지 전송 불가
    if (isAnonymous) {
      final targetName = (targetUser['displayName'] ?? '').toLowerCase();
      if (targetName != _kMoriKnitSupportName) {
        await _showGuestBlockDialog(isKorean);
        return;
      }
    }

    final repo = ref.read(dmRepositoryProvider);
    try {
      final roomId = await repo.getOrCreateRoom(
        uid1: myUid,
        name1: myName,
        handle1: myHandle,
        uid2: targetUser['uid']!,
        name2: targetUser['displayName']!,
        handle2: targetUser['handle'] ?? '',
      );
      if (!mounted) return;
      // 검색 초기화
      _searchCtrl.clear();
      setState(() { _searching = false; _searchResults = []; });
      context.push('/dm/$roomId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '오류: $e' : 'Error: $e')),
      );
    }
  }

  /// 게스트 사용자가 일반 회원에게 메시지를 시도할 때 표시하는 안내 다이얼로그.
  Future<void> _showGuestBlockDialog(bool isKorean) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: C.lvL, shape: BoxShape.circle),
              child: Icon(Icons.person_add_alt_1_rounded, color: C.lvD, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isKorean ? '정식 회원만 이용 가능합니다' : 'Members only',
                style: T.h3,
              ),
            ),
          ],
        ),
        content: Text(
          isKorean
              ? '정식 회원 가입 후 이용 가능합니다.\n지금 게스트 모드에서 작업한 내용은\n계정에 그대로 연결됩니다.'
              : 'Please sign up to send messages.\nYour current guest data will be\nlinked to your new account.',
          style: T.body.copyWith(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isKorean ? '다음에' : 'Later',
              style: TextStyle(color: C.mu),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isKorean ? '가입하기' : 'Sign up',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      context.push('/login');
    }
  }

  /// 채팅방 삭제 확인 다이얼로그.
  Future<void> _confirmDeleteRoom(String roomId, bool isKorean) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isKorean ? '대화를 삭제할까요?' : 'Delete conversation?', style: T.h3),
        content: Text(
          isKorean
              ? '삭제된 대화는 복구할 수 없습니다.'
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
        task: () => ref.read(dmRepositoryProvider).deleteRoom(roomId),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isKorean ? '대화가 삭제됐습니다.' : 'Conversation deleted.')),
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
    final uiCopy = ref.watch(uiCopyProvider).valueOrNull;
    final subtitle = resolveUiCopy(
      data: uiCopy,
      language: language,
      key: 'dm_header_subtitle',
      fallback: isKorean ? '따뜻한 메시지를 주고받아 보세요' : 'Exchange warm messages',
    );

    if (user == null) {
      return AppShellScaffold(
        showHeader: false,
        body: Center(
          child: MoriEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: C.lv,
            title: isKorean ? '로그인이 필요해요' : 'Login required',
            subtitle: isKorean ? '메시지를 보내려면 로그인해 주세요.' : 'Please log in to send messages.',
          ),
        ),
      );
    }

    final roomsAsync = ref.watch(dmRoomsProvider(user.uid));
    final myName = (user.displayName?.isNotEmpty == true)
        ? user.displayName!
        : (user.email?.split('@').first ?? '');
    // 이슈 #771 — 내 핸들 (DM 방 생성 시 스냅샷 저장)
    final myProfile = ref.watch(currentUserProvider).valueOrNull;
    final myHandle = myProfile?.handle ?? '';

    return AppShellScaffold(
      title: isKorean ? '모리톡' : 'MoriTalk',
      subtitle: subtitle,
      aboveBody: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: (q) => _onSearchChanged(q, user.uid),
          decoration: InputDecoration(
            hintText: isKorean ? '닉네임/핸들 검색' : 'Search nickname/handle',
            prefix: Text('@', style: TextStyle(color: C.mu, fontWeight: FontWeight.w500)),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                      setState(() { _searching = false; _searchResults = []; });
                    },
                    child: Icon(Icons.close_rounded, color: C.mu, size: 18),
                  )
                : Icon(Icons.person_search_rounded, color: C.mu, size: 20),
            filled: true,
            fillColor: C.gx,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
      body: _searching
          ? _buildSearchResults(isKorean, user.uid, myName, myHandle)
          : _buildRoomList(roomsAsync, user.uid, isKorean),
    );
  }

  Widget _buildSearchResults(bool isKorean, String myUid, String myName, String myHandle) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        // 검색 결과
        if (_searchLoading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searching && _searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(child: Text(isKorean ? '검색 결과가 없어요' : 'No results found',
                style: T.caption.copyWith(color: C.mu))),
          )
        else
          ...List.generate(_searchResults.length, (i) {
            final u = _searchResults[i];
            final name = u['displayName'] ?? '';
            // 이슈 #771 — 핸들 표시
            final handle = u['handle'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: () => _openDm(u, myUid, myName, myHandle: myHandle),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: C.lvL,
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                        style: TextStyle(color: C.lvD, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(name, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (handle.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('@$handle',
                                    style: T.caption.copyWith(color: C.lvD, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ],
                          ),
                          Text(u['email'] ?? '', style: T.caption.copyWith(color: C.mu)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRoomList(AsyncValue<List<dynamic>> roomsAsync, String uid, bool isKorean) {
    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 40, color: C.mu),
              const SizedBox(height: 12),
              Text(
                isKorean ? '대화 목록을 불러올 수 없어요.' : 'Failed to load conversations.',
                style: T.bodyBold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                isKorean ? '잠시 후 다시 시도해 주세요.' : 'Please try again later.',
                style: T.caption.copyWith(color: C.mu),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (rooms) {
        if (rooms.isEmpty) {
          return Center(
            child: MoriEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: C.lv,
              title: isKorean ? '아직 대화가 없어요' : 'No conversations yet',
              subtitle: isKorean
                  ? '위 검색창에서 닉네임을 입력해\n새 대화를 시작해보세요.'
                  : 'Search a nickname above\nto start a new conversation.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          itemCount: rooms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final room = rooms[index];
            final otherName = room.otherName(uid);
            final otherPhoto = room.otherPhoto(uid);
            // 이슈 #771 — 상대방 핸들 표시
            final otherHandle = room.otherHandle(uid);
            final unread = room.unreadFor(uid);
            return GestureDetector(
              onLongPress: () => _showRoomOptions(room.id, isKorean),
              child: GlassCard(
                onTap: () => context.push('/dm/${room.id}'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: C.lvL,
                      backgroundImage: otherPhoto.isNotEmpty ? NetworkImage(otherPhoto) : null,
                      child: otherPhoto.isEmpty
                          ? Text(
                              otherName.isNotEmpty ? otherName.substring(0, 1).toUpperCase() : '?',
                              style: TextStyle(color: C.lvD, fontWeight: FontWeight.w700, fontSize: 15),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  otherName.isEmpty ? (isKorean ? '알 수 없음' : 'Unknown') : otherName,
                                  style: T.bodyBold,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // 이슈 #771 — @handle 작은 표시
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
                              const Spacer(),
                              Text(room.timeAgo, style: T.caption.copyWith(color: C.mu)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  room.lastMessage,
                                  style: T.caption.copyWith(color: C.mu),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unread > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: C.pk,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 채팅방 아이템 길게 누를 때 팝업 옵션 표시.
  void _showRoomOptions(String roomId, bool isKorean) {
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
                isKorean ? '대화 삭제' : 'Delete conversation',
                style: T.body.copyWith(color: C.og),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDeleteRoom(roomId, isKorean);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
