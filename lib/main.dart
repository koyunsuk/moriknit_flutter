import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'core/constants/subscription_constants.dart';
import 'core/localization/app_language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'features/ravelry/data/ravelry_auth_provider.dart';
import 'providers/theme_provider.dart';


void main() async {
  if (kIsWeb) usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(SubscriptionConstants.boxSwatches),
      Hive.openBox<Map>(SubscriptionConstants.boxProjects),
      Hive.openBox<Map>(SubscriptionConstants.boxCounters),
      Hive.openBox<Map>(SubscriptionConstants.boxNeedles),
      Hive.openBox<Map>(SubscriptionConstants.boxSyncQueue),
      Hive.openBox<Map>(SubscriptionConstants.boxUser),
    ]);
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    kakao.KakaoSdk.init(nativeAppKey: 'de107e8c3aa2ecdb5271c1a48a7da0d7');
  }

  runApp(
    const ProviderScope(
      child: MoriKnitApp(),
    ),
  );
}

class MoriKnitApp extends ConsumerWidget {
  const MoriKnitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = resolveSupportedLocale(ref.watch(appLocaleProvider));
    final themeMode = ref.watch(appThemeProvider);
    C.apply(themeMode);

    return MaterialApp.router(
      key: ValueKey(themeMode),
      title: 'MoriKnit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      routerConfig: router,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        return resolveSupportedLocale(deviceLocale);
      },
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return _OAuthLinkListener(child: child);
      },
    );
  }
}

class _OAuthLinkListener extends ConsumerStatefulWidget {
  const _OAuthLinkListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_OAuthLinkListener> createState() => _OAuthLinkListenerState();
}

class _OAuthLinkListenerState extends ConsumerState<_OAuthLinkListener>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('moriknit/deeplink');
  bool _handledInitialUri = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _channel.setMethodCallHandler(_handleMethodCall);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _handleInitialUri();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 포그라운드 복귀 시 Ravelry 세션 재검증 — 토큰 만료 조기 감지
      ref.read(ravelryAuthProvider.notifier).refreshSession();
    }
  }

  Future<void> _handleInitialUri() async {
    if (_handledInitialUri) return;
    _handledInitialUri = true;
    try {
      final uriString = await _channel.invokeMethod<String>('getInitialLink');
      if (uriString != null && uriString.isNotEmpty) {
        _handleUri(Uri.parse(uriString));
      }
    } catch (error) {
      debugPrint('Ravelry initial link error: $error');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onLink' && call.arguments is String) {
      final uriString = call.arguments as String;
      if (uriString.isNotEmpty) {
        _handleUri(Uri.parse(uriString));
      }
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('Received deep link: $uri');
    if (uri.scheme == 'com.moriknit.app' &&
        uri.host == 'oauth-callback' &&
        uri.path == '/ravelry') {
      ref.read(ravelryAuthProvider.notifier).handleOAuthCallback(uri);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
