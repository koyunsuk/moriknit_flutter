// 이슈 #815 — 어드민 모바일 사이드바 (Drawer 래퍼)
//
// 모바일/좁은 화면에서 어드민 콘솔의 사이드바를 Drawer 로 띄우기 위한
// 공통 위젯. admin_screen.dart 의 _AdminSidebar 와 동일한 그룹·탭 구조를
// 따르되, Drawer 컨텍스트에 맞춰 폭/배경/탭 동작을 조정합니다.
//
// 메인 세션에서 admin_screen.dart 에 LayoutBuilder 분기를 추가하여
// 좁은 폭(예: width < 720)일 때 이 위젯을 Drawer 로 노출하도록 통합합니다.
//
// 사용 예 (메인 세션 통합 시):
//   Scaffold(
//     drawer: AdminMobileSidebar(
//       navItems: navItems,
//       selectedIndex: _selectedIndex,
//       onSelect: (i) {
//         setState(() => _selectedIndex = i);
//         Navigator.of(context).pop(); // Drawer 닫기
//       },
//     ),
//     ...
//   )

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// 어드민 사이드바 네비게이션 아이템(외부 노출용).
///
/// `admin_screen.dart` 의 `_AdminNavItem` 은 private 이므로,
/// 모바일 통합 시 메인 세션이 본 모델로 매핑해서 넘겨주는 것을 권장합니다.
class AdminMobileNavItem {
  final String? groupLabel;
  final IconData? icon;
  final String label;
  final Color color;
  final int? tabIndex;

  const AdminMobileNavItem.tab({
    required int index,
    required this.icon,
    required this.label,
    required this.color,
  })  : groupLabel = null,
        tabIndex = index;

  const AdminMobileNavItem.group({
    required this.label,
    required this.color,
    IconData? groupIcon,
  })  : groupLabel = label,
        icon = groupIcon,
        tabIndex = null;

  bool get isGroup => groupLabel != null;
}

/// 모바일 폭에서 어드민 사이드바를 Drawer 로 띄우는 래퍼.
///
/// Drawer 자체를 반환하므로 `Scaffold(drawer: AdminMobileSidebar(...))`
/// 형태로 그대로 사용 가능합니다.
class AdminMobileSidebar extends StatefulWidget {
  final List<AdminMobileNavItem> navItems;
  final int selectedIndex;
  final User? user;

  /// 탭 선택 시 호출. 메인 세션에서는 setState 후 Drawer 를 닫는 형태로 사용.
  final ValueChanged<int> onSelect;

  const AdminMobileSidebar({
    super.key,
    required this.navItems,
    required this.selectedIndex,
    required this.onSelect,
    this.user,
  });

  @override
  State<AdminMobileSidebar> createState() => _AdminMobileSidebarState();
}

class _AdminMobileSidebarState extends State<AdminMobileSidebar> {
  // _AdminSidebar 와 동일 톤 (재사용성 확보)
  static const _bg = Color(0xFF1E293B);
  static const _divider = Color(0x33FFFFFF);
  static const _textDim = Color(0xFFCBD5E1);

  late Set<String> _expandedGroups;

  @override
  void initState() {
    super.initState();
    _expandedGroups = _getGroupOfTab(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant AdminMobileSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final group = _getGroupLabel(widget.selectedIndex);
      if (group != null && !_expandedGroups.contains(group)) {
        setState(() => _expandedGroups.add(group));
      }
    }
  }

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
    final user = widget.user;
    return Drawer(
      width: 280,
      backgroundColor: _bg,
      child: SafeArea(
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
                  Image.asset(
                    'assets/login_logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MoriKnit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Admin Console',
                        style: TextStyle(
                          color: Color(0xFF84CC16),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF334155),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user?.displayName ?? user?.email ?? '관리자',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '로그아웃',
                    icon: const Icon(Icons.logout_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            behavior: HitTestBehavior.opaque,
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
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: item.color,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 14,
                    color: item.color.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        if (currentGroup == null || currentGroupExpanded) {
          final isSelected = item.tabIndex == widget.selectedIndex;
          final accent = item.color;
          result.add(
            GestureDetector(
              onTap: () => widget.onSelect(item.tabIndex!),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.15)
                      : Colors.transparent,
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
                    Icon(item.icon,
                        size: 16, color: isSelected ? accent : _textDim),
                    const SizedBox(width: 10),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
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
