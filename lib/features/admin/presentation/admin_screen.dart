import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/editorial_provider.dart';
import '../../../providers/template_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../home/domain/editorial_post.dart';
import '../../project/domain/builtin_template.dart';
import '../data/admin_bulk_import_service.dart';
import '../domain/admin_import_models.dart';
import '../../blueprint/data/blueprint_migration.dart';
import '../../landing/data/landing_board_repository.dart';
import '../../pattern/data/pattern_repository.dart';
import 'widgets/admin_list_shell.dart';
import 'widgets/admin_ai_fix_panel.dart';
import 'widgets/dashboard/usage_metrics_section.dart';
import 'widgets/dashboard/traffic_metrics_section.dart';
import 'widgets/dashboard/ops_metrics_section.dart';
import 'widgets/dashboard/market_metrics_section.dart';
import 'widgets/dashboard/ai_metrics_section.dart';
import '../../my/data/bug_report_repository.dart';
import '../../my/domain/bug_report.dart';

/// Firestore 일괄 삭제 헬퍼 — 500건 단위 batch 분할. (이슈 #805)
Future<void> _bulkDeleteDocs(List<DocumentReference> refs) async {
  const chunkSize = 450; // 500 한도 여유 두기
  for (var i = 0; i < refs.length; i += chunkSize) {
    final end = (i + chunkSize < refs.length) ? i + chunkSize : refs.length;
    final batch = FirebaseFirestore.instance.batch();
    for (final r in refs.sublist(i, end)) {
      batch.delete(r);
    }
    await batch.commit();
  }
}

/// Firestore 일괄 업데이트 헬퍼 — 500건 단위 batch 분할.
Future<void> _bulkUpdateDocs(
  List<DocumentReference> refs,
  Map<String, dynamic> data,
) async {
  const chunkSize = 450;
  for (var i = 0; i < refs.length; i += chunkSize) {
    final end = (i + chunkSize < refs.length) ? i + chunkSize : refs.length;
    final batch = FirebaseFirestore.instance.batch();
    for (final r in refs.sublist(i, end)) {
      batch.set(r, data, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

final _adminUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(250)
      .snapshots()
      .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
});

final _adminImportLogsProvider =
    StreamProvider.family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, AdminImportKind>((ref, kind) {
  return FirebaseFirestore.instance
      .collection('admin_import_logs')
      .where('kind', isEqualTo: kind.key)
      .orderBy('createdAt', descending: true)
      .limit(12)
      .snapshots()
      .map((snap) => snap.docs);
});

final _uiCopyDocProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('ui_copy')
      .snapshots()
      .map((doc) => doc.data() ?? <String, dynamic>{});
});

final _socialConfigProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('social_integrations')
      .snapshots()
      .map((doc) => doc.data() ?? <String, dynamic>{});
});

final _supportConfigProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('admin_support')
      .snapshots()
      .map((doc) => doc.data() ?? <String, dynamic>{});
});

final _memberAdminFlagProvider = StreamProvider.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists);
});

final _inquiriesProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collection('landing_boards')
      .doc('qa')
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>());
});

final _memberBlockedFlagProvider = StreamProvider.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['isBlocked'] == true);
});

final _adminCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final db = FirebaseFirestore.instance;
  final results = await Future.wait([
    db.collection('users').limit(300).get(),
    db.collection('market_items').limit(300).get(),
    db.collection('encyclopedia').limit(300).get(),
    db.collection('posts').limit(300).get(),
  ]);

  return {
    'users': results[0].size,
    'market': results[1].size,
    'encyclopedia': results[2].size,
    'posts': results[3].size,
  };
});

final _pendingMarketItemsProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collection('market_items')
      .where('status', isEqualTo: 'pending')
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs);
});

final _pendingEncyclopediaProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collection('encyclopedia')
      .where('status', whereIn: ['draft', 'submitted', 'pending'])
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs);
});

final _dataHealthProvider = FutureProvider<Map<String, int>>((ref) async {
  final db = FirebaseFirestore.instance;
  final market = await db.collection('market_items').limit(200).get();
  final encyclopedia = await db.collection('encyclopedia').limit(200).get();
  final posts = await db.collection('posts').limit(200).get();

  int marketMissingTitle = 0;
  int marketMissingCategory = 0;
  for (final doc in market.docs) {
    final data = doc.data();
    if ((data['title'] as String?)?.trim().isEmpty ?? true) marketMissingTitle++;
    if ((data['category'] as String?)?.trim().isEmpty ?? true) marketMissingCategory++;
  }

  int encyclopediaMissingTerm = 0;
  int encyclopediaMissingCategory = 0;
  for (final doc in encyclopedia.docs) {
    final data = doc.data();
    if ((data['term'] as String?)?.trim().isEmpty ?? true) encyclopediaMissingTerm++;
    if ((data['category'] as String?)?.trim().isEmpty ?? true) encyclopediaMissingCategory++;
  }

  int postMissingTitle = 0;
  for (final doc in posts.docs) {
    final data = doc.data();
    if ((data['title'] as String?)?.trim().isEmpty ?? true) postMissingTitle++;
  }

  return {
    'marketMissingTitle': marketMissingTitle,
    'marketMissingCategory': marketMissingCategory,
    'encyclopediaMissingTerm': encyclopediaMissingTerm,
    'encyclopediaMissingCategory': encyclopediaMissingCategory,
    'postMissingTitle': postMissingTitle,
  };
});

// ── 어드민 네비게이션 아이템 (그룹 헤더 + 탭) ────────────────────────────────
class _AdminNavItem {
  final String? groupLabel;
  final IconData? icon;
  final String label;
  final Color color;
  final int? tabIndex;

  const _AdminNavItem.tab({required int index, required this.icon, required this.label, required this.color})
      : groupLabel = null,
        tabIndex = index;

  const _AdminNavItem.group({required this.label, required this.color, IconData? groupIcon})
      : groupLabel = label,
        icon = groupIcon,
        tabIndex = null;

  bool get isGroup => groupLabel != null;
}

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1020),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16)],
            ),
            child: SafeArea(
              child: auth.when(
                data: (user) {
                  if (user == null) return const _AdminNotLoggedIn();
                  return isAdmin.when(
                    data: (allowed) {
                      if (!allowed) {
                        return _AdminMessageState(
                          title: isKorean ? '권한이 없습니다' : 'Admin permission required',
                          body: isKorean ? '현재 계정에는 관리자 권한이 없습니다.' : 'This account does not have admin permission.',
                        );
                      }
                      return _AdminConsole(user: user, isKorean: isKorean);
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _AdminMessageState(title: isKorean ? '권한 확인 실패' : 'Permission check failed', body: e.toString()),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _AdminMessageState(title: isKorean ? '로그인 상태 확인 불가' : 'Unable to read auth state', body: e.toString()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminConsole extends StatefulWidget {
  final User user;
  final bool isKorean;
  const _AdminConsole({required this.user, required this.isKorean});
  @override
  State<_AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<_AdminConsole> {
  int _selectedIndex = 0;

  static final _navItems = [
    _AdminNavItem.tab(index: 0, icon: Icons.dashboard_rounded, label: '대시보드', color: Color(0xFFA3E635)),

    _AdminNavItem.group(label: '뜨개 자료', color: Color(0xFF4ADE80), groupIcon: Icons.collections_bookmark_rounded),
    _AdminNavItem.tab(index: 13, icon: Icons.folder_special_rounded, label: '기본 템플릿', color: Color(0xFF4ADE80)),
    _AdminNavItem.tab(index: 1, icon: Icons.menu_book_rounded, label: '뜨개백과', color: Color(0xFF4ADE80)),
    _AdminNavItem.tab(index: 2, icon: Icons.grass_rounded, label: '실 브랜드', color: Color(0xFF4ADE80)),
    _AdminNavItem.tab(index: 3, icon: Icons.straighten_rounded, label: '바늘 브랜드', color: Color(0xFF4ADE80)),

    _AdminNavItem.group(label: '사용자 데이터', color: Color(0xFFB47EEB), groupIcon: Icons.manage_accounts_rounded),
    _AdminNavItem.tab(index: 4, icon: Icons.people_rounded, label: '회원', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 21, icon: Icons.bar_chart_rounded, label: '사용자 통합관리', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 5, icon: Icons.auto_fix_high_rounded, label: '도안목록', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 6, icon: Icons.palette_rounded, label: '스와치', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 7, icon: Icons.folder_copy_rounded, label: '프로젝트', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 22, icon: Icons.list_alt_rounded, label: '템플릿', color: Color(0xFFB47EEB)),

    _AdminNavItem.group(label: '콘텐츠', color: Color(0xFFF472B6), groupIcon: Icons.article_rounded),
    _AdminNavItem.tab(index: 8, icon: Icons.storefront_rounded, label: '마켓상품', color: Color(0xFFF472B6)),
    _AdminNavItem.tab(index: 9, icon: Icons.forum_rounded, label: '커뮤니티', color: Color(0xFFF472B6)),
    _AdminNavItem.tab(index: 20, icon: Icons.grid_view_rounded, label: '게시판 관리', color: Color(0xFFF472B6)),
    _AdminNavItem.tab(index: 15, icon: Icons.campaign_rounded, label: '공지사항', color: Color(0xFFF472B6)),
    _AdminNavItem.tab(index: 16, icon: Icons.star_rounded, label: '리뷰 게시판', color: Color(0xFFF472B6)),
    _AdminNavItem.tab(index: 17, icon: Icons.new_releases_rounded, label: '릴리즈노트', color: Color(0xFFF472B6)),
    _AdminNavItem.tab(index: 18, icon: Icons.help_outline_rounded, label: '문의하기 Q&A', color: Color(0xFFF472B6)),

    _AdminNavItem.group(label: '운영 지원', color: Color(0xFF94A3B8), groupIcon: Icons.support_agent_rounded),
    _AdminNavItem.tab(index: 10, icon: Icons.text_fields_rounded, label: '문구관리', color: Color(0xFF94A3B8)),
    _AdminNavItem.tab(index: 11, icon: Icons.bug_report_rounded, label: '버그리포트', color: Color(0xFFFB7185)),
    _AdminNavItem.tab(index: 19, icon: Icons.mail_rounded, label: '1:1 문의', color: Color(0xFF34D399)),
    _AdminNavItem.tab(index: 12, icon: Icons.newspaper_rounded, label: '에디토리얼', color: Color(0xFF38BDF8)),
    _AdminNavItem.tab(index: 23, icon: Icons.campaign_outlined, label: '팝업 설정', color: Color(0xFF94A3B8)),

    _AdminNavItem.group(label: '랜딩 사이트', color: Color(0xFF6EE7B7), groupIcon: Icons.web_rounded),
    _AdminNavItem.tab(index: 24, icon: Icons.smartphone_rounded, label: '목업 이미지', color: Color(0xFF6EE7B7)),

    _AdminNavItem.group(label: '설정', color: Color(0xFF64748B), groupIcon: Icons.tune_rounded),
    _AdminNavItem.tab(index: 14, icon: Icons.settings_rounded, label: '설정', color: Color(0xFF64748B)),
    _AdminNavItem.tab(index: 25, icon: Icons.transform_rounded, label: '#687 마이그레이션', color: Color(0xFFFB923C)),
  ];

  String get _currentPageLabel {
    for (final item in _navItems) {
      if (item.tabIndex == _selectedIndex) return item.label;
    }
    return '대시보드';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── 사이드바 ─────────────────────────────────────────────────────────
        _AdminSidebar(
          navItems: _navItems,
          selectedIndex: _selectedIndex,
          user: widget.user,
          onSelect: (i) => setState(() => _selectedIndex = i),
        ),
        // ── 콘텐츠 영역 ─────────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 콘텐츠 상단 헤더
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
                ),
                child: Row(
                  children: [
                    Text(_currentPageLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC))),
                    const Spacer(),
                    Text(DateFormat('yyyy.MM.dd').format(DateTime.now()),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:  return _DashboardTab(isKorean: widget.isKorean, onTabChange: (i) => setState(() => _selectedIndex = i));
      case 1:  return _EncyclopediaTab(isKorean: widget.isKorean, adminUid: widget.user.uid);
      case 2:  return _BrandTab(collection: 'yarn_brands', title: '실 브랜드');
      case 3:  return _BrandTab(collection: 'needle_brands', title: '바늘 브랜드');
      case 4:  return _MembersTab(isKorean: widget.isKorean);
      case 5:  return const _AdminPatternsTab();
      case 6:  return const _AdminSwatchesTab();
      case 7:  return const _AdminProjectsTab();
      case 8:  return _CollectionWithImportTab(collection: 'market_items', title: '마켓상품', importKind: AdminImportKind.market, isKorean: widget.isKorean, adminUid: widget.user.uid);
      case 9:  return const _CommunityAdminTab();
      case 10: return _CopyManagementTab(isKorean: widget.isKorean);
      case 11: return const _BugReportsTab();
      case 19: return const _InquiriesAdminTab();
      case 12: return const _EditorialAdminTab();
      case 13: return const _BuiltinTemplateAdminTab();
      case 14: return _SettingsTab(isKorean: widget.isKorean);
      case 15: return const _NoticesAdminTab();
      case 16: return const _LandingBoardAdminTab(boardType: 'review', title: '리뷰 게시판');
      case 17: return const _LandingBoardAdminTab(boardType: 'release', title: '릴리즈노트');
      case 18: return const _LandingBoardAdminTab(boardType: 'qa', title: '문의하기 Q&A');
      case 20: return const _BoardManagementTab();
      case 21: return const _UserStatsAdminTab();
      case 22: return const _AdminTemplatesTab();
      case 23: return _SupportSettingsTab(isKorean: widget.isKorean);
      case 24: return const _MockupImagesAdminTab();
      case 25: return _BlueprintMigrationTab(isKorean: widget.isKorean, adminUid: widget.user.uid);
      default: return _DashboardTab(isKorean: widget.isKorean, onTabChange: (i) => setState(() => _selectedIndex = i));
    }
  }
}


class _AdminSidebar extends StatefulWidget {
  final List<_AdminNavItem> navItems;
  final int selectedIndex;
  final User user;
  final void Function(int) onSelect;

  const _AdminSidebar({
    required this.navItems,
    required this.selectedIndex,
    required this.user,
    required this.onSelect,
  });

  @override
  State<_AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<_AdminSidebar> {
  static const _bg = Color(0xFF1E293B);
  static const _divider = Color(0x33FFFFFF);
  static const _textDim = Color(0xFFCBD5E1);

  late final Set<String> _expandedGroups;

  @override
  void initState() {
    super.initState();
    // 현재 선택된 메뉴가 속한 그룹만 펼치고 나머지는 접음
    _expandedGroups = _getGroupOfTab(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(_AdminSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 선택된 탭이 변경되면 해당 그룹을 자동으로 펼침
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final group = _getGroupLabel(widget.selectedIndex);
      if (group != null && !_expandedGroups.contains(group)) {
        setState(() => _expandedGroups.add(group));
      }
    }
  }

  /// 특정 탭이 속한 그룹 레이블 반환
  String? _getGroupLabel(int tabIndex) {
    String? currentGroup;
    for (final item in widget.navItems) {
      if (item.isGroup) {
        currentGroup = item.label;
      } else if (item.tabIndex == tabIndex) {
        return currentGroup;
      }
    }
    return null;
  }

  /// 특정 탭이 속한 그룹 Set 반환 (대시보드처럼 그룹 없는 경우 빈 Set)
  Set<String> _getGroupOfTab(int tabIndex) {
    final group = _getGroupLabel(tabIndex);
    if (group != null) return {group};
    return {};
  }

  void _toggleGroup(String groupLabel) {
    setState(() {
      if (_expandedGroups.contains(groupLabel)) {
        _expandedGroups.remove(groupLabel);
      } else {
        _expandedGroups.add(groupLabel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 헤더 ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _divider, width: 1)),
            ),
            child: Row(
              children: [
                Image.asset('assets/login_logo.png', width: 30, height: 30, fit: BoxFit.contain),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('MoriKnit',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                    Text('Admin Console',
                        style: TextStyle(color: Color(0xFF84CC16), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  ],
                ),
              ],
            ),
          ),
          // ── 네비게이션 ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildNavItems(),
              ),
            ),
          ),
          // ── 하단 유틸 ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _divider, width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF334155),
                      backgroundImage: widget.user.photoURL != null ? NetworkImage(widget.user.photoURL!) : null,
                      child: widget.user.photoURL == null
                          ? const Icon(Icons.person_rounded, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.user.displayName ?? widget.user.email ?? '관리자',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SidebarUtilBtn(
                        icon: Icons.open_in_new_rounded,
                        label: '앱으로',
                        onTap: () => launchUrl(Uri.parse('https://moriknit.com'), mode: LaunchMode.externalApplication),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SidebarUtilBtn(
                        icon: Icons.logout_rounded,
                        label: '로그아웃',
                        onTap: () => FirebaseAuth.instance.signOut(),
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
  }

  List<Widget> _buildNavItems() {
    final result = <Widget>[];
    String? currentGroup;
    bool currentGroupExpanded = true;

    for (final item in widget.navItems) {
      if (item.isGroup) {
        currentGroup = item.label;
        currentGroupExpanded = _expandedGroups.contains(currentGroup);
        final isExpanded = currentGroupExpanded;
        final groupLabel = currentGroup;

        result.add(
          GestureDetector(
            onTap: () => _toggleGroup(groupLabel),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 6),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 12, color: item.color),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      item.label.toUpperCase(),
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: item.color, letterSpacing: 1.0),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 14,
                    color: item.color.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // 그룹에 속하지 않는 항목(대시보드)은 항상 표시
        if (currentGroup == null || currentGroupExpanded) {
          final isSelected = item.tabIndex == widget.selectedIndex;
          final accent = item.color;
          result.add(
            GestureDetector(
              onTap: () => widget.onSelect(item.tabIndex!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: isSelected ? accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 15, color: isSelected ? accent : _textDim),
                    const SizedBox(width: 9),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? Colors.white : _textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }
    return result;
  }
}

class _SidebarUtilBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SidebarUtilBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

/// 비로그인 상태에서 어드민 진입 시 안내 화면을 거치지 않고 즉시 /login 으로 redirect.
/// admin_router 의 redirect 로직과 함께 작동 — 일시적 timing 진입을 즉시 우회.
class _AdminNotLoggedIn extends StatefulWidget {
  const _AdminNotLoggedIn();

  @override
  State<_AdminNotLoggedIn> createState() => _AdminNotLoggedInState();
}

class _AdminNotLoggedInState extends State<_AdminNotLoggedIn> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _AdminMessageState extends StatelessWidget {
  final String title;
  final String body;

  const _AdminMessageState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: C.lvD, size: 42),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(body, style: T.body.copyWith(color: C.tx2), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 브랜드 탭 (실/바늘 브랜드 compact list) ────────────────────────────────
class _BrandTab extends StatefulWidget {
  final String collection;
  final String title;
  const _BrandTab({required this.collection, required this.title});

  @override
  State<_BrandTab> createState() => _BrandTabState();
}

class _BrandTabState extends State<_BrandTab> {
  String? _expandedId;

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final countryCtrl = TextEditingController();
    final websiteCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isActive = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text('${widget.title} 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '브랜드명 *')),
                const SizedBox(height: 8),
                TextField(controller: countryCtrl, decoration: const InputDecoration(labelText: '국가')),
                const SizedBox(height: 8),
                TextField(controller: websiteCtrl, decoration: const InputDecoration(labelText: '홈페이지 URL')),
                const SizedBox(height: 8),
                TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: '연락처')),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '메모')),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('활성화'),
                  const Spacer(),
                  Switch(value: isActive, onChanged: (v) => ss(() => isActive = v)),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await FirebaseFirestore.instance.collection(widget.collection).add({
                  'name': name,
                  'country': countryCtrl.text.trim(),
                  'website': websiteCtrl.text.trim(),
                  'contact': contactCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  'is_active': isActive,
                  'sort_order': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose(); countryCtrl.dispose(); websiteCtrl.dispose();
      contactCtrl.dispose(); notesCtrl.dispose();
    });
  }

  void _showEditDialog(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final nameCtrl = TextEditingController(text: data['name'] as String? ?? '');
    final countryCtrl = TextEditingController(text: data['country'] as String? ?? '');
    final websiteCtrl = TextEditingController(text: data['website'] as String? ?? '');
    final contactCtrl = TextEditingController(text: data['contact'] as String? ?? '');
    final notesCtrl = TextEditingController(text: data['notes'] as String? ?? '');
    bool isActive = data['is_active'] as bool? ?? true;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text('${widget.title} 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '브랜드명 *')),
                const SizedBox(height: 8),
                TextField(controller: countryCtrl, decoration: const InputDecoration(labelText: '국가')),
                const SizedBox(height: 8),
                TextField(controller: websiteCtrl, decoration: const InputDecoration(labelText: '홈페이지 URL')),
                const SizedBox(height: 8),
                TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: '연락처')),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '메모')),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('활성화'),
                  const Spacer(),
                  Switch(value: isActive, onChanged: (v) => ss(() => isActive = v)),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await doc.reference.update({
                  'name': name,
                  'country': countryCtrl.text.trim(),
                  'website': websiteCtrl.text.trim(),
                  'contact': contactCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  'is_active': isActive,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose(); countryCtrl.dispose(); websiteCtrl.dispose();
      contactCtrl.dispose(); notesCtrl.dispose();
    });
  }

  Future<void> _confirmDelete(DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('브랜드 삭제'),
        content: const Text('이 브랜드를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text('${widget.title} 추가'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(widget.collection)
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(child: Text('등록된 브랜드가 없습니다.', style: TextStyle(color: C.mu)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final name = data['name'] as String? ?? '(이름 없음)';
                  final country = data['country'] as String? ?? '';
                  final website = data['website'] as String? ?? '';
                  final contact = data['contact'] as String? ?? '';
                  final notes = data['notes'] as String? ?? '';
                  final isActive = data['is_active'] as bool? ?? true;
                  final isExpanded = _expandedId == doc.id;

                  return GestureDetector(
                    onTap: () => setState(() => _expandedId = isExpanded ? null : doc.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isExpanded ? C.lvL : Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isExpanded ? C.lv.withValues(alpha: 0.4) : C.bd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 컴팩트 헤더
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: isActive ? C.lv : Colors.grey.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ),
                                if (country.isNotEmpty)
                                  Text(country, style: TextStyle(color: C.mu, fontSize: 12)),
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  size: 18, color: C.mu,
                                ),
                              ],
                            ),
                          ),
                          // 확장 영역
                          if (isExpanded) ...[
                            Divider(height: 1, color: C.bd),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (website.isNotEmpty) _BrandInfoRow(Icons.language_rounded, '홈페이지', website),
                                  if (contact.isNotEmpty) _BrandInfoRow(Icons.phone_rounded, '연락처', contact),
                                  if (notes.isNotEmpty) _BrandInfoRow(Icons.notes_rounded, '메모', notes),
                                  if (website.isEmpty && contact.isEmpty && notes.isEmpty)
                                    Text('추가 정보 없음', style: TextStyle(color: C.mu, fontSize: 12)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showEditDialog(doc),
                                        icon: const Icon(Icons.edit_outlined, size: 15),
                                        label: const Text('수정'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: C.lvD,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton.icon(
                                        onPressed: () => _confirmDelete(doc),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 15),
                                        label: const Text('삭제'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red.shade400,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BrandInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _BrandInfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: C.mu),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: C.mu, fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _CollectionWithImportTab extends ConsumerStatefulWidget {
  final String collection;
  final String title;
  final AdminImportKind importKind;
  final bool isKorean;
  final String adminUid;
  const _CollectionWithImportTab({
    required this.collection,
    required this.title,
    required this.importKind,
    required this.isKorean,
    required this.adminUid,
  });

  @override
  ConsumerState<_CollectionWithImportTab> createState() => _CollectionWithImportTabState();
}

class _CollectionWithImportTabState extends ConsumerState<_CollectionWithImportTab> {
  AdminImportPreview? _preview;
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(widget.collection).limit(100);

    return Column(
      children: [
        // 상단: 목록
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(20)),
                          child: Text('${docs.length}', style: TextStyle(color: C.lvD, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: docs.isEmpty
                        ? Center(child: Text('항목이 없습니다.', style: TextStyle(color: C.mu)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: docs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) => _CollectionDocRow(
                              doc: docs[index],
                              collection: widget.collection,
                              isKorean: widget.isKorean,
                              index: index,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        // 하단: 일괄등록 펼침 섹션
        GlassCard(
          child: ExpansionTile(
            initiallyExpanded: false,
            title: Text(widget.isKorean ? '일괄등록' : 'Bulk import', style: T.bodyBold),
            leading: Icon(Icons.upload_rounded, color: C.lv),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isBusy ? null : _downloadCsvTemplate,
                          icon: const Icon(Icons.description_rounded),
                          label: Text(widget.isKorean ? 'CSV 템플릿' : 'CSV template'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isBusy ? null : _downloadExcelTemplate,
                          icon: const Icon(Icons.grid_on_rounded),
                          label: Text(widget.isKorean ? '엑셀 템플릿' : 'Excel template'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : _pickImportFile,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: Text(widget.isKorean ? '파일 업로드' : 'Upload file'),
                        ),
                        if (_preview != null)
                          FilledButton.icon(
                            onPressed: _isBusy || _preview!.validCount == 0 ? null : _applyImport,
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: Text(widget.isKorean ? 'DB 반영' : 'Apply to DB'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _RequiredFieldGuide(kind: widget.importKind, isKorean: widget.isKorean),
                    if (_preview != null) ...[
                      const SizedBox(height: 12),
                      _PreviewCard(preview: _preview!, isKorean: widget.isKorean),
                    ],
                    const SizedBox(height: 12),
                    _RecentImportLogs(kind: widget.importKind, isKorean: widget.isKorean),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _downloadCsvTemplate() async {
    final bytes = Uint8List.fromList(utf8.encode(widget.importKind.buildTemplateCsv(widget.isKorean)));
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = '${widget.importKind.fileBaseName()}_$stamp.csv';
    await downloadBytes(bytes: bytes, mimeType: 'text/csv;charset=utf-8', fileName: fileName);
  }

  Future<void> _downloadExcelTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Template'];
    final rows = widget.importKind.buildTemplateCsv(widget.isKorean).split('\n').map((row) => row.split(',')).toList();
    final requiredSet = widget.importKind.requiredHeaders.toSet();
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#F3E8FF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final requiredStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFF59D'),
      horizontalAlign: HorizontalAlign.Center,
    );
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (var colIndex = 0; colIndex < row.length; colIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
        cell.value = TextCellValue(row[colIndex]);
        if (rowIndex == 0) {
          final header = row[colIndex];
          cell.cellStyle = requiredSet.contains(header) ? requiredStyle : headerStyle;
        } else if (rowIndex == 1) {
          cell.cellStyle = row[colIndex].toLowerCase().contains('required') || row[colIndex] == '필수'
              ? requiredStyle
              : headerStyle.copyWith(backgroundColorHexVal: ExcelColor.fromHexString('#F8FAFC'));
        }
      }
    }
    for (var colIndex = 0; colIndex < widget.importKind.headers.length; colIndex++) {
      sheet.setColumnWidth(colIndex, 22);
    }
    final bytes = Uint8List.fromList(excel.encode() ?? <int>[]);
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = '${widget.importKind.fileBaseName()}_$stamp.xlsx';
    await downloadBytes(
      bytes: bytes,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      fileName: fileName,
    );
  }

  Future<void> _pickImportFile() async {
    setState(() => _isBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls', 'tsv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;
      final preview = await ref.read(adminBulkImportServiceProvider).parseFile(
            kind: widget.importKind,
            fileName: result.files.single.name,
            bytes: result.files.single.bytes!,
          );
      if (!mounted) return;
      setState(() => _preview = preview);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _applyImport() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() => _isBusy = true);
    try {
      final result = await ref.read(adminBulkImportServiceProvider).applyPreview(
            preview: preview,
            adminUid: widget.adminUid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isKorean
                ? '${result.createdCount}건 반영, ${result.skippedCount}건 건너뜀'
                : '${result.createdCount} rows applied, ${result.skippedCount} skipped',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

// ── 마켓 썸네일 플레이스홀더 ───────────────────────────────────────────────────────
class _MarketThumbPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFFF0F0F0),
      child: const Icon(Icons.storefront_rounded, size: 24, color: Colors.grey),
    );
  }
}

// ── 상태 뱃지 ─────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('승인', Colors.green),
      'rejected' => ('거절', Colors.red),
      _ => ('대기', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: T.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

// ── 읽기전용 필드 헬퍼 ────────────────────────────────────────────────────────
class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadonlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.caption.copyWith(color: C.mu, fontSize: 11)),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: C.bg.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.bd),
          ),
          child: Text(value.isEmpty ? '-' : value, style: T.body.copyWith(color: C.tx2)),
        ),
      ],
    );
  }
}

// ── 컬렉션 문서 행 ─────────────────────────────────────────────────────────────
class _CollectionDocRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String collection;
  final bool isKorean;
  final int index;

  const _CollectionDocRow({
    required this.doc,
    required this.collection,
    required this.isKorean,
    this.index = 0,
  });

  String _primaryLabel() {
    final data = doc.data();
    return data['title'] as String? ??
        data['term'] as String? ??
        data['name'] as String? ??
        data['displayName'] as String? ??
        doc.id;
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    Widget rowContent;
    switch (collection) {
      case 'market_items':
        final category = data['category'] as String? ?? '';
        final price = data['price'];
        final priceStr = price != null ? '₩${price.toString()}' : '';
        final status = data['status'] as String? ?? 'pending';
        final imageUrl = data['imageUrl'] as String? ?? '';
        rowContent = Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _MarketThumbPlaceholder(),
                    )
                  : _MarketThumbPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_primaryLabel(), style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (category.isNotEmpty) ...[
                        Text(category, style: T.caption.copyWith(color: C.mu)),
                        const SizedBox(width: 8),
                      ],
                      if (priceStr.isNotEmpty) ...[
                        Text(priceStr, style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                      ],
                      _StatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('ID: ${doc.id}', style: T.caption.copyWith(color: C.mu, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: C.lv, size: 20),
          ],
        );
        break;
      case 'encyclopedia':
        final term = data['term'] as String? ?? _primaryLabel();
        final category = data['category'] as String? ?? '';
        final order = (data['order'] as num?)?.toInt() ?? (index + 1);
        rowContent = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 순서번호
            SizedBox(
              width: 40,
              child: Text(
                '$order',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
            Container(width: 1, height: 36, color: Colors.grey.shade300),
            const SizedBox(width: 10),
            // 제목
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(term, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(category, style: T.caption.copyWith(color: C.mu)),
                  ],
                  Text('ID: ${doc.id}', style: T.caption.copyWith(color: C.mu, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: C.lv, size: 20),
          ],
        );
        break;
      case 'posts':
        final author = data['authorName'] as String? ?? data['authorUid'] as String? ?? '';
        final createdAtRaw = data['createdAt'];
        final dateStr = createdAtRaw is Timestamp
            ? DateFormat('yyyy-MM-dd').format(createdAtRaw.toDate())
            : (createdAtRaw?.toString() ?? '').substring(0, (createdAtRaw?.toString() ?? '').length.clamp(0, 10));
        rowContent = Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_primaryLabel(), style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (author.isNotEmpty) ...[
                        Text(author, style: T.caption.copyWith(color: C.mu)),
                        const SizedBox(width: 8),
                      ],
                      if (dateStr.isNotEmpty)
                        Text(dateStr, style: T.caption.copyWith(color: C.mu)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('ID: ${doc.id}', style: T.caption.copyWith(color: C.mu, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: C.lv, size: 20),
          ],
        );
        break;
      default:
        final desc = data['description']?.toString();
        final secondary = data['category'] as String? ??
            data['status'] as String? ??
            data['email'] as String? ??
            (desc != null ? desc.substring(0, desc.length.clamp(0, 40)) : '');
        rowContent = Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_primaryLabel(), style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(secondary, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text('ID: ${doc.id}', style: T.caption.copyWith(color: C.mu, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: C.lv, size: 18),
          ],
        );
    }

    return GestureDetector(
      onTap: () => _showDetailDialog(context),
      child: GlassCard(child: rowContent),
    );
  }

  // ── 분기 진입점 ─────────────────────────────────────────────────────────────
  void _showDetailDialog(BuildContext context) {
    switch (collection) {
      case 'market_items':
        _showMarketDetailDialog(context);
        break;
      case 'encyclopedia':
        _showEncyclopediaDetailDialog(context);
        break;
      case 'posts':
        _showPostDetailDialog(context);
        break;
      default:
        _showGenericEditDialog(context);
    }
  }

  // ── 삭제 확인 공통 ──────────────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context, {String? customMessage}) async {
    // 도안/마켓 상품이면 판매 기록 먼저 확인
    if (collection == 'market_items') {
      try {
        final salesSnap = await FirebaseFirestore.instance
            .collectionGroup('market_purchases')
            .where('itemId', isEqualTo: doc.id)
            .limit(1)
            .get();
        final hasSales = salesSnap.docs.isNotEmpty;
        if (!context.mounted) return;
        if (hasSales) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('삭제 불가'),
              content: const Text('판매된 적이 있는 도안은 삭제할 수 없습니다.\n판매 기록 보호를 위해 상태를 \'판매 종료\'로 변경하세요.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
              ],
            ),
          );
          return;
        }
      } catch (_) {
        // 판매 기록 조회 실패 시 그냥 진행 (관리자는 강제 삭제 가능)
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(customMessage ?? '${_primaryLabel()}을(를) 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await FirebaseFirestore.instance.collection(collection).doc(doc.id).delete();
    }
  }

  // ── Firestore 저장 공통 ────────────────────────────────────────────────────
  Future<void> _saveToFirestore(BuildContext context, Map<String, dynamic> updated) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(doc.id).update(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수정됐어요'), duration: Duration(milliseconds: 1500)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red.shade400, duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  // ── 마켓 상품 다이얼로그 ────────────────────────────────────────────────────
  void _showMarketDetailDialog(BuildContext context) {
    final data = Map<String, dynamic>.from(doc.data());
    final titleCtrl = TextEditingController(text: data['title'] as String? ?? '');
    final descCtrl = TextEditingController(text: data['description'] as String? ?? '');
    final priceCtrl = TextEditingController(text: (data['price'] ?? '').toString());
    String category = data['category'] as String? ?? 'pattern';
    String status = data['status'] as String? ?? 'pending';
    bool isOfficial = data['isOfficial'] as bool? ?? false;
    final imageUrlCtrl = TextEditingController(text: data['imageUrl'] as String? ?? '');
    final pdfUrlCtrl = TextEditingController(text: data['pdfUrl'] as String? ?? '');
    final sellerUid = data['sellerUid'] as String? ?? data['uid'] as String? ?? '';

    const categories = ['pattern', 'book', 'kit', 'tool', 'yarn', 'other'];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('마켓 상품 수정: ${_primaryLabel()}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageUrlCtrl.text.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: imageUrlCtrl.text,
                          height: 120,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox(),
                        ),
                      ),
                    ),
                  if (imageUrlCtrl.text.isNotEmpty) const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: '제목'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: '설명'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: '가격 (원)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('카테고리', style: T.caption.copyWith(color: C.tx2)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: categories.contains(category) ? category : categories.first,
                        isDense: true,
                        menuMaxHeight: 280,
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        items: categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, color: Colors.black87))))
                            .toList(),
                        onChanged: (v) => setState(() => category = v ?? category),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('승인 상태', style: T.caption.copyWith(color: C.tx2)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'pending',
                        label: Text('대기'),
                        icon: Icon(Icons.hourglass_empty, size: 14),
                      ),
                      ButtonSegment(
                        value: 'approved',
                        label: Text('승인'),
                        icon: Icon(Icons.check_circle_outline, size: 14),
                      ),
                      ButtonSegment(
                        value: 'rejected',
                        label: Text('거절'),
                        icon: Icon(Icons.cancel_outlined, size: 14),
                      ),
                    ],
                    selected: {status},
                    onSelectionChanged: (s) => setState(() => status = s.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('공식 상품', style: T.caption.copyWith(color: C.tx2)),
                      const Spacer(),
                      Switch(
                        value: isOfficial,
                        activeThumbColor: C.lv,
                        onChanged: (v) => setState(() => isOfficial = v),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // 비공식 상품 경고
                  if (!isOfficial) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('모리니트 공식 상품이 아닙니다', style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                if (sellerUid.isNotEmpty)
                                  Text('판매자 UID: $sellerUid', style: TextStyle(color: Colors.orange.shade600, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // 이미지/PDF URL 편집
                  TextField(
                    controller: imageUrlCtrl,
                    decoration: const InputDecoration(labelText: '이미지 URL', prefixIcon: Icon(Icons.image_outlined, size: 18)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pdfUrlCtrl,
                    decoration: const InputDecoration(labelText: 'PDF URL', prefixIcon: Icon(Icons.picture_as_pdf_outlined, size: 18)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _confirmDelete(context);
              },
              style: TextButton.styleFrom(foregroundColor: C.og),
              child: const Text('삭제'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ElevatedButton(
              onPressed: () async {
                final updated = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'price': int.tryParse(priceCtrl.text.trim()) ?? (data['price'] as num?)?.toInt() ?? 0,
                  'category': category,
                  'status': status,
                  'isOfficial': isOfficial,
                  'imageUrl': imageUrlCtrl.text.trim(),
                  'pdfUrl': pdfUrlCtrl.text.trim(),
                };
                Navigator.pop(ctx);
                await _saveToFirestore(context, updated);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      titleCtrl.dispose();
      descCtrl.dispose();
      priceCtrl.dispose();
      imageUrlCtrl.dispose();
      pdfUrlCtrl.dispose();
    });
  }

  // ── 백과사전 다이얼로그 ─────────────────────────────────────────────────────
  void _showEncyclopediaDetailDialog(BuildContext context) {
    final data = Map<String, dynamic>.from(doc.data());
    final termCtrl = TextEditingController(text: data['term'] as String? ?? '');
    final categoryCtrl = TextEditingController(text: data['category'] as String? ?? '');
    final descCtrl = TextEditingController(text: data['description'] as String? ?? '');
    final tagsCtrl = TextEditingController(
      text: (data['tags'] as List?)?.join(', ') ?? data['tags']?.toString() ?? '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('백과사전 수정'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: termCtrl,
                  decoration: const InputDecoration(labelText: '용어 (term)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: '카테고리'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: '설명'),
                  maxLines: 5,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tagsCtrl,
                  decoration: const InputDecoration(
                    labelText: '태그 (쉼표로 구분)',
                    hintText: '예: 뜨개질, 바늘, 코',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _confirmDelete(context);
            },
            style: TextButton.styleFrom(foregroundColor: C.og),
            child: const Text('삭제'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          ElevatedButton(
            onPressed: () async {
              final rawTags = tagsCtrl.text.trim();
              final tagList = rawTags.isEmpty
                  ? <String>[]
                  : rawTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
              final updated = {
                'term': termCtrl.text.trim(),
                'category': categoryCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'tags': tagList,
              };
              Navigator.pop(ctx);
              await _saveToFirestore(context, updated);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ).whenComplete(() {
      termCtrl.dispose();
      categoryCtrl.dispose();
      descCtrl.dispose();
      tagsCtrl.dispose();
    });
  }

  // ── 커뮤니티 게시글 다이얼로그 ─────────────────────────────────────────────
  void _showPostDetailDialog(BuildContext context) {
    final data = Map<String, dynamic>.from(doc.data());
    final titleCtrl = TextEditingController(text: data['title'] as String? ?? '');
    final contentKey = data.containsKey('body') ? 'body' : 'content';
    final contentCtrl = TextEditingController(text: data[contentKey] as String? ?? '');
    final author = data['authorName'] as String? ?? data['authorUid'] as String? ?? '-';
    final category = data['category'] as String? ?? '-';
    final rawDate = data['createdAt'] as String? ?? '';
    final dateStr = rawDate.isNotEmpty
        ? rawDate.replaceAll('T', ' ').substring(0, rawDate.length.clamp(0, 19))
        : '-';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 수정'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReadonlyField(label: '작성자', value: author),
                const SizedBox(height: 10),
                _ReadonlyField(label: '카테고리', value: category),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(labelText: '내용'),
                  maxLines: 6,
                ),
                const SizedBox(height: 10),
                _ReadonlyField(label: '작성일', value: dateStr),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _confirmDelete(context, customMessage: '게시글을 숨김 처리(삭제)할까요?');
            },
            style: TextButton.styleFrom(foregroundColor: C.og),
            child: const Text('삭제(숨김)'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          ElevatedButton(
            onPressed: () async {
              final updated = {
                'title': titleCtrl.text.trim(),
                contentKey: contentCtrl.text.trim(),
              };
              Navigator.pop(ctx);
              await _saveToFirestore(context, updated);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ).whenComplete(() {
      titleCtrl.dispose();
      contentCtrl.dispose();
    });
  }

  // ── 기본(제네릭) 편집 다이얼로그 ───────────────────────────────────────────
  void _showGenericEditDialog(BuildContext context) {
    final data = Map<String, dynamic>.from(doc.data());
    final controllers = <String, TextEditingController>{};
    for (final entry in data.entries) {
      controllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('수정: ${_primaryLabel()}'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(labelText: entry.key),
                          maxLines: entry.key.contains('description') || entry.key.contains('content') ? 3 : 1,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _confirmDelete(context);
            },
            style: TextButton.styleFrom(foregroundColor: C.og),
            child: const Text('삭제'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          ElevatedButton(
            onPressed: () async {
              final updated = <String, dynamic>{};
              for (final entry in controllers.entries) {
                updated[entry.key] = entry.value.text.trim();
              }
              Navigator.pop(ctx);
              await _saveToFirestore(context, updated);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ).whenComplete(() {
      for (final ctrl in controllers.values) {
        ctrl.dispose();
      }
    });
  }
}

class _DashboardTab extends ConsumerWidget {
  final bool isKorean;
  final void Function(int)? onTabChange;

  const _DashboardTab({required this.isKorean, this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(_adminCountsProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        counts.when(
          data: (data) => Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CountCard(label: isKorean ? '회원' : 'Users', value: '${data['users'] ?? 0}', accent: C.lvD, onTap: () => onTabChange?.call(4)),
                _CountCard(label: isKorean ? '마켓/도안' : 'Market', value: '${data['market'] ?? 0}', accent: C.pkD, onTap: () => onTabChange?.call(8)),
                _CountCard(label: isKorean ? '백과사전' : 'Encyclopedia', value: '${data['encyclopedia'] ?? 0}', accent: C.lmD, onTap: () => onTabChange?.call(1)),
                _CountCard(label: isKorean ? '커뮤니티 글' : 'Posts', value: '${data['posts'] ?? 0}', accent: C.og, onTap: () => onTabChange?.call(9)),
              ],
            ),
          ),
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
          error: (e, _) => GlassCard(child: Text(e.toString(), style: T.body.copyWith(color: C.og))),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? '운영 메모' : 'Ops note', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
              const SizedBox(height: 10),
              Text(
                isKorean
                    ? '이 화면은 대량 데이터 입력과 운영 설정을 빠르게 처리하는 데 초점을 둔 관리자 콘솔입니다. 사용자에게 노출되는 문구, 대량등록, 계정 상태를 한곳에서 관리할 수 있습니다.'
                    : 'This console is focused on bulk data entry and operational settings. UI copy, imports, and member controls are grouped here.',
                style: T.body.copyWith(color: C.tx2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 이슈 #814 — 운영 대시보드 풍부화 (호스팅/스토리지/AI토큰/마켓/트래픽)
        OpsMetricsSection(
          onOpenBugReports: () => onTabChange?.call(11),
          onOpenInquiries: () => onTabChange?.call(19),
          onOpenPendingPatterns: () => onTabChange?.call(8),
        ),
        const SizedBox(height: 16),
        const TrafficMetricsSection(),
        const SizedBox(height: 16),
        const UsageMetricsSection(),
        const SizedBox(height: 16),
        const MarketMetricsSection(),
        const SizedBox(height: 16),
        const AiMetricsSection(),
        const SizedBox(height: 16),
        _OperationalSupportSection(isKorean: isKorean),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? '빠른 이동' : 'Quick access', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onTabChange?.call(11),
                    icon: Icon(Icons.bug_report_rounded, size: 16, color: C.og),
                    label: Text(isKorean ? '버그 리포트' : 'Bug reports', style: T.caption.copyWith(color: C.og)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onTabChange?.call(10),
                    icon: Icon(Icons.text_fields_rounded, size: 16, color: C.lvD),
                    label: Text(isKorean ? '문구 관리' : 'Copy mgmt', style: T.caption.copyWith(color: C.lvD)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onTabChange?.call(4),
                    icon: Icon(Icons.people_rounded, size: 16, color: C.lv),
                    label: Text(isKorean ? '회원 관리' : 'Members', style: T.caption.copyWith(color: C.lv)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onTabChange?.call(8),
                    icon: Icon(Icons.storefront_rounded, size: 16, color: C.pkD),
                    label: Text(isKorean ? '마켓 상품' : 'Market', style: T.caption.copyWith(color: C.pkD)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OperationalSupportSection extends ConsumerWidget {
  final bool isKorean;

  const _OperationalSupportSection({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketPending = ref.watch(_pendingMarketItemsProvider);
    final encyclopediaPending = ref.watch(_pendingEncyclopediaProvider);
    final health = ref.watch(_dataHealthProvider);

    return Column(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? '운영 지원 기능' : 'Operator support', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
              const SizedBox(height: 10),
              Text(
                isKorean
                    ? '사용자 데이터가 쌓이기 시작하면 백업, 대기열 관리, 누락 데이터 확인이 중요해집니다.'
                    : 'As user data grows, exports, review queues, and missing-field checks become important.',
                style: T.body.copyWith(color: C.tx2),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ExportButton(collection: 'users', isKorean: isKorean),
                  _ExportButton(collection: 'market_items', isKorean: isKorean),
                  _ExportButton(collection: 'encyclopedia', isKorean: isKorean),
                  _ExportButton(collection: 'posts', isKorean: isKorean),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '검토 대기열' : 'Review queue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
                    const SizedBox(height: 10),
                    marketPending.when(
                      data: (docs) => _PendingSummaryLine(
                        label: isKorean ? '마켓 승인 대기' : 'Pending market approval',
                        count: docs.length,
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text(e.toString(), style: T.caption.copyWith(color: C.og)),
                    ),
                    const SizedBox(height: 8),
                    encyclopediaPending.when(
                      data: (docs) => _PendingSummaryLine(
                        label: isKorean ? '백과 검토 대기' : 'Pending encyclopedia review',
                        count: docs.length,
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text(e.toString(), style: T.caption.copyWith(color: C.og)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '데이터 건강상태' : 'Data health', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
                    const SizedBox(height: 10),
                    health.when(
                      data: (data) => Column(
                        children: [
                          _HealthLine(label: isKorean ? '마켓 제목 누락' : 'Market title missing', count: data['marketMissingTitle'] ?? 0),
                          _HealthLine(label: isKorean ? '마켓 카테고리 누락' : 'Market category missing', count: data['marketMissingCategory'] ?? 0),
                          _HealthLine(label: isKorean ? '백과 용어 누락' : 'Encyclopedia term missing', count: data['encyclopediaMissingTerm'] ?? 0),
                          _HealthLine(label: isKorean ? '백과 카테고리 누락' : 'Encyclopedia category missing', count: data['encyclopediaMissingCategory'] ?? 0),
                          _HealthLine(label: isKorean ? '게시글 제목 누락' : 'Post title missing', count: data['postMissingTitle'] ?? 0),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text(e.toString(), style: T.caption.copyWith(color: C.og)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PendingSummaryLine extends StatelessWidget {
  final String label;
  final int count;

  const _PendingSummaryLine({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: T.body.copyWith(color: C.tx2))),
        Text('$count', style: T.bodyBold.copyWith(color: count > 0 ? C.og : C.lvD)),
      ],
    );
  }
}

class _HealthLine extends StatelessWidget {
  final String label;
  final int count;

  const _HealthLine({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: T.caption.copyWith(color: C.tx2))),
          Text('$count', style: T.captionBold.copyWith(color: count > 0 ? C.og : C.lvD)),
        ],
      ),
    );
  }
}

class _ExportButton extends StatefulWidget {
  final String collection;
  final bool isKorean;

  const _ExportButton({required this.collection, required this.isKorean});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _export,
      icon: const Icon(Icons.download_rounded),
      label: Text(_label),
    );
  }

  String get _label {
    if (widget.isKorean) {
      switch (widget.collection) {
        case 'users':
          return '회원 JSON 내보내기';
        case 'market_items':
          return '마켓 JSON 내보내기';
        case 'encyclopedia':
          return '백과 JSON 내보내기';
        case 'posts':
          return '게시글 JSON 내보내기';
      }
    }
    switch (widget.collection) {
      case 'users':
        return 'Export users JSON';
      case 'market_items':
        return 'Export market JSON';
      case 'encyclopedia':
        return 'Export encyclopedia JSON';
      case 'posts':
        return 'Export posts JSON';
      default:
        return 'Export';
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final snap = await FirebaseFirestore.instance.collection(widget.collection).limit(500).get();
      final payload = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      final bytes = Uint8List.fromList(const Utf8Encoder().convert(const JsonEncoder.withIndent('  ').convert(payload)));
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadBytes(
        bytes: bytes,
        mimeType: 'application/json;charset=utf-8',
        fileName: 'moriknit_${widget.collection}_$stamp.json',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CountCard extends StatefulWidget {
  final String label;
  final String value;
  final Color accent;
  final VoidCallback? onTap;

  const _CountCard({required this.label, required this.value, required this.accent, this.onTap});

  @override
  State<_CountCard> createState() => _CountCardState();
}

class _CountCardState extends State<_CountCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 200,
          height: 90,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.accent.withValues(alpha: 0.16)
                : widget.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.5)
                  : widget.accent.withValues(alpha: 0.16),
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: widget.accent.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(widget.label, style: T.captionBold.copyWith(color: widget.accent)),
                  if (widget.onTap != null) ...[
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: widget.accent.withValues(alpha: 0.6)),
                  ],
                ],
              ),
              Text(widget.value, style: T.h2.copyWith(color: widget.accent)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersTab extends ConsumerStatefulWidget {
  final bool isKorean;
  const _MembersTab({required this.isKorean});

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  String _search = '';

  static const _columns = [
    AdminColumn(label: '회원명 / 이메일', flex: 3),
    AdminColumn(label: '가입일', flex: 1),
    AdminColumn(label: '요금제', flex: 1),
    AdminColumn(label: '뱃지', flex: 2),
    AdminColumn(label: '관리', fixedWidth: 92, align: TextAlign.end),
  ];

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_adminUsersProvider);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bulkActions = <AdminBulkAction<UserModel>>[
      AdminBulkAction<UserModel>(
        label: widget.isKorean ? '선택 삭제' : 'Delete selected',
        icon: Icons.delete_outline_rounded,
        accent: C.og,
        requireConfirm: true,
        confirmMessage: widget.isKorean
            ? '선택한 회원을 모두 삭제할까요? 되돌릴 수 없습니다.'
            : 'Delete selected members? This cannot be undone.',
        loadingMessage:
            widget.isKorean ? '회원을 삭제하는 중입니다.' : 'Deleting members...',
        onTap: (selected) async {
          final refs = selected
              .where((u) => u.uid != currentUid)
              .map((u) =>
                  FirebaseFirestore.instance.collection('users').doc(u.uid))
              .toList();
          await _bulkDeleteDocs(refs);
        },
      ),
      AdminBulkAction<UserModel>(
        label: widget.isKorean ? '게스트 일괄 정리' : 'Cleanup guests',
        icon: Icons.person_off_outlined,
        accent: Colors.orange.shade700,
        requireConfirm: true,
        confirmMessage: widget.isKorean
            ? '선택한 회원 중 게스트(익명) 계정을 모두 삭제할까요?'
            : 'Delete guest (anonymous) accounts among selected?',
        loadingMessage:
            widget.isKorean ? '게스트 계정을 정리하는 중입니다.' : 'Cleaning guests...',
        onTap: (selected) async {
          final refs = selected
              .where((u) =>
                  u.uid != currentUid &&
                  (u.email.isEmpty ||
                      u.email.contains('anonymous') ||
                      u.email.contains('guest')))
              .map((u) =>
                  FirebaseFirestore.instance.collection('users').doc(u.uid))
              .toList();
          await _bulkDeleteDocs(refs);
        },
      ),
    ];

    return usersAsync.when(
      loading: () => AdminListShell<UserModel>(
        title: '회원',
        icon: Icons.people_alt_rounded,
        columns: _columns,
        items: const [],
        isLoading: true,
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      error: (e, _) => AdminListShell<UserModel>(
        title: '회원',
        icon: Icons.people_alt_rounded,
        columns: _columns,
        items: const [],
        errorMessage: '$e',
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      data: (users) {
        final filtered = _search.isEmpty
            ? users
            : users.where((user) {
                final q = _search;
                return user.displayName.toLowerCase().contains(q) ||
                    user.email.toLowerCase().contains(q) ||
                    user.uid.toLowerCase().contains(q);
              }).toList();
        return AdminListShell<UserModel>(
          title: '회원',
          icon: Icons.people_alt_rounded,
          columns: _columns,
          items: filtered,
          searchHint: widget.isKorean ? '이름/이메일/UID' : 'Search',
          onSearchChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          emptyMessage: widget.isKorean ? '조건에 맞는 회원이 없습니다.' : 'No matching members found.',
          selectable: true,
          itemKey: (u) => u.uid,
          bulkActions: bulkActions,
          rowBuilder: (ctx, user) =>
              _buildMemberRow(ctx, ref, user, widget.isKorean),
        );
      },
    );
  }
}

/// AdminListShell 셀 6개를 생성. (회원명/이메일, 가입일, 요금제, 뱃지, 관리)
AdminRow _buildMemberRow(BuildContext context, WidgetRef ref, UserModel user, bool isKorean) {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  final isSelf = currentUid == user.uid;
  final created = user.createdAt == null ? '-' : DateFormat('yyyy-MM-dd').format(user.createdAt!);
  return AdminRow(
    onTap: () => showDialog(
      context: context,
      builder: (_) => _MemberDetailDialog(user: user, isKorean: isKorean, isSelf: isSelf),
    ),
    cells: [
      // 회원명 / 이메일
      Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: C.lvL,
            backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
            child: user.photoURL.isEmpty
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : user.email.isNotEmpty
                            ? user.email[0].toUpperCase()
                            : 'U',
                    style: TextStyle(color: C.lvD, fontWeight: FontWeight.bold, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AdminCellTwoLine(
              title: user.displayName.isEmpty ? user.email : user.displayName,
              subtitle: user.email,
            ),
          ),
        ],
      ),
      // 가입일
      AdminCellText(created, muted: true),
      // 요금제
      AdminCellText(user.subscription.planId, muted: true),
      // 뱃지
      _MemberBadgesCell(uid: user.uid, isKorean: isKorean),
      // 관리 (수정/삭제)
      _MemberActionsCell(user: user, isSelf: isSelf, isKorean: isKorean),
    ],
  );
}

class _MemberBadgesCell extends ConsumerWidget {
  final String uid;
  final bool isKorean;
  const _MemberBadgesCell({required this.uid, required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(_memberAdminFlagProvider(uid)).valueOrNull == true;
    final isBlocked = ref.watch(_memberBlockedFlagProvider(uid)).valueOrNull == true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAdmin) ...[
          MoriChip(label: isKorean ? '관리자' : 'Admin', type: ChipType.lavender),
          const SizedBox(width: 4),
        ],
        if (isBlocked)
          MoriChip(label: isKorean ? '차단' : 'Blocked', type: ChipType.orange),
        if (!isAdmin && !isBlocked)
          Text('-', style: TextStyle(color: C.mu, fontSize: 12)),
      ],
    );
  }
}

class _MemberActionsCell extends StatelessWidget {
  final UserModel user;
  final bool isSelf;
  final bool isKorean;
  const _MemberActionsCell({required this.user, required this.isSelf, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 18, color: C.tx2),
          tooltip: isKorean ? '세부정보 편집' : 'Edit details',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _MemberDetailDialog(user: user, isKorean: isKorean, isSelf: isSelf),
          ),
        ),
        if (!isSelf)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: C.og),
            tooltip: isKorean ? '회원 삭제' : 'Delete member',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(isKorean ? '회원 삭제' : 'Delete Member'),
                  content: Text(
                    isKorean
                        ? '${user.displayName.isEmpty ? user.email : user.displayName} 회원을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'
                        : 'Delete ${user.displayName.isEmpty ? user.email : user.displayName}?\nThis cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(isKorean ? '취소' : 'Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: C.og),
                      child: Text(isKorean ? '삭제' : 'Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              if (!context.mounted) return;
              try {
                await runWithMoriLoadingDialog<void>(
                  context,
                  message: isKorean ? '회원을 삭제하는 중입니다.' : 'Deleting member...',
                  subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                  task: () => FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .delete(),
                );
                if (context.mounted) {
                  showSavedSnackBar(
                    ScaffoldMessenger.of(context),
                    message: isKorean ? '회원이 삭제됐어요.' : 'Member deleted.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showSaveErrorSnackBar(
                    ScaffoldMessenger.of(context),
                    message: '$e',
                  );
                }
              }
            },
          ),
      ],
    );
  }
}

class _MemberDetailDialog extends ConsumerStatefulWidget {
  final UserModel user;
  final bool isKorean;
  final bool isSelf;

  const _MemberDetailDialog({required this.user, required this.isKorean, required this.isSelf});

  @override
  ConsumerState<_MemberDetailDialog> createState() => _MemberDetailDialogState();
}

class _MemberDetailDialogState extends ConsumerState<_MemberDetailDialog> {
  late final TextEditingController _nameCtrl;
  late String _selectedPlan;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _selectedPlan = widget.user.subscription.planId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isKorean = widget.isKorean;
    final isSelf = widget.isSelf;
    final isAdmin = ref.watch(_memberAdminFlagProvider(user.uid)).valueOrNull == true;
    final isBlocked = ref.watch(_memberBlockedFlagProvider(user.uid)).valueOrNull == true;
    final created = user.createdAt == null ? '-' : DateFormat('yyyy-MM-dd').format(user.createdAt!);
    final lastActive = user.lastActiveAt == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(user.lastActiveAt!);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 프로필 + 이름 + 이메일
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: C.lvL,
                    backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
                    child: user.photoURL.isEmpty
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : user.email.isNotEmpty
                                    ? user.email[0].toUpperCase()
                                    : 'U',
                            style: TextStyle(color: C.lvD, fontWeight: FontWeight.bold, fontSize: 18),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName.isEmpty ? user.email : user.displayName,
                          style: T.bodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(user.email, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 11, color: C.mu),
                            const SizedBox(width: 4),
                            Text(created, style: T.caption.copyWith(color: C.mu, fontSize: 11)),
                            const SizedBox(width: 10),
                            Icon(Icons.access_time_rounded, size: 11, color: C.mu),
                            const SizedBox(width: 4),
                            Text(lastActive, style: T.caption.copyWith(color: C.mu, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // 어드민 / 차단 토글
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings_outlined, size: 16, color: C.tx2),
                        const SizedBox(width: 6),
                        Text(isKorean ? '관리자' : 'Admin', style: T.body.copyWith(color: C.tx2)),
                        const Spacer(),
                        Switch(
                          value: isAdmin,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          // 본인 토글 제약 해제 (사용자 결정) — 셀프 권한 박탈 가능
                          onChanged: (value) async {
                            final adminDoc = FirebaseFirestore.instance
                                .collection('admins')
                                .doc(user.uid);
                            if (value) {
                              await adminDoc.set({
                                'role': 'admin',
                                'addedAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await adminDoc.delete();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded, size: 16, color: C.og),
                        const SizedBox(width: 6),
                        Text(isKorean ? '차단' : 'Block', style: T.body.copyWith(color: C.tx2)),
                        const Spacer(),
                        Switch(
                          value: isBlocked,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: isSelf ? null : (value) async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .set({'isBlocked': value}, SetOptions(merge: true));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // 닉네임 편집
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: isKorean ? '닉네임' : 'Display Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              // 플랜 드롭다운
              DropdownButtonFormField<String>(
                initialValue: _selectedPlan,
                menuMaxHeight: 240,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: isKorean ? '플랜' : 'Plan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'free', child: Text('free')),
                  DropdownMenuItem(value: 'starter', child: Text('starter')),
                  DropdownMenuItem(value: 'pro', child: Text('pro')),
                  DropdownMenuItem(value: 'business', child: Text('business')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPlan = v);
                },
              ),
              const SizedBox(height: 12),
              // 사용자 데이터 조회 버튼
              OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _UserSubcollectionDialog(uid: user.uid, displayName: user.displayName.isEmpty ? user.email : user.displayName, isKorean: isKorean),
                ),
                icon: const Icon(Icons.manage_search_rounded, size: 16),
                label: Text(isKorean ? '스와치·카운터·프로젝트 조회' : 'View Swatches/Counters/Projects'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.lv,
                  side: BorderSide(color: C.lv.withValues(alpha: 0.5)),
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 20),
              // 저장 / 닫기
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isKorean ? '닫기' : 'Close', style: TextStyle(color: C.tx2)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                              {
                                'displayName': _nameCtrl.text.trim(),
                                'subscription': {
                                  'planId': _selectedPlan,
                                  'status': 'active',
                                },
                              },
                              SetOptions(merge: true),
                            );
                            if (!mounted) return;
                            setState(() => _isSaving = false);
                            if (context.mounted) Navigator.pop(context);
                          },
                    style: FilledButton.styleFrom(backgroundColor: C.lv),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isKorean ? '저장' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 사용자 서브컬렉션 조회 다이얼로그 ─────────────────────────────────────────

class _UserSubcollectionDialog extends StatefulWidget {
  final String uid;
  final String displayName;
  final bool isKorean;

  const _UserSubcollectionDialog({
    required this.uid,
    required this.displayName,
    required this.isKorean,
  });

  @override
  State<_UserSubcollectionDialog> createState() => _UserSubcollectionDialogState();
}

class _UserSubcollectionDialogState extends State<_UserSubcollectionDialog> {
  // 0=스와치, 1=카운터, 2=프로젝트
  int _tabIndex = 0;

  static const _tabLabels = ['스와치', '카운터', '프로젝트'];
  static const _subcollections = ['swatches', 'counters', 'projects'];

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.manage_search_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.displayName} 의 데이터',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 탭 선택
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: List.generate(_tabLabels.length, (i) {
                  final selected = i == _tabIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _tabIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? C.lv : C.lvL,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _tabLabels[i],
                        style: TextStyle(
                          color: selected ? Colors.white : C.lvD,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(height: 1),
            // 데이터 목록
            Expanded(
              child: _UserSubcollectionList(
                uid: widget.uid,
                subcollection: _subcollections[_tabIndex],
                isKorean: isKorean,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSubcollectionList extends StatefulWidget {
  final String uid;
  final String subcollection;
  final bool isKorean;

  const _UserSubcollectionList({
    required this.uid,
    required this.subcollection,
    required this.isKorean,
  });

  @override
  State<_UserSubcollectionList> createState() => _UserSubcollectionListState();
}

class _UserSubcollectionListState extends State<_UserSubcollectionList> {
  String _docTitle(Map<String, dynamic> data) {
    return data['title'] as String? ??
        data['name'] as String? ??
        data['displayName'] as String? ??
        '(제목 없음)';
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    final subcollection = widget.subcollection;
    final isKorean = widget.isKorean;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(subcollection)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('오류: ${snapshot.error}', style: TextStyle(color: C.og, fontSize: 13)),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_rounded, size: 40, color: C.mu),
                  const SizedBox(height: 8),
                  Text(
                    isKorean ? '데이터가 없습니다.' : 'No data found.',
                    style: TextStyle(color: C.mu, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data();
            final title = _docTitle(data);
            final createdAt = data['createdAt'];
            String dateStr = '';
            if (createdAt is Timestamp) {
              dateStr = DateFormat('yyyy-MM-dd').format(createdAt.toDate());
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.bd.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dateStr.isNotEmpty)
                          Text(dateStr, style: TextStyle(fontSize: 11, color: C.mu)),
                      ],
                    ),
                  ),
                  // 삭제 버튼
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: C.og, size: 18),
                    tooltip: isKorean ? '삭제' : 'Delete',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: ctx,
                        builder: (dialogCtx) => AlertDialog(
                          title: Text(isKorean ? '데이터 삭제' : 'Delete Data'),
                          content: Text(
                            isKorean
                                ? '[$title] 항목을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'
                                : 'Delete [$title]?\nThis cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: Text(isKorean ? '취소' : 'Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              style: TextButton.styleFrom(foregroundColor: C.og),
                              child: Text(isKorean ? '삭제' : 'Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      if (!ctx.mounted) return;
                      try {
                        await runWithMoriLoadingDialog<void>(
                          ctx,
                          message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
                          subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
                          task: () async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection(subcollection)
                                .doc(doc.id)
                                .delete();
                          },
                        );
                        if (ctx.mounted) {
                          showSavedSnackBar(
                            ScaffoldMessenger.of(ctx),
                            message: isKorean ? '삭제됐어요.' : 'Deleted.',
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          showSaveErrorSnackBar(
                            ScaffoldMessenger.of(ctx),
                            message: '$e',
                          );
                        }
                      }
                    },
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

class _BulkImportTab extends ConsumerStatefulWidget {
  final String adminUid;
  final bool isKorean;

  const _BulkImportTab({required this.adminUid, required this.isKorean});

  @override
  ConsumerState<_BulkImportTab> createState() => _BulkImportTabState();
}

class _BulkImportTabState extends ConsumerState<_BulkImportTab> {
  AdminImportKind _kind = AdminImportKind.market;
  AdminImportPreview? _preview;
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isKorean ? '대량등록 항목' : 'Import target', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AdminImportKind.values.map((kind) {
                  final selected = kind == _kind;
                  return ChoiceChip(
                    label: Text(_kindLabel(kind)),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _kind = kind;
                      _preview = null;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isBusy ? null : _downloadCsvTemplate,
                    icon: const Icon(Icons.description_rounded),
                    label: Text(widget.isKorean ? 'CSV 템플릿 다운로드' : 'Download CSV template'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isBusy ? null : _downloadExcelTemplate,
                    icon: const Icon(Icons.grid_on_rounded),
                    label: Text(widget.isKorean ? '엑셀 템플릿 다운로드' : 'Download Excel template'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _pickImportFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(widget.isKorean ? '파일 업로드' : 'Upload file'),
                  ),
                  if (_preview != null)
                    FilledButton.icon(
                      onPressed: _isBusy || _preview!.validCount == 0 ? null : _applyImport,
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: Text(widget.isKorean ? 'DB 반영' : 'Apply to DB'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _RequiredFieldGuide(kind: _kind, isKorean: widget.isKorean),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_preview != null) _PreviewCard(preview: _preview!, isKorean: widget.isKorean),
        if (_preview != null) const SizedBox(height: 12),
        _RecentImportLogs(kind: _kind, isKorean: widget.isKorean),
      ],
    );
  }

  String _kindLabel(AdminImportKind kind) => kind.label(widget.isKorean);

  Future<void> _downloadCsvTemplate() async {
    final bytes = Uint8List.fromList(utf8.encode(_kind.buildTemplateCsv(widget.isKorean)));
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = '${_kind.fileBaseName()}_$stamp.csv';
    await downloadBytes(bytes: bytes, mimeType: 'text/csv;charset=utf-8', fileName: fileName);
  }

  Future<void> _downloadExcelTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Template'];
    final rows = _kind.buildTemplateCsv(widget.isKorean).split('\n').map((row) => _parseCsvLine(row)).toList();
    final requiredSet = _kind.requiredHeaders.toSet();
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#F3E8FF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final requiredStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFF59D'),
      horizontalAlign: HorizontalAlign.Center,
    );

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (var colIndex = 0; colIndex < row.length; colIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
        cell.value = TextCellValue(row[colIndex]);
        if (rowIndex == 0) {
          final header = row[colIndex];
          cell.cellStyle = requiredSet.contains(header) ? requiredStyle : headerStyle;
        } else if (rowIndex == 1) {
          cell.cellStyle = row[colIndex].toLowerCase().contains('required') || row[colIndex] == '필수'
              ? requiredStyle
              : headerStyle.copyWith(backgroundColorHexVal: ExcelColor.fromHexString('#F8FAFC'));
        }
      }
    }
    // Set column widths for readability
    for (var colIndex = 0; colIndex < _kind.headers.length; colIndex++) {
      sheet.setColumnWidth(colIndex, 22);
    }

    final bytes = Uint8List.fromList(excel.encode() ?? <int>[]);
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = '${_kind.fileBaseName()}_$stamp.xlsx';
    await downloadBytes(
      bytes: bytes,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      fileName: fileName,
    );
  }

  List<String> _parseCsvLine(String line) => line.split(',');

  Future<void> _pickImportFile() async {
    setState(() => _isBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls', 'tsv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;
      final preview = await ref.read(adminBulkImportServiceProvider).parseFile(
            kind: _kind,
            fileName: result.files.single.name,
            bytes: result.files.single.bytes!,
          );
      if (!mounted) return;
      setState(() => _preview = preview);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _applyImport() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() => _isBusy = true);
    try {
      final result = await ref.read(adminBulkImportServiceProvider).applyPreview(
            preview: preview,
            adminUid: widget.adminUid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isKorean
                ? '${result.createdCount}건 반영, ${result.skippedCount}건 건너뜀'
                : '${result.createdCount} rows applied, ${result.skippedCount} skipped',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

class _RequiredFieldGuide extends StatelessWidget {
  final AdminImportKind kind;
  final bool isKorean;

  const _RequiredFieldGuide({required this.kind, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isKorean ? '필수 항목은 템플릿에서 노란색으로 표시됩니다.' : 'Required columns are highlighted in yellow in the template.',
            style: T.bodyBold.copyWith(color: const Color(0xFF8A5A00)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kind.requiredHeaders
                .map((header) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF59D),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFFD54F)),
                      ),
                      child: Text(header, style: T.captionBold.copyWith(color: const Color(0xFF6F4E00))),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final AdminImportPreview preview;
  final bool isKorean;

  const _PreviewCard({required this.preview, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isKorean ? '미리보기' : 'Preview', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
          const SizedBox(height: 8),
          Text(
            '${isKorean ? '정상' : 'Valid'} ${preview.validCount} / ${isKorean ? '오류' : 'Errors'} ${preview.invalidCount}',
            style: T.body.copyWith(color: C.tx2),
          ),
          if (preview.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(isKorean ? '오류 목록' : 'Errors', style: T.bodyBold.copyWith(color: C.og)),
            const SizedBox(height: 8),
            ...preview.errors.take(8).map((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(error, style: T.caption.copyWith(color: C.og)),
                )),
          ],
          if (preview.validRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(isKorean ? '샘플 행' : 'Sample rows', style: T.bodyBold),
            const SizedBox(height: 8),
            ...preview.validRows.take(3).map((row) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.bd),
                  ),
                  child: Text(
                    row.entries.map((entry) => '${entry.key}: ${entry.value}').join(' | '),
                    style: T.caption.copyWith(color: C.tx2),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _RecentImportLogs extends ConsumerWidget {
  final AdminImportKind kind;
  final bool isKorean;

  const _RecentImportLogs({required this.kind, required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_adminImportLogsProvider(kind));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isKorean ? '최근 반영 기록' : 'Recent import logs', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
          const SizedBox(height: 10),
          logsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return Text(
                  isKorean ? '아직 반영 기록이 없습니다.' : 'No import logs yet.',
                  style: T.body.copyWith(color: C.tx2),
                );
              }
              return Column(
                children: logs.map((doc) {
                  final data = doc.data();
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final stamp = createdAt == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['fileName']?.toString() ?? '-', style: T.bodyBold),
                              const SizedBox(height: 2),
                              Text(
                                '${isKorean ? '생성' : 'Created'} ${data['validCount'] ?? 0}건 · ${isKorean ? '오류' : 'Errors'} ${data['invalidCount'] ?? 0}건 · $stamp',
                                style: T.caption.copyWith(color: C.tx2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text(e.toString(), style: T.body.copyWith(color: C.og)),
          ),
        ],
      ),
    );
  }
}

class _CopyManagementTab extends ConsumerWidget {
  final bool isKorean;
  const _CopyManagementTab({required this.isKorean});

  static const _keys = <_CopyField>[
    _CopyField('home_header_subtitle', '홈 헤더', 'Home header',
      koFallback: '모두의 뜨개라이프를 응원해요',
      enFallback: 'Cheering on everyone\'s knitting life.'),
    _CopyField('project_header_subtitle', '프로젝트 헤더', 'Project header',
      koFallback: '내 프로젝트와 작업에 필요한 도안, 도구를 한곳에서 이어가세요.',
      enFallback: 'Keep your projects, patterns, and work tools together in one place.'),
    _CopyField('tools_header_subtitle', '도구 헤더', 'Tools header',
      koFallback: '모든 도구를 한곳에 모아 작업 흐름을 깔끔하게 이어가요.',
      enFallback: 'Keep every work tool in one neat place.'),
    _CopyField('community_header_subtitle', '커뮤니티 헤더', 'Community header',
      koFallback: '기록, 질문, 도안 아이디어를 한곳에서 둘러보세요.',
      enFallback: 'Browse project notes, questions, and pattern ideas in one place.'),
    _CopyField('messenger_header_subtitle', '메신저 헤더', 'Messenger header',
      koFallback: '따뜻한 말 한마디가 모두에게 힘이된다냥',
      enFallback: 'A warm word can give everyone strength.'),
    _CopyField('market_header_subtitle', '마켓 헤더', 'Market header',
      koFallback: '상품 목록에 츄르가 왜없냥?',
      enFallback: 'Why is there no churu in the product list?'),
    _CopyField('my_header_subtitle', '마이 헤더', 'My header',
      koFallback: '나만의 뜨개 공간',
      enFallback: 'Your personal knitting space.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copyAsync = ref.watch(_uiCopyDocProvider);
    return copyAsync.when(
      data: (data) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: _keys
            .map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _CopyEditorCard(
                    field: field,
                    source: data,
                    isKorean: isKorean,
                  ),
                ))
            .toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => GlassCard(child: Text(e.toString(), style: T.body.copyWith(color: C.og))),
    );
  }
}

class _CopyField {
  final String keyName;
  final String koLabel;
  final String enLabel;
  final String koFallback;
  final String enFallback;
  const _CopyField(this.keyName, this.koLabel, this.enLabel, {this.koFallback = '', this.enFallback = ''});
}

class _CopyEditorCard extends ConsumerStatefulWidget {
  final _CopyField field;
  final Map<String, dynamic> source;
  final bool isKorean;

  const _CopyEditorCard({
    required this.field,
    required this.source,
    required this.isKorean,
  });

  @override
  ConsumerState<_CopyEditorCard> createState() => _CopyEditorCardState();
}

class _CopyEditorCardState extends ConsumerState<_CopyEditorCard> {
  late final TextEditingController _koCtrl;
  late final TextEditingController _enCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _koCtrl = TextEditingController(text: widget.source['${widget.field.keyName}_ko']?.toString() ?? '');
    _enCtrl = TextEditingController(text: widget.source['${widget.field.keyName}_en']?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _CopyEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _koCtrl.text = widget.source['${widget.field.keyName}_ko']?.toString() ?? '';
      _enCtrl.text = widget.source['${widget.field.keyName}_en']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _koCtrl.dispose();
    _enCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.field.keyName;
    final savedKo = widget.source['${key}_ko']?.toString() ?? '';
    final savedEn = widget.source['${key}_en']?.toString() ?? '';
    final currentKo = savedKo.isNotEmpty ? savedKo : widget.field.koFallback;
    final currentEn = savedEn.isNotEmpty ? savedEn : widget.field.enFallback;
    final isCustom = savedKo.isNotEmpty || savedEn.isNotEmpty;

    return GlassCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isKorean ? widget.field.koLabel : widget.field.enLabel, style: T.bodyBold),
          const SizedBox(height: 2),
          Text(key, style: T.caption.copyWith(color: C.mu)),
          const SizedBox(height: 8),
          _CurrentValueBlock(
            title: widget.isKorean
                ? (isCustom ? '현재 문구 (수정됨)' : '현재 문구 (앱 기본값)')
                : (isCustom ? 'Current value (custom)' : 'Current value (app default)'),
            ko: currentKo,
            en: currentEn,
            isDefault: !isCustom,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _koCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: widget.isKorean ? '한국어 수정값' : 'Korean draft',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _enCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: widget.isKorean ? '영어 수정값' : 'English draft',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await FirebaseFirestore.instance.collection('app_config').doc('ui_copy').set(
                          {
                            '${key}_ko': _koCtrl.text.trim(),
                            '${key}_en': _enCtrl.text.trim(),
                          },
                          SetOptions(merge: true),
                        );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(widget.isKorean ? '저장' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentValueBlock extends StatelessWidget {
  final String title;
  final String ko;
  final String en;
  final bool isDefault;

  const _CurrentValueBlock({required this.title, required this.ko, required this.en, this.isDefault = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDefault ? C.lvL : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDefault ? C.lv.withValues(alpha: 0.3) : C.bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.bodyBold.copyWith(color: isDefault ? C.lvD : C.tx)),
          const SizedBox(height: 8),
          Text('KO: ${ko.isEmpty ? '-' : ko}', style: T.caption.copyWith(color: C.tx2)),
          const SizedBox(height: 4),
          Text('EN: ${en.isEmpty ? '-' : en}', style: T.caption.copyWith(color: C.tx2)),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  final bool isKorean;
  const _SettingsTab({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: C.lvD,
            unselectedLabelColor: C.mu,
            indicatorColor: C.lv,
            tabs: [
              Tab(text: isKorean ? '소셜/API' : 'Social/API'),
              const Tab(text: 'GitHub'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _SocialSettingsTab(isKorean: isKorean),
                const _GitHubSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── GitHub 설정 탭 ────────────────────────────────────────────────────────────
class _GitHubSettingsTab extends StatefulWidget {
  const _GitHubSettingsTab();

  @override
  State<_GitHubSettingsTab> createState() => _GitHubSettingsTabState();
}

class _GitHubSettingsTabState extends State<_GitHubSettingsTab> {
  final _patCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _patCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance.collection('app_config').doc('github_config').get();
    if (!mounted) return;
    setState(() {
      _patCtrl.text = snap.data()?['pat'] as String? ?? '';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('app_config').doc('github_config').set(
        {'pat': _patCtrl.text.trim()},
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub PAT가 저장되었습니다.'), duration: Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      _load();
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('GitHub 연동', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          '버그리포트 제출 시 GitHub Issues에 자동 등록됩니다.\nFine-grained PAT — Issues: Read & Write 권한 필요.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _patCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'GitHub PAT (ghp_xxxxx...)',
            prefixIcon: const Icon(Icons.key_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A2E), foregroundColor: Colors.white),
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('저장'),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        const Text('연동 레포지토리', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('koyunsuk/moriknit_flutter', style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
      ],
    );
  }
}


class _SocialSettingsTab extends ConsumerStatefulWidget {
  final bool isKorean;
  const _SocialSettingsTab({required this.isKorean});

  @override
  ConsumerState<_SocialSettingsTab> createState() => _SocialSettingsTabState();
}

class _SocialSettingsTabState extends ConsumerState<_SocialSettingsTab> {
  final _instagramCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _kakaoCtrl = TextEditingController();
  final _naverCtrl = TextEditingController();
  final _countryApiCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _instagramCtrl.dispose();
    _youtubeCtrl.dispose();
    _kakaoCtrl.dispose();
    _naverCtrl.dispose();
    _countryApiCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_socialConfigProvider);
    return async.when(
      data: (data) {
        if (!_loaded) {
          _instagramCtrl.text = data['instagram']?.toString() ?? '';
          _youtubeCtrl.text = data['youtube']?.toString() ?? '';
          _kakaoCtrl.text = data['kakao']?.toString() ?? '';
          _naverCtrl.text = data['naverCafe']?.toString() ?? '';
          _countryApiCtrl.text = data['countryApiUsage']?.toString() ?? '';
          _notesCtrl.text = data['notes']?.toString() ?? '';
          _loaded = true;
        }
        return ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.isKorean ? '소셜 계정 및 API 메모' : 'Social accounts and API notes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
                  const SizedBox(height: 12),
                  TextField(controller: _instagramCtrl, decoration: const InputDecoration(labelText: 'Instagram')),
                  const SizedBox(height: 10),
                  TextField(controller: _youtubeCtrl, decoration: const InputDecoration(labelText: 'YouTube')),
                  const SizedBox(height: 10),
                  TextField(controller: _kakaoCtrl, decoration: const InputDecoration(labelText: 'Kakao Channel')),
                  const SizedBox(height: 10),
                  TextField(controller: _naverCtrl, decoration: const InputDecoration(labelText: 'Naver Cafe')),
                  const SizedBox(height: 10),
                  TextField(controller: _countryApiCtrl, decoration: InputDecoration(labelText: widget.isKorean ? '국가/API 사용내역' : 'Country/API usage')),
                  const SizedBox(height: 10),
                  TextField(controller: _notesCtrl, maxLines: 3, decoration: InputDecoration(labelText: widget.isKorean ? '메모' : 'Notes')),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(widget.isKorean ? '저장' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => GlassCard(child: Text(e.toString(), style: T.body.copyWith(color: C.og))),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('app_config').doc('social_integrations').set(
        {
          'instagram': _instagramCtrl.text.trim(),
          'youtube': _youtubeCtrl.text.trim(),
          'kakao': _kakaoCtrl.text.trim(),
          'naverCafe': _naverCtrl.text.trim(),
          'countryApiUsage': _countryApiCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
        },
        SetOptions(merge: true),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SupportSettingsTab extends ConsumerStatefulWidget {
  final bool isKorean;
  const _SupportSettingsTab({required this.isKorean});

  @override
  ConsumerState<_SupportSettingsTab> createState() => _SupportSettingsTabState();
}

class _SupportSettingsTabState extends ConsumerState<_SupportSettingsTab> {
  final _noticeCtrl = TextEditingController();
  final _popupTitleCtrl = TextEditingController();
  final _popupMessageCtrl = TextEditingController();
  final _popupLinkUrlCtrl = TextEditingController();
  bool _popupEnabled = false;
  String _noticeType = 'banner';
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _noticeCtrl.dispose();
    _popupTitleCtrl.dispose();
    _popupMessageCtrl.dispose();
    _popupLinkUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_supportConfigProvider);
    return async.when(
      data: (data) {
        if (!_loaded) {
          _noticeCtrl.text = data['maintenanceNotice']?.toString() ?? '';
          _noticeType = data['noticeType']?.toString() ?? 'banner';
          _popupEnabled = data['popupEnabled'] == true;
          _popupTitleCtrl.text = data['popupTitle']?.toString() ?? '';
          _popupMessageCtrl.text = data['popupMessage']?.toString() ?? '';
          _popupLinkUrlCtrl.text = data['popupLinkUrl']?.toString() ?? '';
          _loaded = true;
        }

        return ListView(
          children: [
            // ── 랜딩 팝업 관리 ──────────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.isKorean ? '랜딩 팝업 관리' : 'Landing Popup', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
                      const Spacer(),
                      Switch(
                        value: _popupEnabled,
                        onChanged: (v) => setState(() => _popupEnabled = v),
                        activeThumbColor: C.lv,
                      ),
                      Text(_popupEnabled ? (widget.isKorean ? '활성' : 'ON') : (widget.isKorean ? '비활성' : 'OFF'),
                          style: T.caption.copyWith(color: _popupEnabled ? C.lv : C.tx2)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isKorean
                        ? '팝업 유형을 선택하고 제목·내용·링크를 입력하면 랜딩 페이지 방문 시 팝업이 표시됩니다.'
                        : 'When enabled, visitors see this popup on the landing page.',
                    style: T.caption.copyWith(color: C.tx2, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(widget.isKorean ? '공지 유형' : 'Notice type',
                          style: T.caption.copyWith(color: C.tx2)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _noticeType,
                        isDense: true,
                        menuMaxHeight: 240,
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        items: [
                          DropdownMenuItem(value: 'banner', child: Text(widget.isKorean ? '배너' : 'Banner', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                          DropdownMenuItem(value: 'popup', child: Text(widget.isKorean ? '팝업' : 'Popup', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                          DropdownMenuItem(value: 'push', child: Text(widget.isKorean ? '푸시알림' : 'Push', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                        ],
                        onChanged: (v) => setState(() => _noticeType = v ?? _noticeType),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _popupTitleCtrl,
                    decoration: InputDecoration(
                      labelText: widget.isKorean ? '팝업 제목' : 'Popup title',
                      hintText: widget.isKorean ? 'ex) 신기능 출시!' : 'ex) New feature launched!',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _popupMessageCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: widget.isKorean ? '팝업 내용' : 'Popup message',
                      hintText: widget.isKorean ? '팝업에 표시될 내용을 입력하세요.' : 'Enter popup body text.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _popupLinkUrlCtrl,
                    decoration: InputDecoration(
                      labelText: widget.isKorean ? '바로가기 링크 URL (선택)' : 'Link URL (optional)',
                      hintText: 'https://...',
                      helperText: widget.isKorean ? '입력 시 팝업에 "바로 가기" 버튼이 표시됩니다.' : 'A "Go to" button appears when filled.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noticeCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: widget.isKorean ? '배너 공지 문구 (배너 유형 시)' : 'Banner notice text',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(widget.isKorean ? '저장' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => GlassCard(child: Text(e.toString(), style: T.body.copyWith(color: C.og))),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('app_config').doc('admin_support').set(
        {
          'maintenanceNotice': _noticeCtrl.text.trim(),
          'noticeType': _noticeType,
          'popupEnabled': _popupEnabled,
          'popupTitle': _popupTitleCtrl.text.trim(),
          'popupMessage': _popupMessageCtrl.text.trim(),
          'popupLinkUrl': _popupLinkUrlCtrl.text.trim(),
          // 일회성 표시 트래킹용 — 저장 시각 갱신.
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── 버그리포트 탭 ─────────────────────────────────────────────────────────────

final _bugReportsProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bug_reports')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs);
});

class _BugReportsTab extends ConsumerStatefulWidget {
  const _BugReportsTab();

  @override
  ConsumerState<_BugReportsTab> createState() => _BugReportsTabState();
}

class _BugReportsTabState extends ConsumerState<_BugReportsTab> {
  String? _selectedId;

  static const _categoryColors = {
    'ui': Color(0xFF6B7FD4),
    'crash': Color(0xFFD45050),
    'feature': Color(0xFF4CAF50),
    'other': Color(0xFF9E9E9E),
  };

  static const _columns = [
    AdminColumn(label: '구분', fixedWidth: 56),
    AdminColumn(label: '제목 / 이메일', flex: 4),
    AdminColumn(label: '플래그', fixedWidth: 80),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_bugReportsProvider);
    final bulkActions = <AdminBulkAction<QueryDocumentSnapshot<Map<String, dynamic>>>>[
      AdminBulkAction(
        label: '선택 해결완료',
        icon: Icons.check_circle_outline,
        accent: Colors.green.shade600,
        requireConfirm: true,
        confirmMessage: '선택한 버그리포트를 해결완료로 표시할까요?',
        loadingMessage: '해결완료 처리 중입니다.',
        onTap: (selected) async {
          await _bulkUpdateDocs(
            selected.map((d) => d.reference).toList(),
            {'isResolved': true},
          );
        },
      ),
      AdminBulkAction(
        label: '선택 삭제',
        icon: Icons.delete_outline_rounded,
        accent: C.og,
        requireConfirm: true,
        confirmMessage: '선택한 버그리포트를 모두 삭제할까요? 되돌릴 수 없습니다.',
        loadingMessage: '버그리포트를 삭제하는 중입니다.',
        onTap: (selected) async {
          await _bulkDeleteDocs(selected.map((d) => d.reference).toList());
        },
      ),
    ];
    return Row(
      children: [
        SizedBox(
          width: 380,
          child: async.when(
            loading: () => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
              title: '버그리포트',
              icon: Icons.bug_report_rounded,
              columns: _columns,
              items: const [],
              isLoading: true,
              rowBuilder: (_, _) => const AdminRow(cells: []),
            ),
            error: (e, _) => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
              title: '버그리포트',
              icon: Icons.bug_report_rounded,
              columns: _columns,
              items: const [],
              errorMessage: '$e',
              rowBuilder: (_, _) => const AdminRow(cells: []),
            ),
            data: (docs) => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
              title: '버그리포트',
              icon: Icons.bug_report_rounded,
              columns: _columns,
              items: docs,
              emptyMessage: '접수된 버그리포트가 없습니다.',
              selectable: true,
              itemKey: (d) => d.id,
              bulkActions: bulkActions,
              rowBuilder: (ctx, doc) {
                final data = doc.data();
                final category = data['category'] as String? ?? 'other';
                final issueNum = data['githubIssueNumber'] as int?;
                final wantsReply = data['wantsReply'] as bool? ?? false;
                final userTier = data['userTier'] as String? ?? 'free';
                final isSelected = _selectedId == doc.id;
                final categoryColor = _categoryColors[category] ?? Colors.grey;
                final email = data['userEmail'] as String? ?? '';
                return AdminRow(
                  selected: isSelected,
                  accent: categoryColor,
                  onTap: () => setState(() => _selectedId = isSelected ? null : doc.id),
                  cells: [
                    AdminBadge(label: category, color: categoryColor),
                    AdminCellTwoLine(
                      title: data['title'] as String? ?? '',
                      subtitle: issueNum != null ? '#$issueNum · $email' : email,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (userTier == 'premium')
                          const Text('⭐', style: TextStyle(fontSize: 13)),
                        if (wantsReply)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.mail_outline_rounded, size: 14, color: Color(0xFF1565C0)),
                          ),
                        if (userTier != 'premium' && !wantsReply)
                          AdminCellText('-', muted: true),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: async.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (docs) {
              if (_selectedId == null) {
                return const Center(child: Text('목록에서 항목을 선택하세요.', style: TextStyle(color: Colors.grey)));
              }
              final selectedDoc = docs.where((d) => d.id == _selectedId!).firstOrNull;
              if (selectedDoc == null) {
                return const Center(child: Text('목록에서 항목을 선택하세요.', style: TextStyle(color: Colors.grey)));
              }
              return _BugReportDetail(
                doc: selectedDoc,
                onDeleted: () => setState(() => _selectedId = null),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BugReportDetail extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback? onDeleted;
  const _BugReportDetail({required this.doc, this.onDeleted});

  @override
  State<_BugReportDetail> createState() => _BugReportDetailState();
}

class _BugReportDetailState extends State<_BugReportDetail> {
  late final TextEditingController _memoCtrl;
  bool _isResolved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data();
    _memoCtrl = TextEditingController(text: data['adminMemo'] as String? ?? '');
    _isResolved = data['isResolved'] as bool? ?? false;
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('bug_reports').doc(widget.doc.id).update({
        'adminMemo': _memoCtrl.text.trim(),
        'isResolved': _isResolved,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장됐어요'), duration: Duration(milliseconds: 1200)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('버그리포트 삭제'),
        content: const Text('이 버그리포트를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await FirebaseFirestore.instance.collection('bug_reports').doc(widget.doc.id).delete();
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final issueNum = data['githubIssueNumber'] as int?;
    final issueUrl = data['githubIssueUrl'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final wantsReply = data['wantsReply'] as bool? ?? false;
    final userTier = data['userTier'] as String? ?? 'free';
    final userEmail = data['userEmail'] as String? ?? '';
    final imageUrls = (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final deviceInfo = data['deviceInfo'] as String? ?? '';
    final osVersion = data['osVersion'] as String? ?? '';

    final repo = BugReportRepository();

    // 사용자 요청: 어드민 다크 테마에서 버그리포트 상세 가독성 fix
    // 전체를 흰 카드로 wrap → 모든 텍스트/체크박스/버튼 라이트 톤으로 정상 표시
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFF1F2937)),
          child: Theme(
            data: Theme.of(context).copyWith(
              brightness: Brightness.light,
              iconTheme: const IconThemeData(color: Color(0xFF374151)),
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: const Color(0xFF1F2937),
                displayColor: const Color(0xFF1F2937),
              ),
              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? C.lv : Colors.white),
                checkColor: WidgetStateProperty.all(Colors.white),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                filled: true,
                fillColor: Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D5DB))),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D5DB))),
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                labelStyle: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // 이슈 #813 — AI 자동 fix 패널 (실시간 상태 구독)
          StreamBuilder<BugReport>(
            stream: repo.watchBugReport(widget.doc.id),
            initialData: BugReport.fromFirestore(widget.doc),
            builder: (context, snap) {
              final report = snap.data;
              if (report == null) return const SizedBox.shrink();
              // 어드민 다크 테마에서 패널 라이트 톤 보이도록 Material로 감싸기
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AdminAIFixPanel(
                      report: report,
                      onAnalysisStart: () => repo.updateAiFixStatus(report.id, 'analyzing', log: '본인 트리거: AI 분석 시작'),
                      onApprove: () => repo.updateAiFixStatus(report.id, 'approved', log: '본인 승인: 수정 진행'),
                      onReleaseApprove: () => repo.updateAiFixStatus(report.id, 'done', log: '본인 승인: 릴리즈'),
                      onReject: () => repo.updateAiFixStatus(report.id, 'rejected', log: '본인 거부'),
                    ),
                  ),
                ),
              );
            },
          ),
          // 제목 + GitHub 링크
          Row(
            children: [
              Expanded(
                child: Text(data['title'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (issueNum != null && issueUrl != null)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(issueUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text('#$issueNum GitHub', style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF4CAF50)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text('GitHub 미연동', style: TextStyle(color: Colors.orange, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 메타 정보 행
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (userTier == 'premium')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFAB00))),
                  child: const Text('⭐ 유료회원', style: TextStyle(fontSize: 11, color: Color(0xFF7B5800), fontWeight: FontWeight.bold)),
                ),
              if (wantsReply)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF4CAF50))),
                  child: const Text('✅ 답변 요청', style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${data['category'] ?? ''} · ${data['platform'] ?? ''} · v${data['appVersion'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              if (createdAt != null)
                Text(DateFormat('yyyy-MM-dd HH:mm').format(createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          // 답변하기 버튼
          if (wantsReply && userEmail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFF1565C0)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('답변 요청 접수됨', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                        Text(userEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(
                      Uri(scheme: 'mailto', path: userEmail, queryParameters: {
                        'subject': '[모리니트] 버그리포트 답변: ${data['title'] ?? ''}',
                        'body': '안녕하세요,\n모리니트 팀입니다.\n\n접수해주신 "${data['title'] ?? ''}" 문의에 대해 답변드립니다.\n\n',
                      }),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text('이메일 답변', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          // 제출자 정보
          _DetailSection(
            title: '제출자',
            body: '$userEmail  ·  ${data['userName'] ?? ''}  ·  ${userTier == 'premium' ? '유료회원' : '무료회원'}',
          ),
          const SizedBox(height: 16),
          _DetailSection(title: '설명', body: data['description'] as String? ?? ''),
          if ((data['steps'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailSection(title: '재현 단계', body: data['steps'] as String),
          ],
          if (deviceInfo.isNotEmpty || osVersion.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: '기기 정보',
              body: [if (deviceInfo.isNotEmpty) deviceInfo, if (osVersion.isNotEmpty) osVersion].join(' | '),
            ),
          ],
          // 첨부 이미지
          if (imageUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('첨부 이미지', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imageUrls.map((url) => GestureDetector(
                onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: url, width: 120, height: 120, fit: BoxFit.cover),
                ),
              )).toList(),
            ),
          ],
          // ── 어드민 처리 영역 ───────────────────────────────────────────────
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          // 수정완료 체크박스
          Row(
            children: [
              Checkbox(
                value: _isResolved,
                onChanged: (v) => setState(() => _isResolved = v ?? false),
                activeColor: const Color(0xFF4CAF50),
              ),
              const Text('수정완료', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                label: const Text('삭제', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 어드민 메모
          const Text('어드민 메모', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 6),
          TextField(
            controller: _memoCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '처리 내용, 참고사항 등을 기록하세요.',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(10),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: const Text('저장', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String body;
  const _DetailSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
      ],
    );
  }
}

// ─── 어드민 스와치 탭 ──────────────────────────────────────────────────────────

// createdAt 필드를 다양한 타입(Timestamp / ISO String / DateTime / int millis)으로
// 안전하게 DateTime 으로 변환. 변환 실패 시 null 반환.
DateTime? _coerceToDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

final _adminAllSwatchesProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collectionGroup('swatches')
      .limit(500)
      .snapshots()
      .map((s) {
        final docs = s.docs.toList();
        docs.sort((a, b) {
          final aTs = _coerceToDateTime(a.data()['createdAt']);
          final bTs = _coerceToDateTime(b.data()['createdAt']);
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
        return docs;
      });
});

final _adminAllPatternsProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collectionGroup('pattern_charts')
      .limit(500)
      .snapshots()
      .map((s) {
        final docs = s.docs.toList();
        docs.sort((a, b) {
          final aTs = _coerceToDateTime(a.data()['createdAt']);
          final bTs = _coerceToDateTime(b.data()['createdAt']);
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
        return docs;
      });
});

final _adminAllTemplatesProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collectionGroup('templates')
      .limit(500)
      .snapshots()
      .map((s) => s.docs.toList());
});

class _AdminSwatchesTab extends ConsumerStatefulWidget {
  const _AdminSwatchesTab();
  @override
  ConsumerState<_AdminSwatchesTab> createState() => _AdminSwatchesTabState();
}

class _AdminSwatchesTabState extends ConsumerState<_AdminSwatchesTab> {
  String _search = '';

  static const _columns = [
    AdminColumn(label: '색상', fixedWidth: 60),
    AdminColumn(label: '브랜드 / 소유자', flex: 3),
    AdminColumn(label: '컬러코드', flex: 1),
    AdminColumn(label: '관리', fixedWidth: 60, align: TextAlign.end),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminAllSwatchesProvider);
    return async.when(
      loading: () => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: '스와치',
        icon: Icons.palette_rounded,
        columns: _columns,
        items: const [],
        isLoading: true,
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      error: (e, _) => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: '스와치',
        icon: Icons.palette_rounded,
        columns: _columns,
        items: const [],
        errorMessage: '$e',
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      data: (docs) {
        final filtered = _search.isEmpty
            ? docs
            : docs.where((d) {
                final data = d.data();
                final name = (data['yarnBrandName'] ?? data['name'] ?? '').toString().toLowerCase();
                return name.contains(_search);
              }).toList();
        return AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
          title: '스와치',
          icon: Icons.palette_rounded,
          columns: _columns,
          items: filtered,
          searchHint: '이름/브랜드 검색',
          onSearchChanged: (v) => setState(() => _search = v.toLowerCase()),
          emptyMessage: '스와치가 없습니다.',
          selectable: true,
          itemKey: (d) => d.reference.path,
          bulkActions: [
            AdminBulkAction(
              label: '선택 삭제',
              icon: Icons.delete_outline_rounded,
              accent: C.og,
              requireConfirm: true,
              confirmMessage: '선택한 스와치를 모두 삭제할까요? 되돌릴 수 없습니다.',
              loadingMessage: '스와치를 삭제하는 중입니다.',
              onTap: (selected) async {
                await _bulkDeleteDocs(
                    selected.map((d) => d.reference).toList());
              },
            ),
          ],
          rowBuilder: (ctx, doc) {
            final data = doc.data();
            final pathParts = doc.reference.path.split('/');
            final ownerUid = pathParts.length >= 2 ? pathParts[1] : '';
            final brandName = data['yarnBrandName'] as String? ?? '';
            final colorHex = data['colorHex'] as String? ?? '';
            Color swatchColor = Colors.grey.shade300;
            try {
              if (colorHex.isNotEmpty) {
                swatchColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
              }
            } catch (_) {}
            return AdminRow(
              cells: [
                // 색상
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: swatchColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                // 브랜드/소유자
                AdminCellTwoLine(
                  title: brandName.isNotEmpty ? brandName : '(브랜드 없음)',
                  subtitle: 'UID: $ownerUid',
                ),
                // 컬러코드
                Text(
                  colorHex.isNotEmpty ? colorHex : '-',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
                // 관리
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                    tooltip: '삭제',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: const Text('스와치 삭제'),
                          content: const Text('이 스와치를 삭제하시겠습니까?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('취소')),
                            TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text('삭제', style: TextStyle(color: Colors.red.shade400))),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      if (!ctx.mounted) return;
                      try {
                        await runWithMoriLoadingDialog<void>(
                          ctx,
                          message: '삭제하는 중입니다.',
                          subtitle: '잠시만 기다려 주세요.',
                          task: () => doc.reference.delete(),
                        );
                        if (ctx.mounted) showSavedSnackBar(ScaffoldMessenger.of(ctx), message: '삭제됐어요.');
                      } catch (e) {
                        if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── 어드민 프로젝트 탭 ────────────────────────────────────────────────────────

DateTime? _parseAdminDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String && v.isNotEmpty) {
    try { return DateTime.parse(v); } catch (_) {}
  }
  return null;
}

final _adminAllProjectsProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collectionGroup('projects')
      .limit(500)
      .snapshots()
      .map((s) {
        final docs = s.docs;
        docs.sort((a, b) {
          final aD = _parseAdminDate(a.data()['createdAt']);
          final bD = _parseAdminDate(b.data()['createdAt']);
          if (aD == null && bD == null) return 0;
          if (aD == null) return 1;
          if (bD == null) return -1;
          return bD.compareTo(aD);
        });
        return docs;
      });
});

class _AdminProjectsTab extends ConsumerStatefulWidget {
  const _AdminProjectsTab();
  @override
  ConsumerState<_AdminProjectsTab> createState() => _AdminProjectsTabState();
}

class _AdminProjectsTabState extends ConsumerState<_AdminProjectsTab> {
  String _search = '';

  static const _statusColors = {
    'planning': Color(0xFF9E9E9E),
    'in_progress': Color(0xFF6B7FD4),
    'paused': Color(0xFFFF9800),
    'finished': Color(0xFF4CAF50),
  };

  static const _statusLabels = {
    'planning': '계획중',
    'in_progress': '진행중',
    'paused': '보류',
    'finished': '완료',
  };

  static const _columns = [
    AdminColumn(label: '상태', fixedWidth: 80),
    AdminColumn(label: '제목 / 소유자', flex: 3),
    AdminColumn(label: '시작일', flex: 1),
    AdminColumn(label: '관리', fixedWidth: 60, align: TextAlign.end),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminAllProjectsProvider);
    return async.when(
      loading: () => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: '프로젝트',
        icon: Icons.folder_copy_rounded,
        columns: _columns,
        items: const [],
        isLoading: true,
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      error: (e, _) => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: '프로젝트',
        icon: Icons.folder_copy_rounded,
        columns: _columns,
        items: const [],
        errorMessage: '$e',
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      data: (docs) {
        final filtered = _search.isEmpty
            ? docs
            : docs.where((d) {
                final title = (d.data()['title'] ?? '').toString().toLowerCase();
                return title.contains(_search);
              }).toList();
        return AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
          title: '프로젝트',
          icon: Icons.folder_copy_rounded,
          columns: _columns,
          items: filtered,
          searchHint: '제목 검색',
          onSearchChanged: (v) => setState(() => _search = v.toLowerCase()),
          emptyMessage: '프로젝트가 없습니다.',
          selectable: true,
          itemKey: (d) => d.reference.path,
          bulkActions: [
            AdminBulkAction(
              label: '선택 삭제',
              icon: Icons.delete_outline_rounded,
              accent: C.og,
              requireConfirm: true,
              confirmMessage: '선택한 프로젝트를 모두 삭제할까요? 되돌릴 수 없습니다.',
              loadingMessage: '프로젝트를 삭제하는 중입니다.',
              onTap: (selected) async {
                await _bulkDeleteDocs(
                    selected.map((d) => d.reference).toList());
              },
            ),
          ],
          rowBuilder: (ctx, doc) {
            final data = doc.data();
            final pathParts = doc.reference.path.split('/');
            final ownerUid = pathParts.length >= 2 ? pathParts[1] : '';
            final title = data['title'] as String? ?? '(제목 없음)';
            final status = data['status'] as String? ?? 'planning';
            final statusColor = _statusColors[status] ?? Colors.grey;
            final statusLabel = _statusLabels[status] ?? status;
            final createdAt = data['createdAt'];
            final createdAtDate = _parseAdminDate(createdAt);
            final dateStr = createdAtDate != null ? DateFormat('yyyy-MM-dd').format(createdAtDate) : '';
            return AdminRow(
              accent: statusColor,
              cells: [
                AdminBadge(label: statusLabel, color: statusColor),
                AdminCellTwoLine(title: title, subtitle: 'UID: $ownerUid'),
                AdminCellText(dateStr.isNotEmpty ? dateStr : '-', muted: true),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                    tooltip: '삭제',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: const Text('프로젝트 삭제'),
                          content: Text('[$title] 프로젝트를 삭제하시겠습니까?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('취소')),
                            TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text('삭제', style: TextStyle(color: Colors.red.shade400))),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      if (!ctx.mounted) return;
                      try {
                        await runWithMoriLoadingDialog<void>(
                          ctx,
                          message: '삭제하는 중입니다.',
                          subtitle: '잠시만 기다려 주세요.',
                          task: () => doc.reference.delete(),
                        );
                        if (ctx.mounted) showSavedSnackBar(ScaffoldMessenger.of(ctx), message: '삭제됐어요.');
                      } catch (e) {
                        if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── 뜨개백과 탭 (개별 관리 + 일괄등록) ───────────────────────────────────────

class _EncyclopediaTab extends StatelessWidget {
  final bool isKorean;
  final String adminUid;
  const _EncyclopediaTab({required this.isKorean, required this.adminUid});

  @override
  Widget build(BuildContext context) {
    return _EncyclopediaItemsTab(isKorean: isKorean, adminUid: adminUid);
  }
}

// ── 뜨개백과 항목 목록 & 개별 관리 ────────────────────────────────────────────

class _EncyclopediaItemsTab extends StatefulWidget {
  final bool isKorean;
  final String adminUid;
  const _EncyclopediaItemsTab({required this.isKorean, required this.adminUid});

  @override
  State<_EncyclopediaItemsTab> createState() => _EncyclopediaItemsTabState();
}

class _EncyclopediaItemsTabState extends State<_EncyclopediaItemsTab> {
  String _searchQuery = '';
  bool _showBulkImport = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('encyclopedia')
          .orderBy('order')
          .limit(500)
          .get();
      if (mounted) setState(() { _docs = snap.docs; _loading = false; });
    } catch (_) {
      // order 필드 없는 경우 fallback
      final snap = await FirebaseFirestore.instance
          .collection('encyclopedia')
          .limit(500)
          .get();
      if (mounted) setState(() { _docs = snap.docs; _loading = false; });
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    if (_searchQuery.isEmpty) return _docs;
    final q = _searchQuery.toLowerCase();
    return _docs.where((d) {
      final data = d.data();
      final term = (data['term'] as String? ?? data['term_ko'] as String? ?? '').toLowerCase();
      final abbr = (data['abbreviation'] as String? ?? '').toLowerCase();
      return term.contains(q) || abbr.contains(q);
    }).toList();
  }

  // ── 단일 항목 추가/수정 다이얼로그 ────────────────────────────────────────────

  void _showEditDialog(BuildContext context, [Map<String, dynamic>? data, String? docId]) {
    // 필드값 읽기 (구 필드명 fallback 포함)
    final abbrCtrl    = TextEditingController(text: data?['abbreviation'] as String? ?? '');
    final termCtrl    = TextEditingController(text: data?['term'] as String? ?? data?['term_ko'] as String? ?? '');
    final termEnCtrl  = TextEditingController(text: data?['termEn'] as String? ?? data?['term_en'] as String? ?? '');
    final descCtrl    = TextEditingController(text: data?['description'] as String? ?? data?['description_ko'] as String? ?? '');
    final descEnCtrl  = TextEditingController(text: data?['descriptionEn'] as String? ?? data?['description_en'] as String? ?? '');
    final categoryCtrl = TextEditingController(text: data?['category'] as String? ?? data?['category_key'] as String? ?? 'abbreviation');
    final symbolCtrl  = TextEditingController(text: data?['symbol'] as String? ?? '');
    final orderCtrl   = TextEditingController(text: (data?['order'] as num?)?.toInt().toString() ?? '');
    final videoUrlCtrl = TextEditingController(text: data?['videoUrl'] as String? ?? '');
    final referenceUrlCtrl = TextEditingController(text: data?['referenceUrl'] as String? ?? '');
    final isNew = docId == null;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? '새 항목 추가' : '항목 수정'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextField(controller: abbrCtrl, decoration: const InputDecoration(labelText: '영문 약어 (abbreviation) *')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: orderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '순서 (order)'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: termCtrl, decoration: const InputDecoration(labelText: '한글 용어 (term) *'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: termEnCtrl, decoration: const InputDecoration(labelText: '영문 용어 (termEn)'))),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '한글 설명 (description)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descEnCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '영문 설명 (descriptionEn)'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: '카테고리 (category)'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: symbolCtrl,
                      decoration: const InputDecoration(
                        labelText: '기호 (symbol)',
                        hintText: '□ 또는 이미지 URL',
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: referenceUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SVG/이미지 URL (referenceUrl)',
                    hintText: 'https://... (기호 썸네일용 SVG 또는 이미지 URL)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: videoUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'YouTube URL (videoUrl)',
                    hintText: 'https://youtu.be/xxxxx 또는 https://www.youtube.com/watch?v=xxxxx',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final abbr = abbrCtrl.text.trim();
              final term = termCtrl.text.trim();
              if (abbr.isEmpty || term.isEmpty) return;
              final fields = <String, dynamic>{
                'abbreviation': abbr,
                'term': term,
                'termEn': termEnCtrl.text.trim(),
                'description': descCtrl.text.trim().isEmpty ? term : descCtrl.text.trim(),
                'descriptionEn': descEnCtrl.text.trim().isEmpty ? termEnCtrl.text.trim() : descEnCtrl.text.trim(),
                'category': categoryCtrl.text.trim().isEmpty ? 'abbreviation' : categoryCtrl.text.trim(),
                'symbol': symbolCtrl.text.trim(),
                'referenceUrl': referenceUrlCtrl.text.trim(),
                'videoUrl': videoUrlCtrl.text.trim(),
                'order': int.tryParse(orderCtrl.text.trim()) ?? 0,
                'status': 'approved',
                'createdBy': widget.adminUid,
                'approvedBy': widget.adminUid,
              };
              try {
                await runWithMoriLoadingDialog<void>(
                  ctx,
                  message: '저장하는 중입니다.',
                  subtitle: '잠시만 기다려 주세요.',
                  task: () async {
                    if (isNew) {
                      await FirebaseFirestore.instance.collection('encyclopedia').add({
                        ...fields,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await FirebaseFirestore.instance.collection('encyclopedia').doc(docId).update(fields);
                    }
                  },
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadDocs();
              } catch (e) {
                if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ).whenComplete(() {
      abbrCtrl.dispose(); termCtrl.dispose(); termEnCtrl.dispose();
      descCtrl.dispose(); descEnCtrl.dispose(); categoryCtrl.dispose();
      symbolCtrl.dispose(); orderCtrl.dispose(); videoUrlCtrl.dispose(); referenceUrlCtrl.dispose();
    });
  }

  // ── 붙여넣기 일괄 등록 다이얼로그 ─────────────────────────────────────────────

  void _showPasteImportDialog(BuildContext context) {
    final textCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          int? previewCount;

          List<Map<String, dynamic>> parseRows(String text) {
            final lines = text.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
            final result = <Map<String, dynamic>>[];
            for (final line in lines) {
              final cols = line.split('\t');
              if (cols.length < 3) continue;
              // 형식: No.\t약어\tEnglish\tKorean\tSymbol\t비고
              // 또는 2컬럼 이상이면 약어/영문/한글 순으로 파싱
              final String abbr, termEn, term, symbol;
              if (cols.length >= 4) {
                // No. 컬럼 있는 경우 (4+ 컬럼)
                final firstIsNum = int.tryParse(cols[0].trim()) != null;
                if (firstIsNum) {
                  abbr    = cols.length > 1 ? cols[1].trim() : '';
                  termEn  = cols.length > 2 ? cols[2].trim() : '';
                  term    = cols.length > 3 ? cols[3].trim() : '';
                  symbol  = cols.length > 4 ? cols[4].trim() : '';
                  final order = int.tryParse(cols[0].trim()) ?? 0;
                  if (abbr.isEmpty || term.isEmpty) continue;
                  result.add({
                    'abbreviation': abbr, 'term': term, 'termEn': termEn,
                    'description': term, 'descriptionEn': termEn,
                    'category': 'abbreviation', 'symbol': symbol,
                    'order': order, 'status': 'approved',
                    'createdBy': widget.adminUid, 'approvedBy': widget.adminUid,
                  });
                } else {
                  abbr   = cols[0].trim();
                  termEn = cols[1].trim();
                  term   = cols[2].trim();
                  symbol = cols.length > 3 ? cols[3].trim() : '';
                  if (abbr.isEmpty || term.isEmpty) continue;
                  result.add({
                    'abbreviation': abbr, 'term': term, 'termEn': termEn,
                    'description': term, 'descriptionEn': termEn,
                    'category': 'abbreviation', 'symbol': symbol,
                    'order': result.length + 1, 'status': 'approved',
                    'createdBy': widget.adminUid, 'approvedBy': widget.adminUid,
                  });
                }
              } else {
                // 3컬럼: 약어\t영문\t한글
                abbr   = cols[0].trim();
                termEn = cols[1].trim();
                term   = cols[2].trim();
                if (abbr.isEmpty || term.isEmpty) continue;
                result.add({
                  'abbreviation': abbr, 'term': term, 'termEn': termEn,
                  'description': term, 'descriptionEn': termEn,
                  'category': 'abbreviation', 'symbol': '',
                  'order': result.length + 1, 'status': 'approved',
                  'createdBy': widget.adminUid, 'approvedBy': widget.adminUid,
                });
              }
            }
            return result;
          }

          return AlertDialog(
            title: const Text('붙여넣기 일괄 등록'),
            content: SizedBox(
              width: 620,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      '엑셀/워드에서 복사한 표를 붙여넣으세요.\n'
                      '형식: No.(선택)\t약어\t영문 의미\t한글 설명\t기호(선택)\n'
                      '예: 1\tk\tknit\t겉뜨기',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: textCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: '여기에 표 데이터를 붙여넣으세요...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      onChanged: (v) {
                        ss(() => previewCount = parseRows(v).length);
                      },
                    ),
                  ),
                  if (previewCount != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '인식된 항목: $previewCount개',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: previewCount! > 0 ? Colors.green.shade700 : Colors.red.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () async {
                  final rows = parseRows(textCtrl.text);
                  if (rows.isEmpty) return;
                  try {
                    await runWithMoriLoadingDialog<void>(
                      ctx,
                      message: '${rows.length}개 항목 등록 중...',
                      subtitle: '잠시만 기다려 주세요.',
                      task: () async {
                        const chunkSize = 490;
                        final db = FirebaseFirestore.instance;
                        for (var i = 0; i < rows.length; i += chunkSize) {
                          final chunk = rows.sublist(i, (i + chunkSize).clamp(0, rows.length));
                          final batch = db.batch();
                          for (final row in chunk) {
                            batch.set(db.collection('encyclopedia').doc(), {
                              ...row,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }
                          await batch.commit();
                        }
                      },
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('${rows.length}개 항목이 등록됐습니다.')),
                      );
                    }
                    _loadDocs();
                  } catch (e) {
                    if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
                  }
                },
                child: Text('${previewCount ?? 0}개 등록'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() => textCtrl.dispose());
  }

  Future<void> _confirmDelete(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('항목 삭제'),
        content: const Text('이 뜨개백과 항목을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('encyclopedia').doc(docId).delete();
      _loadDocs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '약어 또는 한글 용어 검색',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              // 일괄등록 토글 버튼
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: _showBulkImport ? const Color(0xFF4ADE80) : null,
                ),
                onPressed: () => setState(() => _showBulkImport = !_showBulkImport),
                icon: Icon(_showBulkImport ? Icons.expand_less : Icons.upload_file_rounded, size: 16),
                label: Text(_showBulkImport ? '일괄등록 닫기' : '일괄등록'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _showEditDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ 새 항목'),
              ),
            ],
          ),
        ),
        // ── 일괄등록 패널 (토글) ───────────────────────────────────
        if (_showBulkImport)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('일괄등록', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10, runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        const url = 'https://firebasestorage.googleapis.com/v0/b/moriknit-ceea9.firebasestorage.app/o/admin_templates%2Fencyclopedia_abbreviations.xlsx?alt=media';
                        await launchUrl(Uri.parse(url));
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('전체 약어 샘플 다운로드 (167행)'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B21A8), foregroundColor: Colors.white),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        const kind = AdminImportKind.encyclopedia;
                        final bytes = Uint8List.fromList(utf8.encode(kind.buildTemplateCsv(widget.isKorean)));
                        final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
                        await downloadBytes(bytes: bytes, mimeType: 'text/csv;charset=utf-8', fileName: 'moriknit_encyclopedia_$stamp.csv');
                      },
                      icon: const Icon(Icons.description_rounded, size: 16),
                      label: const Text('CSV 빈 양식'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPasteImportDialog(context),
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: const Text('붙여넣기 일괄 등록'),
                    ),
                    _EncyclopediaFileImportButton(adminUid: widget.adminUid, onDone: _loadDocs),
                  ],
                ),
              ],
            ),
          ),
        // ── 카운트 표시 ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('총 ${_docs.length}개', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('검색 결과: ${_filtered.length}개', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Text('항목이 없습니다.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final doc = _filtered[index];
                        final data = doc.data();
                        return _EncyclopediaDocRow(
                          data: data,
                          docId: doc.id,
                          onEdit: () => _showEditDialog(context, data, doc.id),
                          onDelete: () => _confirmDelete(context, doc.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _EncyclopediaDocRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EncyclopediaDocRow({
    required this.data,
    required this.docId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final abbr     = data['abbreviation'] as String? ?? '';
    final term     = data['term'] as String? ?? data['term_ko'] as String? ?? '(용어 없음)';
    final termEn   = data['termEn'] as String? ?? data['term_en'] as String? ?? '';
    final category = data['category'] as String? ?? data['category_key'] as String? ?? '';
    final order    = (data['order'] as num?)?.toInt();
    final refUrl   = data['referenceUrl'] as String? ?? '';
    final descKo   = data['description'] as String? ?? '';
    final descEn   = data['descriptionEn'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (order != null)
            SizedBox(
              width: 32,
              child: Text('$order', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ),
          // SVG 심볼
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF6B21A8).withValues(alpha: 0.15)),
            ),
            child: refUrl.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(5),
                    child: SvgPicture.network(
                      refUrl,
                      placeholderBuilder: (_) => const SizedBox.shrink(),
                    ),
                  )
                : Icon(Icons.texture_rounded, size: 18, color: Colors.grey.shade400),
          ),
          // 약어 뱃지
          if (abbr.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.4)),
              ),
              child: Text(abbr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
            ),
          // 용어 + 설명
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(term, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (termEn.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(termEn, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ]),
                if (descKo.isNotEmpty)
                  Text(descKo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (descEn.isNotEmpty)
                  Text(descEn, style: TextStyle(fontSize: 10, color: Colors.grey.shade400), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (category.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(category, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
          IconButton(icon: Icon(Icons.edit_rounded, size: 16, color: Colors.blue.shade600), onPressed: onEdit, tooltip: '수정'),
          IconButton(
            icon: Icon(Icons.delete_rounded, size: 16, color: Colors.red.shade400),
            onPressed: onDelete,
            tooltip: '삭제',
          ),
        ],
      ),
    );
  }
}

// ── 뜨개백과 파일 업로드 버튼 (엑셀/CSV → Firestore 일괄 등록) ──────────────────
class _EncyclopediaFileImportButton extends ConsumerStatefulWidget {
  final String adminUid;
  final VoidCallback onDone;
  const _EncyclopediaFileImportButton({required this.adminUid, required this.onDone});

  @override
  ConsumerState<_EncyclopediaFileImportButton> createState() => _EncyclopediaFileImportButtonState();
}

class _EncyclopediaFileImportButtonState extends ConsumerState<_EncyclopediaFileImportButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : _pickAndImport,
      icon: const Icon(Icons.upload_rounded, size: 16),
      label: const Text('엑셀/CSV 업로드 → DB 등록'),
    );
  }

  Future<void> _pickAndImport() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) { setState(() => _busy = false); return; }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) { setState(() => _busy = false); return; }

      final service = ref.read(adminBulkImportServiceProvider);
      final preview = await service.parseFile(
        kind: AdminImportKind.encyclopedia,
        fileName: file.name,
        bytes: bytes,
      );

      if (!mounted) return;

      if (preview.validCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('유효한 행이 없습니다.\n오류: ${preview.errors.take(3).join(', ')}')),
        );
        setState(() => _busy = false);
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('일괄 등록 확인'),
          content: Text('${preview.validCount}개 항목을 DB에 등록할까요?\n(오류 행: ${preview.invalidCount}개)'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4ADE80), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('${preview.validCount}개 등록'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) { setState(() => _busy = false); return; }

      await runWithMoriLoadingDialog<void>(
        context,
        message: '${preview.validCount}개 등록 중...',
        subtitle: '잠시만 기다려 주세요.',
        task: () => service.applyPreview(preview: preview, adminUid: widget.adminUid),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${preview.validCount}개 항목이 등록됐습니다.')),
        );
        widget.onDone();
      }
    } catch (e) {
      if (mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── 에디토리얼 관리 탭 ────────────────────────────────────────────────────────

class _EditorialAdminTab extends ConsumerStatefulWidget {
  const _EditorialAdminTab();

  @override
  ConsumerState<_EditorialAdminTab> createState() => _EditorialAdminTabState();
}

class _EditorialAdminTabState extends ConsumerState<_EditorialAdminTab> {
  String _selectedType = 'letter';

  static const _types = [
    ('letter',   '뜨개 레터',   Color(0xFFF472B6)),
    ('tips',     '추천 정보',   Color(0xFFA3E635)),
    ('trending', '인기 토픽',   Color(0xFFFBBF24)),
    ('youtube',  '유튜브',      Color(0xFFFF5252)),
  ];

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(editorialAllAdminProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타입 필터 탭
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              ..._types.map((t) {
                final isSelected = _selectedType == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? t.$3.withValues(alpha: 0.18) : Colors.transparent,
                      border: Border.all(color: isSelected ? t.$3 : C.bd2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t.$2,
                      style: TextStyle(
                        color: isSelected ? t.$3 : C.mu,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              // 샘플 초기화 버튼
              GestureDetector(
                onTap: () => _insertSamplePosts(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
                  ),
                  child: const Text('샘플 초기화', style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              // 새 글 추가 버튼
              GestureDetector(
                onTap: () => _showEditDialog(context, null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF38BDF8)),
                  ),
                  child: const Text('+ 새 글', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 목록 (AdminListShell)
        Expanded(
          child: Builder(
            builder: (ctx) {
              const columns = [
                AdminColumn(label: '상태', fixedWidth: 64),
                AdminColumn(label: '제목 / 본문', flex: 4),
                AdminColumn(label: '첨부', fixedWidth: 96),
                AdminColumn(label: '게시일', flex: 1),
                AdminColumn(label: '관리', fixedWidth: 80, align: TextAlign.end),
              ];
              return postsAsync.when(
                loading: () => const AdminListShell<EditorialPost>(
                  title: '에디토리얼',
                  icon: Icons.article_rounded,
                  columns: columns,
                  items: [],
                  isLoading: true,
                  rowBuilder: _emptyRow,
                ),
                error: (e, _) => AdminListShell<EditorialPost>(
                  title: '에디토리얼',
                  icon: Icons.article_rounded,
                  columns: columns,
                  items: const [],
                  errorMessage: '$e',
                  rowBuilder: _emptyRow,
                ),
                data: (posts) {
                  final filtered = posts.where((p) => p.type == _selectedType).toList();
                  final editorialCol = FirebaseFirestore.instance.collection('editorial_posts');
                  return AdminListShell<EditorialPost>(
                    title: '에디토리얼',
                    icon: Icons.article_rounded,
                    columns: columns,
                    items: filtered,
                    emptyMessage: '게시된 글이 없어요.',
                    selectable: true,
                    itemKey: (p) => p.id,
                    bulkActions: [
                      AdminBulkAction<EditorialPost>(
                        label: '선택 발행',
                        icon: Icons.public_rounded,
                        accent: Colors.green.shade600,
                        requireConfirm: true,
                        confirmMessage: '선택한 글을 모두 발행할까요?',
                        loadingMessage: '발행 처리 중입니다.',
                        onTap: (selected) async {
                          await _bulkUpdateDocs(
                            selected.map((p) => editorialCol.doc(p.id)).toList(),
                            {'isPublished': true},
                          );
                        },
                      ),
                      AdminBulkAction<EditorialPost>(
                        label: '선택 비공개',
                        icon: Icons.visibility_off_outlined,
                        accent: Colors.grey.shade600,
                        requireConfirm: true,
                        confirmMessage: '선택한 글을 모두 비공개로 전환할까요?',
                        loadingMessage: '비공개 처리 중입니다.',
                        onTap: (selected) async {
                          await _bulkUpdateDocs(
                            selected.map((p) => editorialCol.doc(p.id)).toList(),
                            {'isPublished': false},
                          );
                        },
                      ),
                      AdminBulkAction<EditorialPost>(
                        label: '선택 삭제',
                        icon: Icons.delete_outline_rounded,
                        accent: C.og,
                        requireConfirm: true,
                        confirmMessage: '선택한 글을 모두 삭제할까요? 되돌릴 수 없습니다.',
                        loadingMessage: '삭제 처리 중입니다.',
                        onTap: (selected) async {
                          await _bulkDeleteDocs(
                            selected.map((p) => editorialCol.doc(p.id)).toList(),
                          );
                        },
                      ),
                    ],
                    rowBuilder: (rctx, post) => AdminRow(
                      accent: post.isPublished ? Colors.green : Colors.grey,
                      onTap: () => _showEditDialog(context, post),
                      cells: [
                        // 상태
                        AdminBadge(
                          label: post.isPublished ? '공개' : '비공개',
                          color: post.isPublished ? Colors.green : Colors.grey,
                        ),
                        // 제목 (본문 노출 X)
                        AdminCellText(post.title, bold: true, maxLines: 1),
                        // 첨부 아이콘
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (post.youtubeVideoId.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.play_circle_outline_rounded, size: 16, color: Colors.red),
                              ),
                            if (post.imageUrl.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.image_outlined, size: 16, color: Colors.blue),
                              ),
                            if (post.attachmentUrl.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.attach_file_rounded, size: 16, color: Colors.orange),
                              ),
                            if (post.youtubeVideoId.isEmpty && post.imageUrl.isEmpty && post.attachmentUrl.isEmpty)
                              AdminCellText('-', muted: true),
                          ],
                        ),
                        // 게시일
                        AdminCellText(
                          post.createdAt != null
                              ? '${post.createdAt!.year}.${post.createdAt!.month.toString().padLeft(2, '0')}.${post.createdAt!.day.toString().padLeft(2, '0')}'
                              : '-',
                          muted: true,
                        ),
                        // 관리
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_rounded, color: C.lv, size: 18),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showEditDialog(rctx, post),
                              tooltip: '수정',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(rctx, post.id),
                              tooltip: '삭제',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static AdminRow _emptyRow(BuildContext _, EditorialPost _) => const AdminRow(cells: []);

  Future<String?> _uploadEditorialFile(PlatformFile file) async {
    final ext = file.name.split('.').last;
    final path = 'editorial_attachments/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      file.bytes!,
      SettableMetadata(contentType: _mimeFromExt(ext)),
    );
    return await ref.getDownloadURL();
  }

  Future<String?> _uploadEditorialImage(PlatformFile file) async {
    final path = 'editorial_images/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(file.bytes!, SettableMetadata(contentType: 'image/${file.extension ?? 'jpeg'}'));
    return await ref.getDownloadURL();
  }

  String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':  return 'application/pdf';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'zip':  return 'application/zip';
      case 'png':  return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      default:     return 'application/octet-stream';
    }
  }

  Future<void> _insertSamplePosts(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.gx,
        title: Text('샘플 데이터 추가', style: TextStyle(color: C.tx, fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text('각 게시판에 샘플 글 1개씩 추가합니다.\n(기존 글은 삭제되지 않습니다)', style: TextStyle(color: C.mu, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: TextStyle(color: C.mu))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(editorialRepositoryProvider);
    final samples = [
      EditorialPost(
        id: '', type: 'letter', isPublished: true,
        title: '🧶 이번 주 뜨개 레터 — 입문자가 꼭 알아야 할 코잡기 3가지',
        content: '처음 뜨개를 시작할 때 가장 헷갈리는 것이 바로 코잡기입니다. 마법의코, 사슬코, 일반코 세 가지 방법을 사진과 함께 쉽게 설명합니다. 각 상황에 맞는 코잡기를 선택하는 것이 완성도를 높이는 첫 번째 비결이에요.',
        imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
        attachmentUrl: 'https://www.w3.org/WAI/WCAG21/Techniques/pdf/PDF1',
        attachmentName: '코잡기_가이드.pdf',
        youtubeVideoId: 'dQw4w9WgXcQ',
        authorName: '모리니트 에디터',
      ),
      EditorialPost(
        id: '', type: 'tips', isPublished: true,
        title: '💡 게이지 스와치, 이렇게 하면 절대 실패 없어요',
        content: '게이지 스와치를 뜨는 올바른 방법과 세탁 후 치수 변화를 예측하는 팁을 공유합니다. 스와치 없이 바로 작품을 시작하면 사이즈가 맞지 않는 경우가 많아요. 정확한 게이지 측정이 완성도를 결정합니다.',
        imageUrl: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=800&q=80',
        attachmentUrl: 'https://www.w3.org/WAI/WCAG21/Techniques/pdf/PDF1',
        attachmentName: '게이지_체크리스트.pdf',
        youtubeVideoId: 'dQw4w9WgXcQ',
        authorName: '모리니트 에디터',
      ),
      EditorialPost(
        id: '', type: 'trending', isPublished: true,
        title: '🔥 지금 가장 핫한 뜨개 트렌드 — 버블 텍스처 스웨터',
        content: '2024 가을겨울 시즌 최대 트렌드는 버블 텍스처입니다. 팝콘 스티치와 보블 스티치를 활용한 입체 패턴이 SNS를 가득 채우고 있어요. 모리니트 커뮤니티에서 가장 많이 공유된 패턴 3가지를 소개합니다.',
        imageUrl: 'https://images.unsplash.com/photo-1616627561950-9f746e330187?w=800&q=80',
        attachmentUrl: 'https://www.w3.org/WAI/WCAG21/Techniques/pdf/PDF1',
        attachmentName: '버블텍스처_패턴.pdf',
        youtubeVideoId: 'dQw4w9WgXcQ',
        authorName: '모리니트 에디터',
      ),
      EditorialPost(
        id: '', type: 'youtube', isPublished: true,
        title: '초보자도 따라하는 대바늘 메리야스 뜨기',
        content: '대바늘 뜨개의 기본 중 기본, 메리야스 뜨기를 처음부터 차근차근 설명합니다. 겉뜨기와 안뜨기를 번갈아가며 평평한 천을 만드는 방법을 영상으로 확인하세요.',
        imageUrl: '',
        youtubeVideoId: 'dQw4w9WgXcQ',
        authorName: '모리니트 에디터',
      ),
    ];
    for (final post in samples) {
      await repo.createPost(post);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('샘플 글 4개가 추가되었습니다.'), backgroundColor: Colors.purple),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.gx,
        title: Text('삭제 확인', style: TextStyle(color: C.tx)),
        content: Text('이 게시글을 삭제할까요?', style: TextStyle(color: C.mu)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: TextStyle(color: C.mu))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(editorialRepositoryProvider).deletePost(id);
    }
  }

  Future<void> _showEditDialog(BuildContext context, EditorialPost? existing) async {
    final typeLabel = _types.firstWhere((t) => t.$1 == _selectedType).$2;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final ytCtrl = TextEditingController(text: existing?.youtubeVideoId ?? '');
    final imageUrlCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final attachUrlCtrl = TextEditingController(text: existing?.attachmentUrl ?? '');
    final attachNameCtrl = TextEditingController(text: existing?.attachmentName ?? '');
    var isPublished = existing?.isPublished ?? true;
    var editType = existing?.type ?? _selectedType;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: C.gx,
          title: Text(
            existing == null ? '새 글 ($typeLabel)' : '수정',
            style: TextStyle(color: C.tx, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 타입 선택 (새 글일 때만)
                  if (existing == null) ...[
                    Text('타입', style: TextStyle(color: C.mu, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: _types.map((t) {
                        final sel = editType == t.$1;
                        return GestureDetector(
                          onTap: () => setS(() => editType = t.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? t.$3.withValues(alpha: 0.18) : Colors.transparent,
                              border: Border.all(color: sel ? t.$3 : C.bd2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(t.$2, style: TextStyle(color: sel ? t.$3 : C.mu, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // 제목
                  Text('제목', style: TextStyle(color: C.mu, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: C.tx, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: C.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 내용
                  Text('내용', style: TextStyle(color: C.mu, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 5,
                    style: TextStyle(color: C.tx, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: C.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // YouTube ID (youtube 타입일 때)
                  if (editType == 'youtube') ...[
                    Text('YouTube Video ID', style: TextStyle(color: C.mu, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: ytCtrl,
                      style: TextStyle(color: C.tx, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. dQw4w9WgXcQ',
                        hintStyle: TextStyle(color: C.mu, fontSize: 12),
                        filled: true,
                        fillColor: C.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // 이미지 URL + 업로드
                  StatefulBuilder(builder: (_, setImg) {
                    bool isUploadingImg = false;
                    return StatefulBuilder(builder: (_, setUpImg) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('이미지 (선택)', style: TextStyle(color: C.mu, fontSize: 12)),
                          const Spacer(),
                          if (isUploadingImg)
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                foregroundColor: const Color(0xFF38BDF8),
                              ),
                              icon: const Icon(Icons.upload_rounded, size: 14),
                              label: const Text('이미지 업로드', style: TextStyle(fontSize: 11)),
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                  withData: true,
                                );
                                if (result == null) return;
                                setUpImg(() => isUploadingImg = true);
                                try {
                                  final url = await _uploadEditorialImage(result.files.first);
                                  if (url != null) {
                                    imageUrlCtrl.text = url;
                                    setImg(() {});
                                  }
                                } finally {
                                  setUpImg(() => isUploadingImg = false);
                                }
                              },
                            ),
                        ]),
                        const SizedBox(height: 4),
                        TextField(
                          controller: imageUrlCtrl,
                          style: TextStyle(color: C.tx, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'https://example.com/image.jpg',
                            hintStyle: TextStyle(color: C.mu, fontSize: 12),
                            filled: true, fillColor: C.bg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixIcon: IconButton(icon: const Icon(Icons.refresh, size: 16), onPressed: () => setImg(() {})),
                          ),
                          onChanged: (_) => setImg(() {}),
                        ),
                        if (imageUrlCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: imageUrlCtrl.text.trim(), height: 80, fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(height: 40, color: C.bd2, child: Center(child: Text('이미지 로드 실패', style: TextStyle(color: C.mu, fontSize: 11))))),
                          ),
                        ],
                      ],
                    ));
                  }),
                  const SizedBox(height: 12),
                  // 첨부파일 업로드
                  StatefulBuilder(builder: (_, setAtt) {
                    bool isUploadingAttach = false;
                    return StatefulBuilder(builder: (_, setUpAtt) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('첨부파일 (선택)', style: TextStyle(color: C.mu, fontSize: 12)),
                          const Spacer(),
                          if (isUploadingAttach)
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                foregroundColor: const Color(0xFFF59E0B),
                              ),
                              icon: const Icon(Icons.attach_file_rounded, size: 14),
                              label: const Text('파일 업로드', style: TextStyle(fontSize: 11)),
                              onPressed: () async {
                                final result = await FilePicker.platform.pickFiles(
                                  withData: true,
                                  allowedExtensions: ['pdf', 'docx', 'xlsx', 'zip', 'png', 'jpg'],
                                  type: FileType.custom,
                                );
                                if (result == null) return;
                                setUpAtt(() => isUploadingAttach = true);
                                try {
                                  final file = result.files.first;
                                  final url = await _uploadEditorialFile(file);
                                  if (url != null) {
                                    attachUrlCtrl.text = url;
                                    if (attachNameCtrl.text.isEmpty) {
                                      attachNameCtrl.text = file.name;
                                    }
                                    setAtt(() {});
                                  }
                                } finally {
                                  setUpAtt(() => isUploadingAttach = false);
                                }
                              },
                            ),
                        ]),
                        const SizedBox(height: 4),
                        TextField(
                          controller: attachNameCtrl,
                          style: TextStyle(color: C.tx, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: '첨부파일 표시 이름 (예: 코바늘기법_가이드.pdf)',
                            hintStyle: TextStyle(color: C.mu, fontSize: 12),
                            filled: true, fillColor: C.bg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: C.bd2)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        if (attachUrlCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.check_circle, size: 13, color: Colors.green),
                            const SizedBox(width: 4),
                            Expanded(child: Text(attachUrlCtrl.text, style: TextStyle(color: C.mu, fontSize: 10), overflow: TextOverflow.ellipsis)),
                            IconButton(
                              icon: Icon(Icons.close, size: 13, color: C.mu),
                              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                              onPressed: () { attachUrlCtrl.text = ''; attachNameCtrl.text = ''; setAtt(() {}); },
                            ),
                          ]),
                        ],
                      ],
                    ));
                  }),
                  const SizedBox(height: 12),
                  // 공개 여부
                  Row(children: [
                    Switch(
                      value: isPublished,
                      onChanged: (v) => setS(() => isPublished = v),
                      activeThumbColor: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 8),
                    Text(isPublished ? '공개' : '비공개', style: TextStyle(color: C.tx, fontSize: 13)),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('취소', style: TextStyle(color: C.mu))),
            TextButton(
              onPressed: () async {
                final repo = ref.read(editorialRepositoryProvider);
                final data = {
                  'type': editType,
                  'title': titleCtrl.text.trim(),
                  'content': contentCtrl.text.trim(),
                  'youtubeVideoId': ytCtrl.text.trim(),
                  'imageUrl': imageUrlCtrl.text.trim(),
                  'attachmentUrl': attachUrlCtrl.text.trim(),
                  'attachmentName': attachNameCtrl.text.trim(),
                  'isPublished': isPublished,
                };
                if (existing == null) {
                  await repo.createPost(EditorialPost(
                    id: '',
                    type: editType,
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    youtubeVideoId: ytCtrl.text.trim(),
                    imageUrl: imageUrlCtrl.text.trim(),
                    attachmentUrl: attachUrlCtrl.text.trim(),
                    attachmentName: attachNameCtrl.text.trim(),
                    isPublished: isPublished,
                  ));
                } else {
                  await repo.updatePost(existing.id, data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('저장', style: TextStyle(color: const Color(0xFF38BDF8), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 기본 템플릿 관리 탭 ─────────────────────────────────────────────────────
class _BuiltinTemplateAdminTab extends ConsumerWidget {
  const _BuiltinTemplateAdminTab();

  IconData _iconFromName(String name) {
    switch (name) {
      case 'checkroom_rounded': return Icons.checkroom_rounded;
      case 'loop_rounded': return Icons.loop_rounded;
      case 'face_rounded': return Icons.face_rounded;
      case 'back_hand_rounded': return Icons.back_hand_rounded;
      case 'local_cafe_rounded': return Icons.local_cafe_rounded;
      default: return Icons.folder_special_rounded;
    }
  }

  Color _colorFromHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(builtinTemplateListProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('기본 템플릿 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.tx)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('템플릿 추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB47EEB),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _seed(context, ref),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('초기 데이터 시드'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB47EEB),
                  side: const BorderSide(color: Color(0xFFB47EEB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('오류: $e', style: TextStyle(color: C.og)),
              data: (templates) {
                if (templates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_special_rounded, size: 48, color: C.mu),
                        const SizedBox(height: 12),
                        Text('기본 템플릿이 없습니다.', style: TextStyle(color: C.mu)),
                        const SizedBox(height: 8),
                        Text('\'초기 데이터 시드\' 버튼으로 5개 기본 템플릿을 등록하세요.',
                            style: TextStyle(color: C.mu, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: templates.length,
                  separatorBuilder: (_, _) => Divider(color: C.bd2, height: 1),
                  itemBuilder: (ctx, i) {
                    final tmpl = templates[i];
                    final icon = _iconFromName(tmpl.iconName);
                    final color = _colorFromHex(tmpl.colorHex);
                    return ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text('${tmpl.titleKo} / ${tmpl.titleEn}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(tmpl.descKo, style: TextStyle(color: C.mu, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('순서: ${tmpl.order}',
                              style: TextStyle(color: C.mu, fontSize: 12)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: tmpl.isActive
                                  ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                                  : C.gx,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tmpl.isActive ? '활성' : '비활성',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: tmpl.isActive ? const Color(0xFF16A34A) : C.mu,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: C.mu, size: 20),
                            onSelected: (value) {
                              if (value == 'edit') _showEditDialog(context, ref, tmpl);
                              if (value == 'delete') _confirmDelete(context, ref, tmpl);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit_outlined, size: 16, color: C.tx),
                                  const SizedBox(width: 8),
                                  const Text('수정'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline_rounded, size: 16, color: C.og),
                                  const SizedBox(width: 8),
                                  Text('삭제', style: TextStyle(color: C.og)),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seed(BuildContext context, WidgetRef ref) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '초기 데이터를 등록하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () => ref.read(templateRepositoryProvider).seedBuiltinTemplates(forceSeed: true),
      );
      if (context.mounted) {
        showSavedSnackBar(ScaffoldMessenger.of(context), message: '초기 데이터가 등록됐어요.');
      }
    } catch (e) {
      if (context.mounted) {
        showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, BuiltinTemplate tmpl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('템플릿 삭제'),
        content: Text('"${tmpl.titleKo}"을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await runWithMoriLoadingDialog<void>(
          context,
          message: '삭제하는 중입니다.',
          subtitle: '잠시만 기다려 주세요.',
          task: () => ref.read(templateRepositoryProvider).deleteBuiltinTemplate(tmpl.id),
        );
        if (context.mounted) {
          showSavedSnackBar(ScaffoldMessenger.of(context), message: '삭제됐어요.');
        }
      } catch (e) {
        if (context.mounted) {
          showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
        }
      }
    }
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    _showTemplateFormDialog(context, ref, existing: null);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, BuiltinTemplate tmpl) {
    _showTemplateFormDialog(context, ref, existing: tmpl);
  }

  void _showTemplateFormDialog(BuildContext context, WidgetRef ref, {BuiltinTemplate? existing}) {
    final titleKoCtrl = TextEditingController(text: existing?.titleKo ?? '');
    final titleEnCtrl = TextEditingController(text: existing?.titleEn ?? '');
    final descKoCtrl = TextEditingController(text: existing?.descKo ?? '');
    final descEnCtrl = TextEditingController(text: existing?.descEn ?? '');
    final iconCtrl = TextEditingController(text: existing?.iconName ?? 'folder_special_rounded');
    final colorCtrl = TextEditingController(text: existing?.colorHex ?? '#B47EEB');
    final orderCtrl = TextEditingController(text: '${existing?.order ?? 0}');
    final isAdd = existing == null;
    // 이슈 #787 — 카테고리(의상/소품/인형/아기용) 드롭다운 상태값.
    BuiltinTemplateCategory selectedCategory =
        existing?.category ?? BuiltinTemplateCategory.clothing;

    InputDecoration adminDec(String label, {String? hint}) => InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      fillColor: Colors.white.withValues(alpha: 0.10), filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white60)),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
        title: Text(isAdd ? '기본 템플릿 추가' : '기본 템플릿 수정',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleKoCtrl, style: const TextStyle(color: Colors.white), decoration: adminDec('제목 (한국어)')),
              const SizedBox(height: 8),
              TextField(controller: titleEnCtrl, style: const TextStyle(color: Colors.white), decoration: adminDec('제목 (English)')),
              const SizedBox(height: 8),
              TextField(controller: descKoCtrl, style: const TextStyle(color: Colors.white), decoration: adminDec('설명 (한국어)')),
              const SizedBox(height: 8),
              TextField(controller: descEnCtrl, style: const TextStyle(color: Colors.white), decoration: adminDec('설명 (English)')),
              const SizedBox(height: 8),
              TextField(controller: iconCtrl, style: const TextStyle(color: Colors.white), decoration: adminDec('아이콘 이름', hint: 'checkroom_rounded / loop_rounded / face_rounded ...')),
              const SizedBox(height: 8),
              TextField(controller: colorCtrl, style: const TextStyle(color: Colors.white), decoration: adminDec('색상 HEX', hint: '#B47EEB')),
              const SizedBox(height: 8),
              TextField(controller: orderCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: adminDec('순서 (숫자)')),
              const SizedBox(height: 8),
              // 이슈 #787 — 카테고리 선택 드롭다운.
              DropdownButtonFormField<BuiltinTemplateCategory>(
                initialValue: selectedCategory,
                isExpanded: true,
                dropdownColor: const Color(0xFF1F1F2A),
                style: const TextStyle(color: Colors.white),
                decoration: adminDec('카테고리'),
                items: BuiltinTemplateCategory.values
                    .map((c) => DropdownMenuItem<BuiltinTemplateCategory>(
                          value: c,
                          child: Text(
                            c.label(isKorean: true),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setLocalState(() => selectedCategory = v);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final tmpl = BuiltinTemplate(
                id: existing?.id ?? '',
                category: selectedCategory,
                titleKo: titleKoCtrl.text.trim(),
                titleEn: titleEnCtrl.text.trim(),
                descKo: descKoCtrl.text.trim(),
                descEn: descEnCtrl.text.trim(),
                iconName: iconCtrl.text.trim(),
                colorHex: colorCtrl.text.trim(),
                stepsKo: existing?.stepsKo ?? [],
                stepsEn: existing?.stepsEn ?? [],
                stepNotesKo: existing?.stepNotesKo ?? [],
                stepNotesEn: existing?.stepNotesEn ?? [],
                stepTargetRows: existing?.stepTargetRows ?? [],
                order: int.tryParse(orderCtrl.text.trim()) ?? 0,
                isActive: existing?.isActive ?? true,
              );
              try {
                await runWithMoriLoadingDialog<void>(
                  ctx,
                  message: '저장하는 중입니다.',
                  subtitle: '잠시만 기다려 주세요.',
                  task: () => isAdd
                      ? ref.read(templateRepositoryProvider).createBuiltinTemplate(tmpl)
                      : ref.read(templateRepositoryProvider).updateBuiltinTemplate(tmpl),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  showSavedSnackBar(ScaffoldMessenger.of(context), message: '저장됐어요.');
                }
              } catch (e) {
                if (ctx.mounted) {
                  showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
      ),
    );
  }
}

// ── 커뮤니티 어드민 탭 ────────────────────────────────────────────────────────
class _CommunityAdminTab extends StatefulWidget {
  const _CommunityAdminTab();

  @override
  State<_CommunityAdminTab> createState() => _CommunityAdminTabState();
}

class _CommunityAdminTabState extends State<_CommunityAdminTab> {
  String _selectedCategory = 'all';
  String? _expandedPostId;

  static const _categories = ['all', 'free', 'qna', 'show', 'market', 'kal'];
  static const _categoryLabels = {
    'all': '전체',
    'free': '자유',
    'qna': 'Q&A',
    'show': '작품공유',
    'market': '마켓',
    'kal': 'KAL',
  };

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('posts')
        .limit(200);
    if (_selectedCategory != 'all') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return Column(
      children: [
        // 카테고리 필터
        Container(
          height: 40,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final selected = cat == _selectedCategory;
              return GestureDetector(
                onTap: () => setState(() { _selectedCategory = cat; _expandedPostId = null; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? C.lv : C.lvL,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _categoryLabels[cat] ?? cat,
                    style: TextStyle(
                      color: selected ? Colors.white : C.lvD,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 게시글 목록
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final rawDocs = snapshot.data?.docs ?? [];
              final docs = [...rawDocs]..sort((a, b) {
                  final aTs = a.data()['createdAt'];
                  final bTs = b.data()['createdAt'];
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return (bTs as Timestamp).compareTo(aTs as Timestamp);
                });
              if (docs.isEmpty) {
                return Center(child: Text('게시글이 없습니다.', style: TextStyle(color: C.mu)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final postId = doc.id;
                  final isExpanded = _expandedPostId == postId;
                  final title = data['title'] as String? ?? '(제목 없음)';
                  final author = data['authorName'] as String? ?? '익명';
                  final category = data['category'] as String? ?? '';
                  final content = data['content'] as String? ?? '';
                  final likeCount = data['likeCount'] as int? ?? 0;
                  final imageUrls = List<String>.from(data['imageUrls'] ?? []);
                  final createdAt = data['createdAt'];
                  String timeStr = '';
                  if (createdAt is Timestamp) {
                    final dt = createdAt.toDate();
                    timeStr = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
                  }

                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: C.bd.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        // 헤더 행
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _expandedPostId = isExpanded ? null : postId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: C.lvL,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(_categoryLabels[category] ?? category, style: TextStyle(color: C.lvD, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                Text(author, style: TextStyle(fontSize: 12, color: C.tx2)),
                                const SizedBox(width: 6),
                                Text(timeStr, style: TextStyle(fontSize: 11, color: C.mu)),
                                const SizedBox(width: 6),
                                Icon(Icons.favorite_rounded, size: 12, color: C.og),
                                const SizedBox(width: 2),
                                Text('$likeCount', style: TextStyle(fontSize: 11, color: C.mu)),
                                const SizedBox(width: 8),
                                // 삭제 버튼
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: C.og, size: 18),
                                  tooltip: '게시글 삭제',
                                  onPressed: () async {
                                    final sm = ScaffoldMessenger.of(context);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('게시글 삭제'),
                                        content: Text('[$title] 게시글을 삭제하시겠습니까?\n댓글 및 이미지도 함께 삭제됩니다.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('삭제', style: TextStyle(color: C.og))),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    if (!mounted) return;
                                    try {
                                      await runWithMoriLoadingDialog<void>(
                                        context,
                                        message: '삭제하는 중입니다.',
                                        subtitle: '잠시만 기다려 주세요.',
                                        task: () async {
                                          // 댓글 먼저 삭제
                                          final comments = await FirebaseFirestore.instance
                                              .collection('posts').doc(postId).collection('comments').get();
                                          for (final c in comments.docs) { await c.reference.delete(); }
                                          await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                                        },
                                      );
                                      if (mounted) showSavedSnackBar(sm, message: '삭제됐어요.');
                                    } catch (e) {
                                      if (mounted) showSaveErrorSnackBar(sm, message: '$e');
                                    }
                                  },
                                ),
                                Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.mu, size: 18),
                              ],
                            ),
                          ),
                        ),
                        // 펼침: 내용 + 이미지 + 댓글
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(content, style: TextStyle(fontSize: 13, color: C.tx2)),
                            ),
                          ),
                          if (imageUrls.isNotEmpty) ...[
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                                itemCount: imageUrls.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 6),
                                itemBuilder: (_, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(imageUrl: imageUrls[i], width: 80, height: 80, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ],
                          // 댓글 목록
                          _CommunityAdminComments(postId: postId),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommunityAdminComments extends StatelessWidget {
  final String postId;
  const _CommunityAdminComments({required this.postId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts').doc(postId).collection('comments')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Text('댓글 없음', style: TextStyle(fontSize: 12, color: C.mu)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Text('댓글 ${docs.length}개', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.tx2)),
            ),
            ...docs.map((doc) {
              final d = doc.data();
              final author = d['authorName'] as String? ?? '익명';
              final body = d['body'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$author  ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: C.tx)),
                          Expanded(child: Text(body, style: TextStyle(fontSize: 12, color: C.tx2))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 15, color: C.og),
                      tooltip: '댓글 삭제',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        try {
                          await runWithMoriLoadingDialog<void>(
                            context,
                            message: '삭제하는 중입니다.',
                            subtitle: '잠시만 기다려 주세요.',
                            task: () => doc.reference.delete(),
                          );
                          if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: '댓글 삭제됐어요.');
                        } catch (e) {
                          if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── 공지사항 어드민 탭 (landing_notices) ──────────────────────────────────────
class _NoticesAdminTab extends StatefulWidget {
  const _NoticesAdminTab();
  @override
  State<_NoticesAdminTab> createState() => _NoticesAdminTabState();
}

class _NoticesAdminTabState extends State<_NoticesAdminTab> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더 + 추가 버튼
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('공지사항 관리', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.tx)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('새 공지'),
                onPressed: () => _showEditDialog(context, null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LandingPost>>(
            stream: LandingBoardRepository().getNotices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = snapshot.data ?? [];
              if (posts.isEmpty) {
                return Center(child: Text('공지사항이 없습니다. 새 공지를 추가해보세요.', style: TextStyle(color: C.mu)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final post = posts[i];
                  final isExpanded = _expandedId == post.id;
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: C.bd.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _expandedId = isExpanded ? null : post.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                if (post.isPinned)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(Icons.push_pin_rounded, size: 14, color: C.lv),
                                  ),
                                Expanded(
                                  child: Text(post.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 11, color: C.mu),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  tooltip: '수정',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  color: C.lvD,
                                  onPressed: () => _showEditDialog(context, post),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, size: 16, color: C.og),
                                  tooltip: '삭제',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteNotice(context, post),
                                ),
                                const SizedBox(width: 4),
                                Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.mu, size: 18),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(post.content, style: TextStyle(fontSize: 13, color: C.tx2, height: 1.6)),
                                ),
                                if (post.imageUrl.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: post.imageUrl,
                                      width: double.infinity,
                                      height: 160,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => const SizedBox(),
                                    ),
                                  ),
                                ],
                                if (post.fileUrl.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => launchUrl(Uri.parse(post.fileUrl), mode: LaunchMode.externalApplication),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: C.lvL,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: C.lv.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.insert_drive_file_rounded, size: 14, color: C.lv),
                                          const SizedBox(width: 6),
                                          Text(
                                            post.fileName.isNotEmpty ? post.fileName : '첨부파일',
                                            style: TextStyle(fontSize: 12, color: C.lv, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteNotice(BuildContext context, LandingPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: Text('[${post.title}] 공지를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('삭제', style: TextStyle(color: C.og))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '삭제하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () => FirebaseFirestore.instance.collection('landing_notices').doc(post.id).delete(),
      );
      if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: '삭제됐어요.');
    } catch (e) {
      if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _showEditDialog(BuildContext context, LandingPost? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    bool isPinned = existing?.isPinned ?? false;
    String imageUrl = existing?.imageUrl ?? '';
    String fileUrl = existing?.fileUrl ?? '';
    String fileName = existing?.fileName ?? '';
    bool uploading = false;
    bool fileUploading = false;

    InputDecoration adminDec(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      fillColor: Colors.white.withValues(alpha: 0.10), filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white60)),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? '공지사항 추가' : '공지사항 수정',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: adminDec('제목'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: adminDec('내용'),
                  ),
                  const SizedBox(height: 12),
                  // ── 사진 첨부 ────────────────────────────────────────────
                  Row(
                    children: [
                      const Text('사진 첨부', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      if (uploading)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        TextButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (picked == null) return;
                            setDialogState(() => uploading = true);
                            try {
                              final bytes = await picked.readAsBytes();
                              final ext = picked.name.split('.').last.toLowerCase();
                              final docId = existing?.id.isNotEmpty == true ? existing!.id : 'new_${DateTime.now().millisecondsSinceEpoch}';
                              final ref = FirebaseStorage.instance.ref('announcements/$docId/cover.$ext');
                              await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
                              final url = await ref.getDownloadURL();
                              setDialogState(() { imageUrl = url; uploading = false; });
                            } catch (e) {
                              setDialogState(() => uploading = false);
                              if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '업로드 실패: $e');
                            }
                          },
                          icon: const Icon(Icons.upload_rounded, size: 16, color: Colors.white70),
                          label: const Text('갤러리에서 선택', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                    ],
                  ),
                  if (imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(imageUrl: imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => setDialogState(() => imageUrl = ''),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // ── 파일 첨부 ────────────────────────────────────────────
                  Row(
                    children: [
                      const Text('파일 첨부', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      if (fileUploading)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        TextButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(type: FileType.any);
                            if (result == null || result.files.isEmpty) return;
                            final picked = result.files.first;
                            final bytes = picked.bytes;
                            if (bytes == null) return;
                            setDialogState(() => fileUploading = true);
                            try {
                              final docId = existing?.id.isNotEmpty == true ? existing!.id : 'new_${DateTime.now().millisecondsSinceEpoch}';
                              final ref = FirebaseStorage.instance.ref('announcements/$docId/files/${picked.name}');
                              await ref.putData(bytes);
                              final url = await ref.getDownloadURL();
                              setDialogState(() { fileUrl = url; fileName = picked.name; fileUploading = false; });
                            } catch (e) {
                              setDialogState(() => fileUploading = false);
                              if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '파일 업로드 실패: $e');
                            }
                          },
                          icon: const Icon(Icons.attach_file_rounded, size: 16, color: Colors.white70),
                          label: const Text('파일 선택', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                    ],
                  ),
                  if (fileUrl.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_rounded, size: 16, color: Colors.white60),
                          const SizedBox(width: 8),
                          Expanded(child: Text(fileName, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          GestureDetector(
                            onTap: () => setDialogState(() { fileUrl = ''; fileName = ''; }),
                            child: const Icon(Icons.close, size: 16, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isPinned,
                        onChanged: (v) => setDialogState(() => isPinned = v ?? false),
                      ),
                      const Text('상단 고정 (isPinned)', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (title.isEmpty) return;
                final repo = LandingBoardRepository();
                try {
                  await runWithMoriLoadingDialog<void>(
                    ctx,
                    message: '저장하는 중입니다.',
                    subtitle: '잠시만 기다려 주세요.',
                    task: () async {
                      if (existing == null) {
                        final newPost = LandingPost(
                          id: '',
                          title: title,
                          content: content,
                          authorUid: 'admin',
                          authorName: '관리자',
                          createdAt: DateTime.now(),
                          isPinned: isPinned,
                          isNotice: true,
                          imageUrl: imageUrl,
                          fileUrl: fileUrl,
                          fileName: fileName,
                        );
                        await repo.createNotice(newPost);
                      } else {
                        await FirebaseFirestore.instance
                            .collection('landing_notices')
                            .doc(existing.id)
                            .update({'title': title, 'content': content, 'isPinned': isPinned, 'imageUrl': imageUrl, 'fileUrl': fileUrl, 'fileName': fileName});
                      }
                    },
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    showSavedSnackBar(ScaffoldMessenger.of(context), message: '저장됐어요.');
                  }
                } catch (e) {
                  if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 랜딩 게시판 어드민 탭 (review / release / qa) ────────────────────────────
class _LandingBoardAdminTab extends StatefulWidget {
  final String boardType;
  final String title;
  const _LandingBoardAdminTab({required this.boardType, required this.title});
  @override
  State<_LandingBoardAdminTab> createState() => _LandingBoardAdminTabState();
}

class _LandingBoardAdminTabState extends State<_LandingBoardAdminTab> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('${widget.title} 관리', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.tx)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('새 글 작성'),
                onPressed: () => _showEditDialog(context, null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LandingPost>>(
            stream: LandingBoardRepository().getPosts(widget.boardType),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = snapshot.data ?? [];
              if (posts.isEmpty) {
                return Center(child: Text('게시글이 없습니다. 새 글을 추가해보세요.', style: TextStyle(color: C.mu)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final post = posts[i];
                  final isExpanded = _expandedId == post.id;
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: C.bd.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _expandedId = isExpanded ? null : post.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(post.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                Text(post.authorName, style: TextStyle(fontSize: 12, color: C.tx2)),
                                const SizedBox(width: 8),
                                Text(
                                  '${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 11, color: C.mu),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.visibility_outlined, size: 12, color: C.mu),
                                const SizedBox(width: 2),
                                Text('${post.viewCount}', style: TextStyle(fontSize: 11, color: C.mu)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  tooltip: '수정',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  color: C.lvD,
                                  onPressed: () => _showEditDialog(context, post),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, size: 16, color: C.og),
                                  tooltip: '삭제',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deletePost(context, post),
                                ),
                                const SizedBox(width: 4),
                                Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.mu, size: 18),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(post.content, style: TextStyle(fontSize: 13, color: C.tx2, height: 1.6)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deletePost(BuildContext context, LandingPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${widget.title} 삭제'),
        content: Text('[${post.title}] 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('삭제', style: TextStyle(color: C.og))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: '삭제하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () async {
          final postRef = FirebaseFirestore.instance
              .collection('landing_boards')
              .doc(widget.boardType)
              .collection('posts')
              .doc(post.id);
          final comments = await postRef.collection('comments').get();
          for (final c in comments.docs) {
            await c.reference.delete();
          }
          await postRef.delete();
        },
      );
      if (context.mounted) showSavedSnackBar(ScaffoldMessenger.of(context), message: '삭제됐어요.');
    } catch (e) {
      if (context.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    }
  }

  void _showEditDialog(BuildContext context, LandingPost? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '${widget.title} 추가' : '${widget.title} 수정',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: '제목', labelStyle: const TextStyle(color: Colors.white70), fillColor: Colors.white.withValues(alpha: 0.10), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24))),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: '내용', labelStyle: const TextStyle(color: Colors.white70), fillColor: Colors.white.withValues(alpha: 0.10), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24))),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final content = contentCtrl.text.trim();
              if (title.isEmpty) return;
              final repo = LandingBoardRepository();
              try {
                await runWithMoriLoadingDialog<void>(
                  ctx,
                  message: '저장하는 중입니다.',
                  subtitle: '잠시만 기다려 주세요.',
                  task: () async {
                    if (existing == null) {
                      final newPost = LandingPost(
                        id: '',
                        title: title,
                        content: content,
                        authorUid: 'admin',
                        authorName: '관리자',
                        createdAt: DateTime.now(),
                        type: widget.boardType,
                      );
                      await repo.createPost(newPost);
                    } else {
                      await FirebaseFirestore.instance
                          .collection('landing_boards')
                          .doc(widget.boardType)
                          .collection('posts')
                          .doc(existing.id)
                          .update({'title': title, 'content': content});
                    }
                  },
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  showSavedSnackBar(ScaffoldMessenger.of(context), message: '저장됐어요.');
                }
              } catch (e) {
                if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}


// ── 1:1 문의 관리

class _InquiriesAdminTab extends ConsumerStatefulWidget {
  const _InquiriesAdminTab();
  @override
  ConsumerState<_InquiriesAdminTab> createState() => _InquiriesAdminTabState();
}

class _InquiriesAdminTabState extends ConsumerState<_InquiriesAdminTab> {
  String? _selectedId;

  static const _inquiryColumns = [
    AdminColumn(label: '상태', fixedWidth: 56),
    AdminColumn(label: '제목 / 작성자', flex: 4),
    AdminColumn(label: '접수일', flex: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_inquiriesProvider);
    return Row(
      children: [
        SizedBox(
          width: 380,
          child: async.when(
            loading: () => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
              title: '1:1 문의',
              icon: Icons.mail_rounded,
              columns: _inquiryColumns,
              items: const [],
              isLoading: true,
              rowBuilder: (_, _) => const AdminRow(cells: []),
            ),
            error: (e, _) => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
              title: '1:1 문의',
              icon: Icons.mail_rounded,
              columns: _inquiryColumns,
              items: const [],
              errorMessage: '$e',
              rowBuilder: (_, _) => const AdminRow(cells: []),
            ),
            data: (docs) => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
              title: '1:1 문의',
              icon: Icons.mail_rounded,
              columns: _inquiryColumns,
              items: docs,
              emptyMessage: '접수된 문의가 없습니다.',
              selectable: true,
              itemKey: (d) => d.id,
              bulkActions: [
                AdminBulkAction(
                  label: '선택 답변완료',
                  icon: Icons.check_circle_outline,
                  accent: Colors.green.shade600,
                  requireConfirm: true,
                  confirmMessage: '선택한 문의를 답변완료로 표시할까요?',
                  loadingMessage: '답변완료 처리 중입니다.',
                  onTap: (selected) async {
                    await _bulkUpdateDocs(
                      selected.map((d) => d.reference).toList(),
                      {'isResolved': true},
                    );
                  },
                ),
                AdminBulkAction(
                  label: '선택 삭제',
                  icon: Icons.delete_outline_rounded,
                  accent: C.og,
                  requireConfirm: true,
                  confirmMessage: '선택한 문의를 모두 삭제할까요? 되돌릴 수 없습니다.',
                  loadingMessage: '문의를 삭제하는 중입니다.',
                  onTap: (selected) async {
                    await _bulkDeleteDocs(
                        selected.map((d) => d.reference).toList());
                  },
                ),
              ],
              rowBuilder: (ctx, doc) {
                final data = doc.data();
                final isResolved = data['isResolved'] as bool? ?? false;
                final isSelected = _selectedId == doc.id;
                final authorName = data['authorName'] as String? ?? '';
                final title = data['title'] as String? ?? '';
                final createdAt = data['createdAt'] != null
                    ? DateTime.tryParse(data['createdAt'] as String? ?? '')
                    : null;
                final accentColor = isResolved ? const Color(0xFF4CAF50) : const Color(0xFF34D399);
                return AdminRow(
                  selected: isSelected,
                  accent: accentColor,
                  onTap: () => setState(() => _selectedId = isSelected ? null : doc.id),
                  cells: [
                    AdminBadge(label: isResolved ? '완료' : '신규', color: accentColor),
                    AdminCellTwoLine(title: title, subtitle: authorName),
                    AdminCellText(
                      createdAt != null ? DateFormat('MM.dd HH:mm').format(createdAt) : '-',
                      muted: true,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: async.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (docs) {
              if (_selectedId == null) {
                return const Center(child: Text('목록에서 문의를 선택하세요.', style: TextStyle(color: Colors.grey)));
              }
              final selectedDoc = docs.where((d) => d.id == _selectedId!).firstOrNull;
              if (selectedDoc == null) {
                return const Center(child: Text('목록에서 문의를 선택하세요.', style: TextStyle(color: Colors.grey)));
              }
              return _InquiryDetail(doc: selectedDoc, onDeleted: () => setState(() => _selectedId = null));
            },
          ),
        ),
      ],
    );
  }

}

class _InquiryDetail extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback? onDeleted;
  const _InquiryDetail({required this.doc, this.onDeleted});
  @override
  State<_InquiryDetail> createState() => _InquiryDetailState();
}

class _InquiryDetailState extends State<_InquiryDetail> {
  late final TextEditingController _memoCtrl;
  bool _isResolved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data();
    _memoCtrl = TextEditingController(text: data['adminMemo'] as String? ?? '');
    _isResolved = data['isResolved'] as bool? ?? false;
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('landing_boards').doc('qa').collection('posts').doc(widget.doc.id)
          .update({'adminMemo': _memoCtrl.text.trim(), 'isResolved': _isResolved});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장됐습니다.'), duration: Duration(milliseconds: 1200)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문의 삭제'),
        content: const Text('이 문의를 삭제하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await FirebaseFirestore.instance
          .collection('landing_boards').doc('qa').collection('posts').doc(widget.doc.id).delete();
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final title = data['title'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    final authorName = data['authorName'] as String? ?? '';
    final authorEmail = data['authorUid'] as String? ?? '';
    final createdAt = data['createdAt'] != null
        ? DateTime.tryParse(data['createdAt'] as String? ?? '') : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (authorEmail.contains('@'))
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri(scheme: 'mailto', path: authorEmail,
                        queryParameters: {'subject': 'Re: $title', 'body': '\n\n---\n원본 문의:\n$content'});
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: const Text('메일로 답장'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF34D399)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 4,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(authorName, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
              if (authorEmail.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(authorEmail, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
              if (createdAt != null)
                Text(DateFormat('yyyy.MM.dd HH:mm').format(createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(content, style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF1A1A2E))),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Checkbox(value: _isResolved, activeColor: const Color(0xFF4CAF50),
                onChanged: (v) => setState(() => _isResolved = v ?? false)),
            const Text('처리 완료', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          const Text('관리자 메모', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _memoCtrl,
            decoration: const InputDecoration(
              hintText: '이 건 처리 메모를 입력해주세요..',
              border: OutlineInputBorder(),
              filled: true, fillColor: Colors.white,
              contentPadding: EdgeInsets.all(12),
            ),
            maxLines: 5, minLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('삭제'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('저장'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34D399), foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 게시판 관리 탭 (community_posts + public_projects) ─────────────────────────
class _BoardManagementTab extends StatefulWidget {
  const _BoardManagementTab();

  @override
  State<_BoardManagementTab> createState() => _BoardManagementTabState();
}

class _BoardManagementTabState extends State<_BoardManagementTab> {
  // 0 = posts, 1 = gallery, 2 = community_posts, 3 = public_projects
  int _boardIndex = 0;

  static const _boardTabs = ['posts 게시물', '갤러리(gallery)', '커뮤니티 게시물', '완성갤러리 게시물'];
  static const _collections = ['posts', 'gallery', 'community_posts', 'public_projects'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 탭 선택
        Container(
          height: 44,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: List.generate(_boardTabs.length, (i) {
              final selected = i == _boardIndex;
              return GestureDetector(
                onTap: () => setState(() => _boardIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? C.lv : C.lvL,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _boardTabs[i],
                    style: TextStyle(
                      color: selected ? Colors.white : C.lvD,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _BoardPostList(
            collection: _collections[_boardIndex],
            title: _boardTabs[_boardIndex],
          ),
        ),
      ],
    );
  }
}

class _BoardPostList extends StatefulWidget {
  final String collection;
  final String title;

  const _BoardPostList({required this.collection, required this.title});

  @override
  State<_BoardPostList> createState() => _BoardPostListState();
}

class _BoardPostListState extends State<_BoardPostList> {
  String _search = '';

  static const _columns = [
    AdminColumn(label: '제목', flex: 4),
    AdminColumn(label: '작성자', flex: 1),
    AdminColumn(label: '작성일', fixedWidth: 110),
    AdminColumn(label: '관리', fixedWidth: 60, align: TextAlign.end),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(widget.collection)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
            title: widget.title,
            icon: Icons.dashboard_rounded,
            columns: _columns,
            items: const [],
            isLoading: true,
            rowBuilder: (_, _) => const AdminRow(cells: []),
          );
        }
        final allDocs = snapshot.data?.docs ?? [];
        final docs = _search.isEmpty
            ? allDocs
            : allDocs.where((d) {
                final data = d.data();
                final title =
                    ((data['title'] ?? data['name']) ?? '').toString().toLowerCase();
                return title.contains(_search);
              }).toList();
        return AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
          title: widget.title,
          icon: Icons.dashboard_rounded,
          columns: _columns,
          items: docs,
          searchHint: '제목 검색',
          onSearchChanged: (v) => setState(() => _search = v.toLowerCase()),
          emptyMessage: '게시물이 없습니다.',
          selectable: true,
          itemKey: (d) => d.reference.path,
          bulkActions: [
            AdminBulkAction(
              label: '선택 삭제',
              icon: Icons.delete_outline_rounded,
              accent: C.og,
              requireConfirm: true,
              confirmMessage: '선택한 게시물을 모두 삭제할까요? 되돌릴 수 없습니다.',
              loadingMessage: '게시물을 삭제하는 중입니다.',
              onTap: (selected) async {
                await _bulkDeleteDocs(
                    selected.map((d) => d.reference).toList());
              },
            ),
          ],
          rowBuilder: (ctx, doc) {
            final data = doc.data();
            final docId = doc.id;
            final postTitle = data['title'] as String? ??
                data['name'] as String? ??
                '(제목 없음)';
            final author = data['authorName'] as String? ??
                data['displayName'] as String? ??
                '익명';
            final createdAt = data['createdAt'];
            String timeStr = '';
            if (createdAt is Timestamp) {
              final dt = createdAt.toDate();
              timeStr = DateFormat('yyyy-MM-dd').format(dt);
            }
            return AdminRow(
              cells: [
                AdminCellText(postTitle, bold: true),
                AdminCellText(author, muted: true),
                AdminCellText(timeStr.isNotEmpty ? timeStr : '-', muted: true),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: C.og, size: 18),
                    tooltip: '게시물 삭제',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (dialogCtx) => AlertDialog(
                          title: const Text('게시물 삭제'),
                          content: Text('[$postTitle] 게시물을 삭제하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              child: Text('삭제', style: TextStyle(color: C.og)),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      if (!ctx.mounted) return;
                      try {
                        await runWithMoriLoadingDialog<void>(
                          ctx,
                          message: '삭제하는 중입니다.',
                          subtitle: '잠시만 기다려 주세요.',
                          task: () async {
                            await FirebaseFirestore.instance
                                .collection(widget.collection)
                                .doc(docId)
                                .delete();
                          },
                        );
                        if (ctx.mounted) {
                          showSavedSnackBar(
                            ScaffoldMessenger.of(ctx),
                            message: '게시물이 삭제됐어요.',
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          showSaveErrorSnackBar(
                            ScaffoldMessenger.of(ctx),
                            message: '$e',
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── 어드민 도안 탭 ───────────────────────────────────────────────────────────

class _AdminPatternsTab extends ConsumerStatefulWidget {
  const _AdminPatternsTab();
  @override
  ConsumerState<_AdminPatternsTab> createState() => _AdminPatternsTabState();
}

class _AdminPatternsTabState extends ConsumerState<_AdminPatternsTab> {
  String _search = '';
  bool _migrating = false;
  int _migrateCurrent = 0;
  int _migrateTotal = 0;

  Future<void> _runCoverMigration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PDF 커버 일괄 추출'),
        content: const Text(
          '모든 사용자의 PDF 도안 중 커버 이미지가 없는 항목을 검색해 첫 페이지를 추출합니다.\n\n'
          '- 이미 커버가 있는 도안은 건너뜁니다.\n'
          '- 실패한 도안은 건너뛰고 계속 진행합니다.\n'
          '- 도안이 많으면 시간이 오래 걸릴 수 있어요.\n\n'
          '진행하시겠어요?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('진행')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() {
      _migrating = true;
      _migrateCurrent = 0;
      _migrateTotal = 0;
    });

    final repo = ref.read(patternRepositoryProvider);
    try {
      final processed = await runWithMoriLoadingDialog<int>(
        context,
        message: 'PDF 커버를 추출하고 있어요.',
        subtitle: '잠시만 기다려 주세요.',
        task: () async {
          return repo.migrateMissingCoversForAllUsers(
            onProgress: (cur, total) {
              if (!mounted) return;
              setState(() {
                _migrateCurrent = cur;
                _migrateTotal = total;
              });
            },
          );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: '$processed개 처리됐어요.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) {
        setState(() => _migrating = false);
      }
    }
  }

  static const _columns = [
    AdminColumn(label: '타입', fixedWidth: 64),
    AdminColumn(label: '제목 / 소유자', flex: 4),
    AdminColumn(label: '단계', fixedWidth: 80),
    AdminColumn(label: '생성일', flex: 1),
    AdminColumn(label: '관리', fixedWidth: 60, align: TextAlign.end),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminAllPatternsProvider);
    final trailing = ElevatedButton.icon(
      onPressed: _migrating ? null : _runCoverMigration,
      icon: const Icon(Icons.download_for_offline_rounded, size: 16),
      label: Text(_migrating && _migrateTotal > 0
          ? '커버 추출 $_migrateCurrent / $_migrateTotal'
          : (_migrating ? '대상 검색 중...' : 'PDF 커버 일괄 추출')),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFB47EEB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );

    return async.when(
      loading: () => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: '도안',
        icon: Icons.auto_fix_high_rounded,
        columns: _columns,
        items: const [],
        isLoading: true,
        trailing: trailing,
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      error: (e, _) => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: '도안',
        icon: Icons.auto_fix_high_rounded,
        columns: _columns,
        items: const [],
        errorMessage: '$e',
        trailing: trailing,
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      data: (docs) {
        final filtered = _search.isEmpty
            ? docs
            : docs.where((d) {
                final title = (d.data()['title'] ?? '').toString().toLowerCase();
                return title.contains(_search);
              }).toList();
        return AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
          title: '도안',
          icon: Icons.auto_fix_high_rounded,
          columns: _columns,
          items: filtered,
          searchHint: '제목 검색',
          onSearchChanged: (v) => setState(() => _search = v.toLowerCase()),
          trailing: trailing,
          emptyMessage: '도안이 없습니다.',
          selectable: true,
          itemKey: (d) => d.reference.path,
          bulkActions: [
            AdminBulkAction(
              label: '선택 삭제',
              icon: Icons.delete_outline_rounded,
              accent: C.og,
              requireConfirm: true,
              confirmMessage: '선택한 도안을 모두 삭제할까요? 되돌릴 수 없습니다.',
              loadingMessage: '도안을 삭제하는 중입니다.',
              onTap: (selected) async {
                await _bulkDeleteDocs(
                    selected.map((d) => d.reference).toList());
              },
            ),
          ],
          rowBuilder: (ctx, doc) {
            final data = doc.data();
            final pathParts = doc.reference.path.split('/');
            final ownerUid = pathParts.length >= 2 ? pathParts[1] : '';
            final title = data['title'] as String? ?? '(제목 없음)';
            final createdAt = data['createdAt'];
            String dateStr = '';
            if (createdAt is Timestamp) {
              dateStr = DateFormat('yyyy-MM-dd').format(createdAt.toDate());
            }
            final typeStr = (data['type'] as String?) ?? 'unknown';
            final typeLabel = switch (typeStr) {
              'pdf' => 'PDF',
              'image' => '이미지',
              'chart' => '차트',
              _ => typeStr,
            };
            final typeColor = switch (typeStr) {
              'pdf' => const Color(0xFFFF8C42),
              'image' => const Color(0xFF34C759),
              'chart' => const Color(0xFFB47EEB),
              _ => Colors.grey,
            };
            final sourceOwnerName = data['sourceOwnerName'] as String?;
            final aiSections = data['aiSections'] as List?;
            final hasSteps = aiSections != null && aiSections.isNotEmpty;
            final subtitleText = sourceOwnerName != null && sourceOwnerName.isNotEmpty
                ? '생성자: $sourceOwnerName · UID: $ownerUid'
                : 'UID: $ownerUid';
            return AdminRow(
              accent: typeColor,
              cells: [
                // 타입
                AdminBadge(label: typeLabel, color: typeColor),
                // 제목 / 소유자
                AdminCellTwoLine(title: title, subtitle: subtitleText),
                // 단계
                hasSteps
                    ? AdminBadge(label: '단계 있음', color: const Color(0xFFEC4899))
                    : AdminCellText('-', muted: true),
                // 생성일
                AdminCellText(dateStr.isNotEmpty ? dateStr : '-', muted: true),
                // 관리
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                    tooltip: '삭제',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: const Text('도안 삭제'),
                          content: Text('[$title] 도안을 삭제하시겠습니까?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('취소')),
                            TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text('삭제', style: TextStyle(color: Colors.red.shade400))),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      if (!ctx.mounted) return;
                      try {
                        await runWithMoriLoadingDialog<void>(
                          ctx,
                          message: '삭제하는 중입니다.',
                          subtitle: '잠시만 기다려 주세요.',
                          task: () => doc.reference.delete(),
                        );
                        if (ctx.mounted) showSavedSnackBar(ScaffoldMessenger.of(ctx), message: '삭제됐어요.');
                      } catch (e) {
                        if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── 어드민 템플릿 탭 ─────────────────────────────────────────────────────────

class _AdminTemplatesTab extends ConsumerStatefulWidget {
  const _AdminTemplatesTab();
  @override
  ConsumerState<_AdminTemplatesTab> createState() => _AdminTemplatesTabState();
}

class _AdminTemplatesTabState extends ConsumerState<_AdminTemplatesTab> {
  String _search = '';

  static const _columns = [
    AdminColumn(label: '템플릿명 / 소유자', flex: 4),
    AdminColumn(label: '관리', fixedWidth: 60, align: TextAlign.end),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminAllTemplatesProvider);
    return async.when(
      loading: () => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: '템플릿',
        icon: Icons.list_alt_rounded,
        columns: _columns,
        items: const [],
        isLoading: true,
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      error: (e, _) => AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: '템플릿',
        icon: Icons.list_alt_rounded,
        columns: _columns,
        items: const [],
        errorMessage: '$e',
        rowBuilder: (_, _) => const AdminRow(cells: []),
      ),
      data: (docs) {
        final filtered = _search.isEmpty
            ? docs
            : docs.where((d) {
                final name = (d.data()['name'] ?? '').toString().toLowerCase();
                return name.contains(_search);
              }).toList();
        return AdminListShell<QueryDocumentSnapshot<Map<String, dynamic>>>(
          title: '템플릿',
          icon: Icons.list_alt_rounded,
          columns: _columns,
          items: filtered,
          searchHint: '이름 검색',
          onSearchChanged: (v) => setState(() => _search = v.toLowerCase()),
          emptyMessage: '템플릿이 없습니다.',
          selectable: true,
          itemKey: (d) => d.reference.path,
          bulkActions: [
            AdminBulkAction(
              label: '선택 삭제',
              icon: Icons.delete_outline_rounded,
              accent: C.og,
              requireConfirm: true,
              confirmMessage: '선택한 템플릿을 모두 삭제할까요? 되돌릴 수 없습니다.',
              loadingMessage: '템플릿을 삭제하는 중입니다.',
              onTap: (selected) async {
                await _bulkDeleteDocs(
                    selected.map((d) => d.reference).toList());
              },
            ),
          ],
          rowBuilder: (ctx, doc) {
            final data = doc.data();
            final pathParts = doc.reference.path.split('/');
            final ownerUid = pathParts.length >= 2 ? pathParts[1] : '';
            final name = data['name'] as String? ?? '(이름 없음)';
            return AdminRow(
              cells: [
                AdminCellTwoLine(title: name, subtitle: 'UID: $ownerUid'),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                    tooltip: '삭제',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: const Text('템플릿 삭제'),
                          content: Text('[$name] 템플릿을 삭제하시겠습니까?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('취소')),
                            TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text('삭제', style: TextStyle(color: Colors.red.shade400))),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      if (!ctx.mounted) return;
                      try {
                        await runWithMoriLoadingDialog<void>(
                          ctx,
                          message: '삭제하는 중입니다.',
                          subtitle: '잠시만 기다려 주세요.',
                          task: () => doc.reference.delete(),
                        );
                        if (ctx.mounted) showSavedSnackBar(ScaffoldMessenger.of(ctx), message: '삭제됐어요.');
                      } catch (e) {
                        if (ctx.mounted) showSaveErrorSnackBar(ScaffoldMessenger.of(ctx), message: '$e');
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── 서비스 제어 카드 (회원관리 탭 상단에 표시) ─────────────────────────────────
class _ServiceControlCard extends ConsumerStatefulWidget {
  const _ServiceControlCard();

  @override
  ConsumerState<_ServiceControlCard> createState() => _ServiceControlCardState();
}

class _ServiceControlCardState extends ConsumerState<_ServiceControlCard> {
  bool _communityEnabled = true;
  bool _sellerEnabled = true;
  bool _encyclopediaEnabled = true;
  final _backgroundCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _backgroundCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_supportConfigProvider);
    return async.when(
      data: (data) {
        if (!_loaded) {
          _communityEnabled = data['communityWriteEnabled'] != false;
          _sellerEnabled = data['sellerSubmissionEnabled'] != false;
          _encyclopediaEnabled = data['encyclopediaSuggestionEnabled'] != false;
          _backgroundCtrl.text = data['backgroundImageUrl']?.toString() ?? '';
          _loaded = true;
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('서비스 제어', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), height: 1.3)),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _communityEnabled,
                  onChanged: (v) => setState(() => _communityEnabled = v),
                  title: const Text('커뮤니티 글쓰기 허용'),
                ),
                SwitchListTile(
                  value: _sellerEnabled,
                  onChanged: (v) => setState(() => _sellerEnabled = v),
                  title: const Text('판매 등록 허용'),
                ),
                SwitchListTile(
                  value: _encyclopediaEnabled,
                  onChanged: (v) => setState(() => _encyclopediaEnabled = v),
                  title: const Text('백과사전 제안 허용'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _backgroundCtrl,
                  decoration: const InputDecoration(
                    labelText: '배경 이미지 URL',
                    helperText: '지금은 저장만 합니다. 추후 앱 배경 커스터마이징과 연결될 예정입니다.',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('app_config').doc('admin_support').set(
        {
          'communityWriteEnabled': _communityEnabled,
          'sellerSubmissionEnabled': _sellerEnabled,
          'encyclopediaSuggestionEnabled': _encyclopediaEnabled,
          'backgroundImageUrl': _backgroundCtrl.text.trim(),
        },
        SetOptions(merge: true),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── 사용자 통합관리 탭 (users 컬렉션 + plan + 프로젝트/스와치 수) ─────────────
class _UserStatsAdminTab extends ConsumerStatefulWidget {
  const _UserStatsAdminTab();

  @override
  ConsumerState<_UserStatsAdminTab> createState() => _UserStatsAdminTabState();
}

class _UserStatsAdminTabState extends ConsumerState<_UserStatsAdminTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_adminUsersProvider);
    final query = _searchCtrl.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ServiceControlCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: '이름 또는 이메일로 검색',
            ),
          ),
        ),
        // 헤더 행
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              const SizedBox(width: 44),
              const Expanded(flex: 3, child: Text('이름 / 이메일', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
              const SizedBox(width: 8),
              const SizedBox(width: 80, child: Text('플랜', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
              const SizedBox(width: 8),
              const SizedBox(width: 60, child: Text('프로젝트', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)), textAlign: TextAlign.center)),
              const SizedBox(width: 8),
              const SizedBox(width: 60, child: Text('스와치', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)), textAlign: TextAlign.center)),
              const SizedBox(width: 8),
              const SizedBox(width: 90, child: Text('가입일', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
            ],
          ),
        ),
        Expanded(
          child: usersAsync.when(
            data: (users) {
              final filtered = users.where((u) {
                if (query.isEmpty) return true;
                return u.displayName.toLowerCase().contains(query) ||
                    u.email.toLowerCase().contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text('조건에 맞는 회원이 없습니다.', style: TextStyle(color: C.mu)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (ctx, index) {
                  final user = filtered[index];
                  return _UserStatsRow(user: user);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e', style: TextStyle(color: C.og))),
          ),
        ),
      ],
    );
  }
}

class _UserStatsRow extends StatelessWidget {
  final UserModel user;

  const _UserStatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final created = user.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd').format(user.createdAt!);
    final planId = user.subscription.planId;
    final projectCount = user.usage.projectCount;
    final swatchCount = user.usage.swatchCount;

    Color planColor;
    switch (planId) {
      case 'premium':
      case 'pro':
        planColor = const Color(0xFFB47EEB);
        break;
      case 'basic':
        planColor = const Color(0xFF38BDF8);
        break;
      default:
        planColor = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.bd.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: C.lvL,
            backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
            child: user.photoURL.isEmpty
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : user.email.isNotEmpty
                            ? user.email[0].toUpperCase()
                            : 'U',
                    style: TextStyle(color: C.lvD, fontWeight: FontWeight.bold, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isEmpty ? user.email : user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email,
                  style: TextStyle(fontSize: 11, color: C.mu),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: planColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: planColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                planId,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: planColor),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              '$projectCount',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              '$swatchCount',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              created,
              style: TextStyle(fontSize: 11, color: C.mu),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 목업 이미지 관리 탭 ───────────────────────────────────────────────────────
final _mockupImagesDocProvider = StreamProvider<Map<String, String>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('mockup_images')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return <String, String>{};
    final data = snap.data()!;
    return {for (final e in data.entries) e.key: (e.value as String? ?? '')};
  });
});

class _MockupImagesAdminTab extends ConsumerStatefulWidget {
  const _MockupImagesAdminTab();
  @override
  ConsumerState<_MockupImagesAdminTab> createState() => _MockupImagesAdminTabState();
}

class _MockupImagesAdminTabState extends ConsumerState<_MockupImagesAdminTab> {
  bool _uploading = false;
  String? _uploadingKey;

  static const _featureItems = [
    ('project', '프로젝트 기록'),
    ('swatch', '스와치 보관함'),
    ('market', '도안 마켓'),
    ('community', '커뮤니티'),
    ('encyclopedia', '뜨개백과사전'),
    ('gauge', '게이지 계산기'),
    ('ravelry', 'Ravelry 연동'),
    ('etsy', 'Etsy 연동'),
    ('ai-pattern-converter', 'AI 도안 변환기'),
    ('ai-gauge', 'AI 게이지 판독기'),
    ('pattern-editor', '도안 에디터'),
    ('counter', '카운터 & 트래커'),
    ('measure', '측정 도구'),
    ('ai-translator', 'AI 영문 도안 번역기'),
    ('cloud-sync', '클라우드 연결'),
  ];

  static const _carouselItems = [
    ('screen-home', '홈'),
    ('screen-coach', '나의 니팅 코치'),
    ('screen-pattern-editor-ext', '도안에디터 확장'),
    ('screen-market-sell', '내 도안 판매'),
    ('screen-course', '강의'),
    ('screen-english', 'English'),
    ('screen-theme', '테마 설정'),
    ('screen-ravelry-yarn', 'Ravelry 실 검색'),
    ('screen-ravelry-pattern', 'Ravelry 도안 검색'),
  ];

  Future<void> _uploadImage(String mockupKey) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() { _uploading = true; _uploadingKey = mockupKey; });
    try {
      final ext = file.extension ?? 'jpg';
      final storageRef = FirebaseStorage.instance.ref('mockup_images/$mockupKey.$ext');
      await storageRef.putData(file.bytes!, SettableMetadata(contentType: 'image/$ext'));
      final url = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('mockup_images')
          .set({mockupKey: url}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업로드 완료'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _uploading = false; _uploadingKey = null; });
    }
  }

  Future<void> _deleteImage(String mockupKey) async {
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('mockup_images')
        .update({mockupKey: FieldValue.delete()});
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(_mockupImagesDocProvider).valueOrNull ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('목업 이미지 관리', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            '기능 상세페이지 및 홈 캐러셀에 표시되는 스크린샷 이미지를 관리합니다.\n이미지가 없으면 코드 렌더링 화면이 표시됩니다.',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6), height: 1.5),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('기능 상세페이지 목업', icon: Icons.web_asset_rounded),
          const SizedBox(height: 16),
          _buildGrid(_featureItems, images),
          const SizedBox(height: 32),
          _buildSectionHeader('홈 캐러셀 전용 화면', icon: Icons.view_carousel_rounded),
          const SizedBox(height: 16),
          _buildGrid(_carouselItems, images),
        ],
      ),
    );
  }

  Widget _buildGrid(List<(String, String)> items, Map<String, String> images) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items.map((item) {
        final (key, label) = item;
        final url = images[key] ?? '';
        return _MockupImageCard(
          mockupKey: key,
          label: label,
          imageUrl: url,
          isUploading: _uploading && _uploadingKey == key,
          onUpload: () => _uploadImage(key),
          onDelete: url.isNotEmpty ? () => _deleteImage(key) : null,
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6EE7B7), size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}

class _MockupImageCard extends StatelessWidget {
  final String mockupKey;
  final String label;
  final String imageUrl;
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback? onDelete;

  const _MockupImageCard({
    required this.mockupKey,
    required this.label,
    required this.imageUrl,
    required this.isUploading,
    required this.onUpload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: imageUrl.isNotEmpty
              ? const Color(0xFF6EE7B7).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _MockupPlaceholder())
                  : _MockupPlaceholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(mockupKey, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          onPressed: isUploading ? null : onUpload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6EE7B7),
                            foregroundColor: const Color(0xFF0F172A),
                            padding: EdgeInsets.zero,
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          child: isUploading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                              : const Text('업로드'),
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 30,
                        width: 30,
                        child: IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          color: Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockupPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Icon(Icons.smartphone_rounded, color: Colors.white.withValues(alpha: 0.15), size: 36),
      ),
    );
  }
}

// ── #687 Phase H 마이그레이션 탭 ──────────────────────────────────────────────

class _BlueprintMigrationTab extends StatefulWidget {
  final bool isKorean;
  final String adminUid;
  const _BlueprintMigrationTab({required this.isKorean, required this.adminUid});

  @override
  State<_BlueprintMigrationTab> createState() => _BlueprintMigrationTabState();
}

class _BlueprintMigrationTabState extends State<_BlueprintMigrationTab> {
  Map<String, MigrationResult>? _lastResult;
  CollectionCounts? _lastCounts;
  bool _lastDryRun = true;
  bool _running = false;

  String _localized(String ko, String en) => widget.isKorean ? ko : en;

  Future<void> _runMigration({required bool dryRun}) async {
    if (_running) return;
    if (!dryRun) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_localized('실제 마이그레이션 실행', 'Run real migration')),
          content: Text(_localized(
            '신규 청사진/실행 컬렉션에 데이터를 복제해요.\n기존 컬렉션은 삭제되지 않아요.\n진행할까요?',
            'This will copy data into new blueprint/run collections.\nExisting collections will NOT be deleted.\nProceed?',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_localized('취소', 'Cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_localized('실행', 'Run')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _running = true);
    try {
      final migration = BlueprintMigration(uid: widget.adminUid);
      final result = await runWithMoriLoadingDialog<Map<String, MigrationResult>>(
        context,
        message: _localized(
          dryRun ? 'Dry Run 시뮬레이션 중입니다.' : '마이그레이션 실행 중입니다.',
          dryRun ? 'Dry running...' : 'Migrating...',
        ),
        subtitle: _localized('잠시만 기다려 주세요.', 'Please wait a moment.'),
        task: () => migration.migrateAll(dryRun: dryRun),
      );
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _lastDryRun = dryRun;
      });
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: _localized(
          dryRun ? 'Dry Run 완료' : '마이그레이션 완료',
          dryRun ? 'Dry run completed' : 'Migration completed',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _runDiagnostics() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final migration = BlueprintMigration(uid: widget.adminUid);
      final counts = await runWithMoriLoadingDialog<CollectionCounts>(
        context,
        message: _localized('컬렉션 집계 중입니다.', 'Counting...'),
        subtitle: _localized('잠시만 기다려 주세요.', 'Please wait a moment.'),
        task: () => migration.countByCollection(),
      );
      if (!mounted) return;
      setState(() => _lastCounts = counts);
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: _localized('진단 완료', 'Diagnostics done'),
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          _localized('#687 Phase H — 마이그레이션', '#687 Phase H — Migration'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          _localized(
            '기존 컬렉션(pattern_charts / projects.steps / templates / builtin_templates)을\n'
            '신규 step_blueprints + step_runs 구조로 병렬 복제해요.\n'
            '기존 컬렉션은 절대 삭제되지 않으며, 재실행은 멱등(migrationVersion=$kBlueprintMigrationVersion)으로 안전합니다.',
            'Copies existing collections into the new blueprint/run structure.\n'
            'Existing collections are never deleted. Re-runs are idempotent.',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 20),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _running ? null : () => _runMigration(dryRun: true),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(_localized('Dry Run (시뮬레이션)', 'Dry Run (simulate)')),
            ),
            FilledButton.icon(
              onPressed: _running ? null : () => _runMigration(dryRun: false),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_localized('실제 마이그레이션 실행', 'Run real migration')),
            ),
            OutlinedButton.icon(
              onPressed: _running ? null : _runDiagnostics,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(_localized('컬렉션 진단', 'Count collections')),
            ),
          ],
        ),
        const SizedBox(height: 24),

        if (_lastResult != null) ...[
          Text(
            _localized(
              _lastDryRun ? '마지막 Dry Run 결과' : '마지막 실제 마이그레이션 결과',
              _lastDryRun ? 'Last dry run result' : 'Last real migration result',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ..._lastResult!.entries.map((e) => _ResultCard(label: e.key, result: e.value)),
        ],

        if (_lastCounts != null) ...[
          const SizedBox(height: 24),
          Text(
            _localized('컬렉션 진단 결과', 'Collection diagnostics'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(_lastCounts!.summary, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final MigrationResult result;
  const _ResultCard({required this.label, required this.result});

  @override
  Widget build(BuildContext context) {
    final hasErrors = result.errors > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasErrors ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasErrors ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(result.summary, style: const TextStyle(fontSize: 12)),
          if (result.errorMessages.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...result.errorMessages.take(5).map(
                  (msg) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• $msg',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                    ),
                  ),
                ),
            if (result.errorMessages.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '... +${result.errorMessages.length - 5} more',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
