import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/sync/network_status.dart';

/// 버그리포트 자동 수집 메타데이터 (#778).
///
/// 시트 열린 시점의 환경 정보를 한 번에 캡처해 GitHub 이슈/Firestore에 적재.
class BugMetadata {
  final String deviceInfo;
  final String osVersion;
  final String platform; // 'android' | 'ios' | 'web' | 'other'
  final String appVersion;
  final String screenSize; // "412x915"
  final String currentRoute; // "/swatch/abc123"
  final String currentScreenName; // "swatch"
  final String localeName; // "ko_KR" / "en_US"
  final String isOnline; // "true" | "false" | "" (unknown)
  final String viewportInsets; // "top:24 bottom:0"

  const BugMetadata({
    required this.deviceInfo,
    required this.osVersion,
    required this.platform,
    required this.appVersion,
    required this.screenSize,
    required this.currentRoute,
    required this.currentScreenName,
    required this.localeName,
    required this.isOnline,
    required this.viewportInsets,
  });
}

/// context 의존 sync 정보만 즉시 수집. platform channel 호출 없음.
///
/// #822 — sheet 닫기 전 동기 호출용. ANR 방지 (메인스레드 점유 없음).
({String screenSize, String viewportInsets, String currentRoute, String currentScreenName, String localeName, String isOnline})
    collectBugMetadataSync(BuildContext context, WidgetRef ref) {
  String screenSize = '';
  String viewportInsets = '';
  try {
    final media = MediaQuery.of(context);
    screenSize = '${media.size.width.round()}x${media.size.height.round()}';
    viewportInsets = 'top:${media.padding.top.round()} bottom:${media.padding.bottom.round()}';
  } catch (_) {}

  final route = _getCurrentRoute(context);
  final screenName = _routeToScreenName(route);
  final localeName = _getLocaleName(context, ref);

  String isOnline = '';
  try {
    final svc = ref.read(networkStatusServiceProvider);
    switch (svc.current) {
      case NetworkStatus.online:
        isOnline = 'true';
        break;
      case NetworkStatus.offline:
        isOnline = 'false';
        break;
      case NetworkStatus.unknown:
        isOnline = '';
        break;
    }
  } catch (_) {}

  return (
    screenSize: screenSize,
    viewportInsets: viewportInsets,
    currentRoute: route,
    currentScreenName: screenName,
    localeName: localeName,
    isOnline: isOnline,
  );
}

/// platform channel 의존 정보만 비동기 수집. sheet 닫힌 후 백그라운드 호출용.
///
/// #822 — DeviceInfoPlugin / PackageInfo 호출. cold start 1-3초 가능 → 메인스레드 무관해야 함.
Future<({String deviceInfo, String osVersion, String platform, String appVersion})>
    collectBugMetadataAsync() async {
  final sys = await _getSystemInfo();
  final appVersion = await _getAppVersion();
  return (
    deviceInfo: sys.deviceInfo,
    osVersion: sys.osVersion,
    platform: sys.platform,
    appVersion: appVersion,
  );
}

/// 시트 열린 시점의 모든 메타데이터를 수집해 [BugMetadata]로 반환.
///
/// BuildContext 의존 정보는 async 진입 전에 모두 캡처하여
/// async gap 동안 context 무효화 위험을 회피한다.
///
/// ⚠️ 이 함수는 platform channel 호출 (DeviceInfoPlugin/PackageInfo) 을 포함하므로
/// 메인스레드에서 await 시 ANR 위험. 가급적 sync/async 분리 함수 사용 권장.
Future<BugMetadata> collectBugMetadata(
  BuildContext context,
  WidgetRef ref,
) async {
  // ── 동기 캡처 (context 사용 가능한 시점에서 즉시 수집) ──
  String screenSize = '';
  String viewportInsets = '';
  try {
    final media = MediaQuery.of(context);
    final size = media.size;
    screenSize = '${size.width.round()}x${size.height.round()}';
    final pad = media.padding;
    viewportInsets = 'top:${pad.top.round()} bottom:${pad.bottom.round()}';
  } catch (e) {
    debugPrint('[BugMetadata] MediaQuery 수집 실패: $e');
  }

  final route = _getCurrentRoute(context);
  final screenName = _routeToScreenName(route);
  final localeName = _getLocaleName(context, ref);

  String isOnline = '';
  try {
    final svc = ref.read(networkStatusServiceProvider);
    switch (svc.current) {
      case NetworkStatus.online:
        isOnline = 'true';
        break;
      case NetworkStatus.offline:
        isOnline = 'false';
        break;
      case NetworkStatus.unknown:
        isOnline = '';
        break;
    }
  } catch (e) {
    debugPrint('[BugMetadata] 네트워크 상태 수집 실패: $e');
  }

  // ── 비동기 캡처 (context와 무관) ──
  final sys = await _getSystemInfo();
  final appVersion = await _getAppVersion();

  return BugMetadata(
    deviceInfo: sys.deviceInfo,
    osVersion: sys.osVersion,
    platform: sys.platform,
    appVersion: appVersion,
    screenSize: screenSize,
    currentRoute: route,
    currentScreenName: screenName,
    localeName: localeName,
    isOnline: isOnline,
    viewportInsets: viewportInsets,
  );
}

Future<({String deviceInfo, String osVersion, String platform})>
    _getSystemInfo() async {
  try {
    final plugin = DeviceInfoPlugin();
    if (kIsWeb) {
      final info = await plugin.webBrowserInfo;
      final ua = info.userAgent ?? '';
      String osVersion = info.platform ?? '';
      if (ua.contains('Windows')) {
        osVersion = 'Windows';
      } else if (ua.contains('Mac OS X')) {
        osVersion = 'macOS';
      } else if (ua.contains('Android')) {
        osVersion = 'Android (웹)';
      } else if (ua.contains('iPhone') || ua.contains('iPad')) {
        osVersion = 'iOS (웹)';
      } else if (ua.contains('Linux')) {
        osVersion = 'Linux';
      }
      final browser = ua.contains('Chrome')
          ? 'Chrome'
          : ua.contains('Firefox')
              ? 'Firefox'
              : ua.contains('Safari')
                  ? 'Safari'
                  : 'Browser';
      return (deviceInfo: browser, osVersion: osVersion, platform: 'web');
    }
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return (
        deviceInfo: '${info.manufacturer} ${info.model}',
        osVersion:
            'Android ${info.version.release} (SDK ${info.version.sdkInt})',
        platform: 'android',
      );
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return (
        deviceInfo: '${info.name} (${info.model})',
        osVersion: '${info.systemName} ${info.systemVersion}',
        platform: 'ios',
      );
    }
    return (deviceInfo: 'Unknown', osVersion: '', platform: 'other');
  } catch (e) {
    debugPrint('[BugMetadata] 시스템 정보 수집 실패: $e');
    return (deviceInfo: 'Unknown', osVersion: '', platform: 'other');
  }
}

Future<String> _getAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  } catch (_) {
    return '1.0.0';
  }
}

String _getCurrentRoute(BuildContext context) {
  // 1순위: GoRouterState.of(context) (라우트 컨텍스트 안에서 동작)
  try {
    return GoRouterState.of(context).matchedLocation;
  } catch (_) {
    // 시트는 root navigator 위에서 떠 있어 GoRouterState가 비어있을 수 있음
  }
  // 2순위: routerDelegate 통해 현재 라우트
  try {
    final router = GoRouter.of(context);
    final cfg = router.routerDelegate.currentConfiguration;
    return cfg.uri.path;
  } catch (e) {
    debugPrint('[BugMetadata] 라우트 수집 실패: $e');
    return '';
  }
}

String _routeToScreenName(String route) {
  if (route.isEmpty || route == '/') return 'home';
  final segments = route
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) return 'home';
  // 마지막 segment가 ID/숫자로 보이면 그 앞 segment 사용
  final last = segments.last;
  final looksLikeId = last.length >= 12 ||
      RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(last);
  if (looksLikeId && segments.length >= 2) {
    return segments[segments.length - 2];
  }
  return last;
}

String _getLocaleName(BuildContext context, WidgetRef ref) {
  // 앱 설정 언어 우선
  try {
    final appLang = ref.read(appLanguageProvider);
    final base = appLang.isKorean ? 'ko' : 'en';
    // 국가 코드는 시스템 로케일에서 시도
    try {
      final sys = Localizations.localeOf(context);
      final country = sys.countryCode;
      if (country != null && country.isNotEmpty) {
        return '${base}_$country';
      }
    } catch (_) {}
    return base == 'ko' ? 'ko_KR' : 'en_US';
  } catch (_) {
    return '';
  }
}
