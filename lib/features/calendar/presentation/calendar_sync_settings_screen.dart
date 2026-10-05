import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../data/external_calendar_sync.dart';
import '../data/google_calendar_service.dart';
import '../data/outlook_calendar_service.dart';

class CalendarSyncSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSyncSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSyncSettingsScreen> createState() =>
      _CalendarSyncSettingsScreenState();
}

class _CalendarSyncSettingsScreenState
    extends ConsumerState<CalendarSyncSettingsScreen> {
  bool _gcalSyncing = false;
  bool _outlookSyncing = false;
  String? _lastResult;

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final gcal = ref.watch(googleCalendarServiceProvider);
    final outlookState = ref.watch(outlookCalendarServiceProvider);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isKorean ? '캘린더 연동 설정' : 'Calendar Sync', style: T.h3),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 구글 캘린더 ───────────────────────────────────────────
                MoriBlockShell(
                  label: isKorean ? 'Google 캘린더' : 'Google Calendar',
                  icon: Icons.calendar_today_rounded,
                  accent: C.og,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SyncServiceTile(
                        iconWidget: FaIcon(FontAwesomeIcons.google, color: C.og, size: 20),
                        iconColor: C.og,
                        title: isKorean ? 'Google 계정' : 'Google Account',
                        subtitle: gcal.isSignedIn
                            ? (gcal.userEmail ?? '')
                            : (isKorean ? '연결되지 않음' : 'Not connected'),
                        connected: gcal.isSignedIn,
                        onConnectTap: () => _connectGoogle(gcal, isKorean),
                        onDisconnectTap: () => _disconnectGoogle(gcal),
                      ),
                      if (gcal.isSignedIn) ...[
                        const SizedBox(height: 10),
                        _SyncButton(
                          label: isKorean ? '지금 동기화' : 'Sync Now',
                          loading: _gcalSyncing,
                          onTap: () => _syncGoogle(uid, isKorean),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 아웃룩 캘린더 ─────────────────────────────────────────
                MoriBlockShell(
                  label: isKorean ? 'Microsoft Outlook' : 'Microsoft Outlook',
                  icon: Icons.mail_outlined,
                  accent: C.lv,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SyncServiceTile(
                        iconWidget: Icon(Icons.window_rounded, color: C.lv, size: 22),
                        iconColor: C.lv,
                        title: isKorean ? 'Microsoft 계정' : 'Microsoft Account',
                        subtitle: outlookState.isLoggedIn
                            ? (outlookState.email ?? '')
                            : (isKorean ? '연결되지 않음' : 'Not connected'),
                        connected: outlookState.isLoggedIn,
                        onConnectTap: () =>
                            _connectOutlook(context, isKorean),
                        onDisconnectTap: () => _disconnectOutlook(isKorean),
                      ),
                      if (outlookState.isLoggedIn) ...[
                        const SizedBox(height: 10),
                        _SyncButton(
                          label: isKorean ? '지금 동기화' : 'Sync Now',
                          loading: _outlookSyncing,
                          onTap: () => _syncOutlook(isKorean),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── 마지막 동기화 결과 ────────────────────────────────────
                if (_lastResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.lv.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.lv.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: C.lv, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_lastResult!, style: T.caption)),
                      ],
                    ),
                  ),
                ],

                // ── 안내 ────────────────────────────────────────────────
                const SizedBox(height: 24),
                MoriBlockShell(
                  label: isKorean ? '동기화 안내' : 'Sync Info',
                  icon: Icons.info_outline_rounded,
                  accent: C.tx,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(isKorean
                          ? '모리니트 이벤트만 외부 캘린더에 동기화됩니다.'
                          : 'Only MoriKnit events are synced to external calendars.'),
                      _InfoRow(isKorean
                          ? '자동생성 이벤트(프로젝트/함뜨)는 동기화되지 않습니다.'
                          : 'Auto-generated events (project/KAL) are not synced.'),
                      _InfoRow(isKorean
                          ? '충돌 시 가장 최근 변경사항이 우선 적용됩니다.'
                          : 'On conflict, the most recent change takes priority.'),
                      _InfoRow(isKorean
                          ? 'Outlook 연동은 Azure AD 클라이언트 ID 등록이 필요합니다.'
                          : 'Outlook sync requires Azure AD client ID registration.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 구글 캘린더 액션 ───────────────────────────────────────────────────────

  Future<void> _connectGoogle(
      GoogleCalendarService gcal, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '구글 계정 연결 중...' : 'Connecting Google...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => gcal.signIn(),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '연결 실패: $e' : 'Failed: $e');
    }
  }

  Future<void> _disconnectGoogle(GoogleCalendarService gcal) async {
    await gcal.signOut();
    if (mounted) setState(() {});
  }

  Future<void> _syncGoogle(String uid, bool isKorean) async {
    if (uid.isEmpty) return;
    setState(() => _gcalSyncing = true);
    try {
      final result =
          await ref.read(externalCalendarSyncProvider).syncGoogleCalendar(uid);
      if (mounted) {
        setState(() {
          _lastResult = isKorean
              ? 'Google 동기화 완료 — 업로드 ${result.pushed}건, 다운로드 ${result.pulled}건'
              : 'Google sync done — pushed ${result.pushed}, pulled ${result.pulled}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) setState(() => _gcalSyncing = false);
    }
  }

  // ── 아웃룩 액션 ────────────────────────────────────────────────────────────

  Future<void> _connectOutlook(BuildContext ctx, bool isKorean) async {
    try {
      await runWithMoriLoadingDialog<void>(
        ctx,
        message: isKorean ? 'Microsoft 계정 연결 중...' : 'Connecting Microsoft...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
        task: () => ref
            .read(outlookCalendarServiceProvider.notifier)
            .signIn(),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '연결 실패: $e' : 'Failed: $e');
    }
  }

  Future<void> _disconnectOutlook(bool isKorean) async {
    await ref.read(outlookCalendarServiceProvider.notifier).signOut();
    if (mounted) setState(() {});
  }

  Future<void> _syncOutlook(bool isKorean) async {
    setState(() => _outlookSyncing = true);
    try {
      // Outlook 동기화는 향후 externalCalendarSync에 통합 예정
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _lastResult = isKorean
              ? 'Outlook 동기화 준비 완료 (Azure AD 클라이언트 ID 등록 필요)'
              : 'Outlook sync ready (Azure AD client ID registration required)';
        });
      }
    } finally {
      if (mounted) setState(() => _outlookSyncing = false);
    }
  }
}

// ── 보조 위젯 ──────────────────────────────────────────────────────────────

class _SyncServiceTile extends StatelessWidget {
  final Widget iconWidget;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool connected;
  final VoidCallback onConnectTap;
  final VoidCallback onDisconnectTap;

  const _SyncServiceTile({
    required this.iconWidget,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.onConnectTap,
    required this.onDisconnectTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: iconWidget,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.bodyBold),
              Text(subtitle,
                  style: T.caption.copyWith(
                      color: connected ? C.lv : C.tx.withValues(alpha: 0.5))),
            ],
          ),
        ),
        connected
            ? TextButton(
                onPressed: onDisconnectTap,
                child: Text('연결 해제',
                    style: T.caption.copyWith(color: C.og)),
              )
            : ElevatedButton(
                onPressed: onConnectTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: T.caption,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('연결'),
              ),
      ],
    );
  }
}

class _SyncButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _SyncButton(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.sync_rounded, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: C.lv,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;
  const _InfoRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: C.tx.withValues(alpha: 0.4), shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: T.caption
                      .copyWith(color: C.tx.withValues(alpha: 0.75)))),
        ],
      ),
    );
  }
}
