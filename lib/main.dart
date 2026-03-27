import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/subscription_constants.dart';
import 'core/localization/app_language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Future.wait([
    Hive.openBox<Map>(SubscriptionConstants.boxSwatches),
    Hive.openBox<Map>(SubscriptionConstants.boxProjects),
    Hive.openBox<Map>(SubscriptionConstants.boxCounters),
    Hive.openBox<Map>(SubscriptionConstants.boxNeedles),
    Hive.openBox<Map>(SubscriptionConstants.boxSyncQueue),
    Hive.openBox<Map>(SubscriptionConstants.boxUser),
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

    return MaterialApp.router(
      title: 'MoriKnit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
    );
  }
}
