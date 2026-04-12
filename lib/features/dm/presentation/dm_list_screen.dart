import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dm_provider.dart';
import '../../../providers/ui_copy_provider.dart';

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

  Future<void> _openDm(Map<String, String> targetUser, String myUid, String myName) async {
    final repo = ref.read(dmRepositoryProvider);
    final isKorean = ref.read(appLanguageProvider).isKorean;
    try {
      final roomId = await repo.getOrCreateRoom(
        uid1: myUid,
        name1: myName,
        uid2: targetUser['uid']!,
        name2: targetUser['displayName']!,
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
      return Scaffold(
        backgroundColor: Colors.transparent,
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            MoriPageHeaderShell(
              child: MoriWideHeader(
                title: isKorean ? '모리톡' : 'MoriTalk',
                subtitle: subtitle,
              ),
            ),
            // 검색창
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: (q) => _onSearchChanged(q, user.uid),
                decoration: InputDecoration(
                  hintText: isKorean ? '닉네임 검색' : 'Search nickname',
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
            // 검색 결과 또는 DM 목록
            Expanded(
              child: _searching
                  ? _buildSearchResults(isKorean, user.uid, myName)
                  : _buildRoomList(roomsAsync, user.uid, isKorean),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isKorean, String myUid, String myName) {
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: () => _openDm(u, myUid, myName),
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
                          Text(name, style: T.bodyBold),
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
            final unread = room.unreadFor(uid);
            return GlassCard(
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
                            Expanded(
                              child: Text(
                                otherName.isEmpty ? (isKorean ? '알 수 없음' : 'Unknown') : otherName,
                                style: T.bodyBold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
            );
          },
        );
      },
    );
  }
}
