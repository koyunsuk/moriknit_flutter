import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _progressController;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    // 웹에서는 스플래시 없이 바로 이동
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
      return;
    }

    _fadeController.forward();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _progressController.forward();
    });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _navigate();
    });
  }

  void _navigate() {
    final isLoggedIn = ref.read(authRepositoryProvider).currentUser != null;
    context.go(isLoggedIn ? Routes.home : (kIsWeb ? Routes.landing : Routes.login));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: AnimatedBuilder(
            animation: _slideUp,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _slideUp.value),
              child: child,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 모냥이 이미지
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Image.asset(
                      'assets/splash_cat.png',
                      width: 260,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 프로그레스바 (고양이 바로 아래)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _progressController.value,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFF0F0F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFADC62E)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // MoriKnit 타이틀
                  const Text(
                    'MoriKnit',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 슬로건
                  const Text(
                    '모냥이와 함께 뜨개힐링',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFB8B8B8),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // URL
                  const Text(
                    'www.moriknit.com',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFCCCCCC),
                      letterSpacing: 0.8,
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
