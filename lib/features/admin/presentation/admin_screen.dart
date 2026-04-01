import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/editorial_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../home/domain/editorial_post.dart';
import '../data/admin_bulk_import_service.dart';
import '../domain/admin_import_models.dart';

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
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['isAdmin'] == true);
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

  const _AdminNavItem.group({required this.label, required this.color})
      : groupLabel = label,
        icon = null,
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
      backgroundColor: const Color(0xFFF2F3F5),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: C.bg,
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

    _AdminNavItem.group(label: '뜨개 자료', color: Color(0xFF4ADE80)),
    _AdminNavItem.tab(index: 1, icon: Icons.menu_book_rounded, label: '뜨개백과', color: Color(0xFF4ADE80)),
    _AdminNavItem.tab(index: 2, icon: Icons.grass_rounded, label: '실 브랜드', color: Color(0xFF4ADE80)),
    _AdminNavItem.tab(index: 3, icon: Icons.straighten_rounded, label: '바늘 브랜드', color: Color(0xFF4ADE80)),

    _AdminNavItem.group(label: '사용자 데이터', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 4, icon: Icons.people_rounded, label: '회원', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 5, icon: Icons.auto_fix_high_rounded, label: '도안목록', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 6, icon: Icons.palette_rounded, label: '스와치', color: Color(0xFFB47EEB)),
    _AdminNavItem.tab(index: 7, icon: Icons.folder_copy_rounded, label: '프로젝트', color: Color(0xFFB47EEB)),

    _AdminNavItem.group(label: '콘텐츠', color: Color(0xFFF472B6)),
    _AdminNavItem.tab(index: 8, icon: Icons.storefront_rounded, label: '마켓상품', color: Color(0xFFF472B6)),
    _AdminNavItem.tab(index: 9, icon: Icons.forum_rounded, label: '커뮤니티', color: Color(0xFFF472B6)),

    _AdminNavItem.group(label: '운영 지원', color: Color(0xFF94A3B8)),
    _AdminNavItem.tab(index: 10, icon: Icons.text_fields_rounded, label: '문구관리', color: Color(0xFF94A3B8)),
    _AdminNavItem.tab(index: 11, icon: Icons.bug_report_rounded, label: '버그리포트', color: Color(0xFFFB7185)),
    _AdminNavItem.tab(index: 12, icon: Icons.newspaper_rounded, label: '에디토리얼', color: Color(0xFF38BDF8)),
    _AdminNavItem.tab(index: 13, icon: Icons.settings_rounded, label: '설정', color: Color(0xFF94A3B8)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 어드민 탑바 ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: C.gx,
            border: Border(bottom: BorderSide(color: C.bd2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 로고 + 유틸 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                child: Row(
                  children: [
                    Image.asset('assets/login_logo.png', width: 26, height: 26, fit: BoxFit.contain),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MoriKnit', style: TextStyle(color: C.tx, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                        const Text('Admin Console', style: TextStyle(color: Color(0xFFB47EEB), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                      ],
                    ),
                    const Spacer(),
                    _AdminSidebarUtil(
                      icon: Icons.open_in_new_rounded,
                      label: '앱으로 가기',
                      onTap: () => launchUrl(Uri.parse('https://www.moriknit.com'), mode: LaunchMode.externalApplication),
                    ),
                    _AdminSidebarUtil(
                      icon: Icons.logout_rounded,
                      label: '로그아웃',
                      onTap: () => FirebaseAuth.instance.signOut(),
                    ),
                  ],
                ),
              ),
              // 탭 네비게이션 (가로 스크롤 — 그룹 2단 계층)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _buildGroupedNav(_navItems, _selectedIndex, (i) => setState(() => _selectedIndex = i)),
                ),
              ),
            ],
          ),
        ),
        // ── 콘텐츠 영역 ─────────────────────────────────────────────────────
        Expanded(child: _buildContent()),
      ],
    );
  }

  List<Widget> _buildGroupedNav(List<_AdminNavItem> items, int selectedIndex, void Function(int) onSelect) {
    final result = <Widget>[];
    // 현재 그룹 범위를 추적하며 그룹별 Column 빌드
    _AdminNavItem? currentGroup;
    List<_AdminNavItem> groupTabs = [];

    void flushGroup() {
      if (currentGroup == null && groupTabs.isEmpty) return;
      final color = currentGroup?.color ?? C.mu;
      final isGroupActive = groupTabs.any((t) => t.tabIndex == selectedIndex);
      result.add(
        Container(
          margin: const EdgeInsets.only(left: 4, right: 2),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color.withValues(alpha: 0.35), width: 2),
              bottom: BorderSide(color: isGroupActive ? color : Colors.transparent, width: 2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentGroup != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Text(
                    currentGroup!.groupLabel!.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: groupTabs.map((item) {
                  final isSelected = item.tabIndex == selectedIndex;
                  final accent = item.color;
                  return GestureDetector(
                    onTap: () => onSelect(item.tabIndex!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? accent.withValues(alpha: 0.14) : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 15, color: isSelected ? accent : C.mu),
                          const SizedBox(width: 5),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              color: isSelected ? accent : C.tx2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
      currentGroup = null;
      groupTabs = [];
    }

    for (final item in items) {
      if (item.isGroup) {
        flushGroup();
        currentGroup = item;
      } else {
        groupTabs.add(item);
      }
    }
    flushGroup();
    return result;
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:  return _DashboardTab(isKorean: widget.isKorean);
      case 1:  return _EncyclopediaTab(isKorean: widget.isKorean, adminUid: widget.user.uid);
      case 2:  return _BrandTab(collection: 'yarn_brands', title: '실 브랜드');
      case 3:  return _BrandTab(collection: 'needle_brands', title: '바늘 브랜드');
      case 4:  return _MembersTab(isKorean: widget.isKorean);
      case 5:  return _CollectionWithImportTab(collection: 'pattern_charts', title: '도안목록', importKind: AdminImportKind.pattern, isKorean: widget.isKorean, adminUid: widget.user.uid);
      case 6:  return const _AdminSwatchesTab();
      case 7:  return const _AdminProjectsTab();
      case 8:  return _CollectionWithImportTab(collection: 'market_items', title: '마켓상품', importKind: AdminImportKind.market, isKorean: widget.isKorean, adminUid: widget.user.uid);
      case 9:  return _CollectionWithImportTab(collection: 'posts', title: '커뮤니티', importKind: AdminImportKind.communityPost, isKorean: widget.isKorean, adminUid: widget.user.uid);
      case 10: return _CopyManagementTab(isKorean: widget.isKorean);
      case 11: return const _BugReportsTab();
      case 12: return const _EditorialAdminTab();
      case 13: return _SettingsTab(isKorean: widget.isKorean);
      default: return _DashboardTab(isKorean: widget.isKorean);
    }
  }
}


class _AdminSidebarUtil extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AdminSidebarUtil({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 15, color: C.tx2),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, color: C.tx2)),
          ],
        ),
      ),
    );
  }
}

class _AdminNotLoggedIn extends StatelessWidget {
  const _AdminNotLoggedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Image.asset('assets/login_logo.png', width: 64, height: 64, fit: BoxFit.contain)),
              const SizedBox(height: 16),
              const Text('모리니트 관리자페이지', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                '로그인 페이지에서 관리자 체크박스를 선택하고\n로그인해 주세요.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('로그인 페이지로 이동'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
              Text(title, style: T.h3, textAlign: TextAlign.center),
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

  const _CollectionDocRow({
    required this.doc,
    required this.collection,
    required this.isKorean,
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
                  ? Image.network(
                      imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _MarketThumbPlaceholder(),
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
        rowContent = Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(term, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(category, style: T.caption.copyWith(color: C.mu)),
                  ],
                  const SizedBox(height: 4),
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
                        child: Image.network(
                          imageUrlCtrl.text,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(),
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
                        style: TextStyle(fontSize: 13, color: C.tx),
                        items: categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 13, color: C.tx))))
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

  const _DashboardTab({required this.isKorean});

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
                _CountCard(label: isKorean ? '회원' : 'Users', value: '${data['users'] ?? 0}', accent: C.lvD),
                _CountCard(label: isKorean ? '마켓/도안' : 'Market', value: '${data['market'] ?? 0}', accent: C.pkD),
                _CountCard(label: isKorean ? '백과사전' : 'Encyclopedia', value: '${data['encyclopedia'] ?? 0}', accent: C.lmD),
                _CountCard(label: isKorean ? '커뮤니티 글' : 'Posts', value: '${data['posts'] ?? 0}', accent: C.og),
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
              Text(isKorean ? '운영 메모' : 'Ops note', style: T.h3),
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
        _OperationalSupportSection(isKorean: isKorean),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isKorean ? '빠른 이동' : 'Quick access', style: T.h3),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.bug_report_rounded, size: 16, color: C.og),
                    label: Text(isKorean ? '버그 리포트' : 'Bug reports', style: T.caption.copyWith(color: C.og)),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.text_fields_rounded, size: 16, color: C.lvD),
                    label: Text(isKorean ? '문구 관리' : 'Copy mgmt', style: T.caption.copyWith(color: C.lvD)),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.people_rounded, size: 16, color: C.lv),
                    label: Text(isKorean ? '회원 관리' : 'Members', style: T.caption.copyWith(color: C.lv)),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
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
              Text(isKorean ? '운영 지원 기능' : 'Operator support', style: T.h3),
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
                    Text(isKorean ? '검토 대기열' : 'Review queue', style: T.h3),
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
                    Text(isKorean ? '데이터 건강상태' : 'Data health', style: T.h3),
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

class _CountCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _CountCard({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 90,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: T.captionBold.copyWith(color: accent)),
          Text(value, style: T.h2.copyWith(color: accent)),
        ],
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
      children: [
        GlassCard(
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: widget.isKorean ? '이름이나 이메일로 검색' : 'Search by name or email',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: usersAsync.when(
            data: (users) {
              final filtered = users.where((user) {
                if (query.isEmpty) return true;
                return user.displayName.toLowerCase().contains(query) ||
                    user.email.toLowerCase().contains(query) ||
                    user.uid.toLowerCase().contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return GlassCard(
                  child: Center(
                    child: Text(
                      widget.isKorean ? '조건에 맞는 회원이 없습니다.' : 'No matching members found.',
                      style: T.body.copyWith(color: C.tx2),
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final user = filtered[index];
                  return _MemberRow(user: user, isKorean: widget.isKorean);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => GlassCard(child: Text(e.toString(), style: T.body.copyWith(color: C.og))),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends ConsumerWidget {
  final UserModel user;
  final bool isKorean;

  const _MemberRow({required this.user, required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = currentUid == user.uid;
    final created = user.createdAt == null ? '-' : DateFormat('yyyy-MM-dd').format(user.createdAt!);
    final isAdmin = ref.watch(_memberAdminFlagProvider(user.uid)).valueOrNull == true;
    final isBlocked = ref.watch(_memberBlockedFlagProvider(user.uid)).valueOrNull == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.bd),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: C.lvL,
            backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
            child: user.photoURL.isEmpty
                ? Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U',
                    style: TextStyle(color: C.lvD, fontWeight: FontWeight.bold, fontSize: 13),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          // 이름+이메일
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName.isEmpty ? user.email : user.displayName, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(user.email, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 가입일
          SizedBox(
            width: 90,
            child: Text(created, style: T.caption.copyWith(color: C.mu)),
          ),
          const SizedBox(width: 10),
          // 뱃지
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdmin) ...[
                MoriChip(label: isKorean ? '관리자' : 'Admin', type: ChipType.lavender),
                const SizedBox(width: 4),
              ],
              if (isBlocked)
                MoriChip(label: isKorean ? '차단' : 'Blocked', type: ChipType.orange),
            ],
          ),
          const Spacer(),
          // 세부정보 버튼
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: C.tx2),
            tooltip: isKorean ? '세부정보 편집' : 'Edit details',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _MemberDetailDialog(user: user, isKorean: isKorean, isSelf: isSelf),
            ),
          ),
          // 삭제 버튼
          if (!isSelf)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: C.og),
              tooltip: isKorean ? '회원 삭제' : 'Delete member',
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
                if (confirmed == true) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
                }
              },
            ),
        ],
      ),
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
                          onChanged: isSelf ? null : (value) async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .set({'isAdmin': value}, SetOptions(merge: true));
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
                style: const TextStyle(fontSize: 13),
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
              Text(widget.isKorean ? '대량등록 항목' : 'Import target', style: T.h3),
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
          Text(isKorean ? '미리보기' : 'Preview', style: T.h3),
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
          Text(isKorean ? '최근 반영 기록' : 'Recent import logs', style: T.h3),
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
      length: 3,
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
              Tab(text: isKorean ? '운영지원' : 'Support'),
              const Tab(text: 'GitHub'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _SocialSettingsTab(isKorean: isKorean),
                _SupportSettingsTab(isKorean: isKorean),
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
                  Text(widget.isKorean ? '소셜 계정 및 API 메모' : 'Social accounts and API notes', style: T.h3),
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
  final _backgroundCtrl = TextEditingController();
  bool _communityEnabled = true;
  bool _sellerEnabled = true;
  bool _encyclopediaEnabled = true;
  String _noticeType = 'banner';
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _noticeCtrl.dispose();
    _backgroundCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_supportConfigProvider);
    return async.when(
      data: (data) {
        if (!_loaded) {
          _noticeCtrl.text = data['maintenanceNotice']?.toString() ?? '';
          _backgroundCtrl.text = data['backgroundImageUrl']?.toString() ?? '';
          _communityEnabled = data['communityWriteEnabled'] != false;
          _sellerEnabled = data['sellerSubmissionEnabled'] != false;
          _encyclopediaEnabled = data['encyclopediaSuggestionEnabled'] != false;
          _noticeType = data['noticeType']?.toString() ?? 'banner';
          _loaded = true;
        }

        return ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.isKorean ? '운영지원 설정' : 'Operational support', style: T.h3),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noticeCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: widget.isKorean ? '공지 문구' : 'Notice'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(widget.isKorean ? '공지 유형' : 'Notice type',
                          style: T.caption.copyWith(color: C.tx2)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _noticeType,
                        isDense: true,
                        menuMaxHeight: 240,
                        style: TextStyle(fontSize: 13, color: C.tx),
                        items: [
                          DropdownMenuItem(value: 'banner', child: Text(widget.isKorean ? '배너' : 'Banner', style: TextStyle(fontSize: 13, color: C.tx))),
                          DropdownMenuItem(value: 'popup', child: Text(widget.isKorean ? '팝업' : 'Popup', style: TextStyle(fontSize: 13, color: C.tx))),
                          DropdownMenuItem(value: 'push', child: Text(widget.isKorean ? '푸시알림' : 'Push', style: TextStyle(fontSize: 13, color: C.tx))),
                        ],
                        onChanged: (v) => setState(() => _noticeType = v ?? _noticeType),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _communityEnabled,
                    onChanged: (value) => setState(() => _communityEnabled = value),
                    title: Text(widget.isKorean ? '커뮤니티 글쓰기 허용' : 'Enable community posting'),
                  ),
                  SwitchListTile(
                    value: _sellerEnabled,
                    onChanged: (value) => setState(() => _sellerEnabled = value),
                    title: Text(widget.isKorean ? '판매 등록 허용' : 'Enable seller submissions'),
                  ),
                  SwitchListTile(
                    value: _encyclopediaEnabled,
                    onChanged: (value) => setState(() => _encyclopediaEnabled = value),
                    title: Text(widget.isKorean ? '백과사전 제안 허용' : 'Enable encyclopedia suggestions'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _backgroundCtrl,
                    decoration: InputDecoration(
                      labelText: widget.isKorean ? '배경 이미지 URL' : 'Background image URL',
                      helperText: widget.isKorean
                          ? '지금은 저장만 합니다. 추후 앱 배경 커스터마이징과 연결될 예정입니다.'
                          : 'Stored now for future background customization.',
                    ),
                  ),
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
      await FirebaseFirestore.instance.collection('app_config').doc('admin_support').set(
        {
          'maintenanceNotice': _noticeCtrl.text.trim(),
          'noticeType': _noticeType,
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_bugReportsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (docs) {
        if (docs.isEmpty) {
          return const Center(child: Text('접수된 버그리포트가 없습니다.', style: TextStyle(color: Colors.grey)));
        }
        return Row(
          children: [
            // 목록
            SizedBox(
              width: 340,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: const Color(0xFFF5F5F5),
                    child: Row(
                      children: [
                        const Icon(Icons.bug_report_rounded, size: 18, color: Color(0xFF1A1A2E)),
                        const SizedBox(width: 8),
                        Text('버그리포트 (${docs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data();
                        final category = data['category'] as String? ?? 'other';
                        final issueNum = data['githubIssueNumber'] as int?;
                        final wantsReply = data['wantsReply'] as bool? ?? false;
                        final userTier = data['userTier'] as String? ?? 'free';
                        final isSelected = _selectedId == doc.id;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFFEEF2FF),
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: _categoryColors[category] ?? Colors.grey,
                            child: Text(category[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(data['title'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (userTier == 'premium') const Text('⭐', style: TextStyle(fontSize: 11)),
                              if (wantsReply) const Padding(padding: EdgeInsets.only(left: 2), child: Icon(Icons.mail_outline_rounded, size: 13, color: Color(0xFF1565C0))),
                            ],
                          ),
                          subtitle: Text(
                            issueNum != null ? '#$issueNum · ${data['userEmail'] ?? ''}' : data['userEmail'] as String? ?? '',
                            style: TextStyle(fontSize: 11, color: issueNum != null ? const Color(0xFF4CAF50) : Colors.grey),
                          ),
                          onTap: () => setState(() => _selectedId = isSelected ? null : doc.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            // 상세
            Expanded(
              child: () {
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
                }(),
            ),
          ],
        );
      },
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  child: Image.network(url, width: 120, height: 120, fit: BoxFit.cover),
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

final _adminAllSwatchesProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collectionGroup('swatches')
      .limit(500)
      .snapshots()
      .map((s) {
        final docs = s.docs;
        docs.sort((a, b) {
          final aTs = a.data()['createdAt'];
          final bTs = b.data()['createdAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });
        return docs;
      });
});

class _AdminSwatchesTab extends ConsumerStatefulWidget {
  const _AdminSwatchesTab();
  @override
  ConsumerState<_AdminSwatchesTab> createState() => _AdminSwatchesTabState();
}

class _AdminSwatchesTabState extends ConsumerState<_AdminSwatchesTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminAllSwatchesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.palette_rounded, size: 18, color: Color(0xFF1A1A2E)),
              const SizedBox(width: 8),
              async.when(
                data: (d) => Text('스와치 전체 (${d.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                loading: () => const Text('스와치 로딩 중...', style: TextStyle(fontSize: 14)),
                error: (e, _) => Text('오류: $e', style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '이름/브랜드 검색',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (docs) {
              final filtered = _search.isEmpty
                  ? docs
                  : docs.where((d) {
                      final data = d.data();
                      final name = (data['yarnBrandName'] ?? data['name'] ?? '').toString().toLowerCase();
                      return name.contains(_search);
                    }).toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('스와치가 없습니다.', style: TextStyle(color: Colors.grey)));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final doc = filtered[i];
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
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: swatchColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(brandName.isNotEmpty ? brandName : '(브랜드 없음)',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('UID: $ownerUid',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        if (colorHex.isNotEmpty)
                          Text(colorHex,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace')),
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

// ─── 어드민 프로젝트 탭 ────────────────────────────────────────────────────────

final _adminAllProjectsProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collectionGroup('projects')
      .limit(500)
      .snapshots()
      .map((s) {
        final docs = s.docs;
        docs.sort((a, b) {
          final aTs = a.data()['createdAt'];
          final bTs = b.data()['createdAt'];
          if (aTs == null || bTs == null) return 0;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminAllProjectsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.folder_copy_rounded, size: 18, color: Color(0xFF1A1A2E)),
              const SizedBox(width: 8),
              async.when(
                data: (d) => Text('프로젝트 전체 (${d.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                loading: () => const Text('프로젝트 로딩 중...', style: TextStyle(fontSize: 14)),
                error: (e, _) => Text('오류: $e', style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '제목 검색',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (docs) {
              final filtered = _search.isEmpty
                  ? docs
                  : docs.where((d) {
                      final title = (d.data()['title'] ?? '').toString().toLowerCase();
                      return title.contains(_search);
                    }).toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('프로젝트가 없습니다.', style: TextStyle(color: Colors.grey)));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final doc = filtered[i];
                  final data = doc.data();
                  final pathParts = doc.reference.path.split('/');
                  final ownerUid = pathParts.length >= 2 ? pathParts[1] : '';
                  final title = data['title'] as String? ?? '(제목 없음)';
                  final status = data['status'] as String? ?? 'planning';
                  final statusColor = _statusColors[status] ?? Colors.grey;
                  final statusLabel = _statusLabels[status] ?? status;
                  final createdAt = data['createdAt'];
                  String dateStr = '';
                  if (createdAt is Timestamp) {
                    dateStr = DateFormat('yyyy-MM-dd').format(createdAt.toDate());
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                          ),
                          child: Text(statusLabel,
                              style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text('UID: $ownerUid',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        if (dateStr.isNotEmpty)
                          Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
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

// ── 뜨개백과 탭 (개별 관리 + 일괄등록) ───────────────────────────────────────

class _EncyclopediaTab extends StatefulWidget {
  final bool isKorean;
  final String adminUid;
  const _EncyclopediaTab({required this.isKorean, required this.adminUid});

  @override
  State<_EncyclopediaTab> createState() => _EncyclopediaTabState();
}

class _EncyclopediaTabState extends State<_EncyclopediaTab> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF4ADE80).withValues(alpha: 0.3))),
          ),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: Color(0xFF4ADE80),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF4ADE80),
            tabs: const [
              Tab(text: '항목 목록 & 개별 관리'),
              Tab(text: '일괄등록'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _EncyclopediaItemsTab(isKorean: widget.isKorean),
              _CollectionWithImportTab(
                collection: 'encyclopedia',
                title: '뜨개백과',
                importKind: AdminImportKind.encyclopedia,
                isKorean: widget.isKorean,
                adminUid: widget.adminUid,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 뜨개백과 항목 목록 & 개별 관리 ────────────────────────────────────────────

class _EncyclopediaItemsTab extends StatefulWidget {
  final bool isKorean;
  const _EncyclopediaItemsTab({required this.isKorean});

  @override
  State<_EncyclopediaItemsTab> createState() => _EncyclopediaItemsTabState();
}

class _EncyclopediaItemsTabState extends State<_EncyclopediaItemsTab> {
  String _searchQuery = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance
        .collection('encyclopedia')
        .orderBy('term_ko')
        .limit(200)
        .get();
    if (mounted) {
      setState(() {
        _docs = snap.docs;
        _loading = false;
      });
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    if (_searchQuery.isEmpty) return _docs;
    final q = _searchQuery.toLowerCase();
    return _docs.where((d) {
      final term = (d.data()['term_ko'] as String? ?? '').toLowerCase();
      return term.contains(q);
    }).toList();
  }

  void _showEditDialog(BuildContext context, [Map<String, dynamic>? data, String? docId]) {
    final termKeyCtrl = TextEditingController(text: data?['term_key'] as String? ?? '');
    final termKoCtrl = TextEditingController(text: data?['term_ko'] as String? ?? '');
    final termEnCtrl = TextEditingController(text: data?['term_en'] as String? ?? '');
    final categoryCtrl = TextEditingController(text: data?['category_key'] as String? ?? '');
    final descKoCtrl = TextEditingController(text: data?['description_ko'] as String? ?? '');
    final descEnCtrl = TextEditingController(text: data?['description_en'] as String? ?? '');
    bool isPublic = data?['isPublic'] as bool? ?? true;
    final isNew = docId == null;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(isNew ? '새 항목 추가' : '항목 수정'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: termKeyCtrl, decoration: const InputDecoration(labelText: 'term_key (영문 키) *')),
                  const SizedBox(height: 8),
                  TextField(controller: termKoCtrl, decoration: const InputDecoration(labelText: 'term_ko (한글 용어) *')),
                  const SizedBox(height: 8),
                  TextField(controller: termEnCtrl, decoration: const InputDecoration(labelText: 'term_en (영문 용어)')),
                  const SizedBox(height: 8),
                  TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'category_key (카테고리)')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descKoCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'description_ko (한글 설명)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descEnCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'description_en (영문 설명)'),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('공개 (isPublic)'),
                    const Spacer(),
                    Switch(value: isPublic, onChanged: (v) => ss(() => isPublic = v)),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final key = termKeyCtrl.text.trim();
                final ko = termKoCtrl.text.trim();
                if (key.isEmpty || ko.isEmpty) return;
                final fields = {
                  'term_key': key,
                  'term_ko': ko,
                  'term_en': termEnCtrl.text.trim(),
                  'category_key': categoryCtrl.text.trim(),
                  'description_ko': descKoCtrl.text.trim(),
                  'description_en': descEnCtrl.text.trim(),
                  'isPublic': isPublic,
                };
                try {
                  await runWithMoriLoadingDialog<void>(
                    ctx,
                    message: widget.isKorean ? '저장하는 중입니다.' : 'Saving...',
                    subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
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
    ).whenComplete(() {
      termKeyCtrl.dispose(); termKoCtrl.dispose(); termEnCtrl.dispose();
      categoryCtrl.dispose(); descKoCtrl.dispose(); descEnCtrl.dispose();
    });
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
                    hintText: 'term_ko 검색',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _showEditDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ 새 항목'),
              ),
            ],
          ),
        ),
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
    final termKo = data['term_ko'] as String? ?? '(용어 없음)';
    final categoryKey = data['category_key'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(termKo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (categoryKey.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(categoryKey, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 16),
            onPressed: onEdit,
            tooltip: '수정',
          ),
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
                  child: const Text(
                    '+ 새 글',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 목록
        Expanded(
          child: postsAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
            error: (e, _) => Center(child: Text('$e', style: TextStyle(color: C.tx))),
            data: (posts) {
              final filtered = posts.where((p) => p.type == _selectedType).toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    '게시된 글이 없어요.',
                    style: TextStyle(color: C.mu, fontSize: 13),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final post = filtered[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.gx,
                      border: Border.all(color: C.bd2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (post.isPublished ? Colors.green : Colors.grey).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    post.isPublished ? '공개' : '비공개',
                                    style: TextStyle(
                                      color: post.isPublished ? Colors.green : Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (post.youtubeVideoId.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'YouTube',
                                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 6),
                              Text(post.title, style: TextStyle(color: C.tx, fontSize: 13, fontWeight: FontWeight.w600)),
                              if (post.content.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  post.content,
                                  style: TextStyle(color: C.mu, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (post.createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${post.createdAt!.year}.${post.createdAt!.month.toString().padLeft(2, '0')}.${post.createdAt!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: C.mu, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_rounded, color: C.lv, size: 18),
                              onPressed: () => _showEditDialog(context, post),
                              tooltip: '수정',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                              onPressed: () => _confirmDelete(context, post.id),
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
                if (existing == null) {
                  await repo.createPost(EditorialPost(
                    id: '',
                    type: editType,
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    youtubeVideoId: ytCtrl.text.trim(),
                    isPublished: isPublished,
                  ));
                } else {
                  await repo.updatePost(existing.id, {
                    'type': editType,
                    'title': titleCtrl.text.trim(),
                    'content': contentCtrl.text.trim(),
                    'youtubeVideoId': ytCtrl.text.trim(),
                    'isPublished': isPublished,
                  });
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

