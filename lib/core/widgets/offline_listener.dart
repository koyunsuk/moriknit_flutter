// 이슈 #704 Phase 5 — 오프라인/온라인 전환 SnackBar 리스너.
//
// MainShell에 1회 wrap 되어 전역적으로 네트워크 상태 변화를 감지.
// 상태 변화 발생 시 SnackBar 1회만 표시 (중복 방지).
//
// 표시 규칙:
// - online → offline: "인터넷 연결이 끊어졌습니다. 연결되면 자동으로 동기화됩니다."
// - offline → online: "연결이 복구되었습니다. {N}개 항목을 동기화 중입니다." (pending > 0일 때)
// - offline → online: "연결이 복구되었습니다." (pending == 0)
// - 시동 시 첫 결정이 offline → 안내 다이얼로그 표시 (PostFrame).
//
// 초기 로드(unknown → online/offline) 시에는 SnackBar 표시하지 않음.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_language.dart';
import '../sync/network_status.dart';
import '../sync/sync_queue.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 네트워크 상태 전환 시 SnackBar를 자동 표시하는 전역 리스너.
/// 자식 위젯은 그대로 렌더링.
class OfflineListener extends ConsumerStatefulWidget {
  const OfflineListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineListener> createState() => _OfflineListenerState();
}

class _OfflineListenerState extends ConsumerState<OfflineListener> {
  NetworkStatus? _prev;
  bool _startupDialogShown = false;

  Future<void> _showStartupOfflineDialog() async {
    if (_startupDialogShown) return;
    _startupDialogShown = true;
    if (!mounted) return;
    final isKorean = ref.read(appLanguageProvider).isKorean;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.signal_wifi_off_rounded, color: C.og, size: 22),
            const SizedBox(width: 8),
            Text(isKorean ? '오프라인 모드' : 'Offline Mode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKorean
                  ? '인터넷에 연결되어 있지 않습니다.'
                  : 'No internet connection.',
              style: T.body,
            ),
            const SizedBox(height: 12),
            _OfflineBullet(
              icon: Icons.menu_book_rounded,
              color: C.lv,
              text: isKorean
                  ? '저장된 도안은 볼 수 있습니다'
                  : 'Saved patterns are available',
            ),
            const SizedBox(height: 6),
            _OfflineBullet(
              icon: Icons.exposure_plus_1_rounded,
              color: C.lvD,
              text: isKorean
                  ? '카운터·타이머도 그대로 작동합니다'
                  : 'Counters & timers still work',
            ),
            const SizedBox(height: 6),
            _OfflineBullet(
              icon: Icons.people_alt_rounded,
              color: C.mu,
              text: isKorean
                  ? '커뮤니티·마켓은 사용할 수 없습니다'
                  : 'Community & Market are unavailable',
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isKorean ? '확인' : 'OK'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _openWifiSettings();
            },
            icon: const Icon(Icons.wifi_rounded, size: 18),
            label: Text(isKorean ? '인터넷 확인하기' : 'Check Internet'),
          ),
        ],
      ),
    );
  }

  /// 안드로이드 WiFi 설정 화면 열기 (intent). iOS는 일반 설정.
  Future<void> _openWifiSettings() async {
    if (kIsWeb) return;
    try {
      const platform = MethodChannel('flutter/platform');
      // Android intent for WiFi settings via system channels
      await platform.invokeMethod('SystemNavigator.openWifiSettings');
    } catch (_) {
      // 폴백: 무음. 사용자가 직접 설정으로 이동 필요.
    }
  }

  @override
  Widget build(BuildContext context) {
    // networkStatusProvider 변화 구독 — listen 사용해 빌드 없이 사이드이펙트만 실행.
    ref.listen<AsyncValue<NetworkStatus>>(networkStatusProvider, (previous, next) {
      final status = next.asData?.value;
      if (status == null || status == NetworkStatus.unknown) return;

      // 동일 상태로 재emit이면 무시.
      if (_prev == status) return;

      final hadPrev = _prev != null && _prev != NetworkStatus.unknown;
      _prev = status;

      // 이슈 #704 — 첫 결정이 offline이면 시동 안내 다이얼로그 표시 (PostFrame 보장).
      if (!hadPrev && status == NetworkStatus.offline) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showStartupOfflineDialog());
        return;
      }
      // 첫 결정이 online이면 알림 표시 X (기존 동작).
      if (!hadPrev) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      final isKorean = ref.read(appLanguageProvider).isKorean;

      if (status == NetworkStatus.offline) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                isKorean
                    ? '인터넷 연결이 끊어졌습니다. 연결되면 자동으로 동기화됩니다.'
                    : 'No internet. Changes will sync automatically when connected.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
      } else if (status == NetworkStatus.online) {
        final pending = ref.read(syncQueueProvider).sizeSync();
        final message = pending > 0
            ? (isKorean
                ? '연결이 복구되었습니다. $pending개 항목을 동기화 중입니다.'
                : 'Back online. Syncing $pending item(s)…')
            : (isKorean ? '연결이 복구되었습니다.' : 'Back online.');
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
      }
    });

    return widget.child;
  }
}

class _OfflineBullet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _OfflineBullet({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: T.caption.copyWith(color: C.tx))),
      ],
    );
  }
}
