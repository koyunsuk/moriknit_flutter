import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _orbitController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250));
    _orbitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    _fade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack));
    _lift = Tween<double>(begin: 16, end: 0).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic));
    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [C.bg, Color(0xFFF6E7FF), Color(0xFFFDEFF6)],
          ),
        ),
        child: Stack(
          children: [
            const BgOrbs(),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _orbitController,
                  builder: (context, child) {
                    final t = _orbitController.value;
                    return Stack(
                      children: [
                        _OrbitIcon(left: 38, top: 178 + (t * 18), icon: Icons.content_cut_rounded, color: C.pkD, angle: t * 6.28),
                        _OrbitIcon(right: 42, top: 204 - (t * 14), icon: Icons.grid_view_rounded, color: C.lvD, angle: t * -5.2),
                        _OrbitIcon(left: 66, bottom: 168 - (t * 10), icon: Icons.checkroom_rounded, color: C.lmD, angle: t * 4.6),
                        _OrbitIcon(right: 60, bottom: 198 + (t * 12), icon: Icons.auto_awesome_rounded, color: C.pk, angle: t * -4.3),
                      ],
                    );
                  },
                ),
              ),
            ),
            FadeTransition(
              opacity: _fade,
              child: AnimatedBuilder(
                animation: _lift,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _lift.value),
                    child: ScaleTransition(
                      scale: _scale,
                      child: child,
                    ),
                  );
                },
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoriLogo(size: 214),
                          const SizedBox(height: 18),
                          const MoriKnitTitle(fontSize: 42),
                          const SizedBox(height: 10),
                          Text('뜨개 기록 앱', style: T.h3.copyWith(color: C.pkD), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('스와치 · 프로젝트 · 카운터를 한 곳에서 기록하세요', style: T.body.copyWith(color: C.tx2), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          Text('MoriKnit.com', style: T.captionBold.copyWith(color: C.lvD, letterSpacing: 0.5)),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              _LoadingDot(color: C.pkD, delay: 0),
                              SizedBox(width: 8),
                              _LoadingDot(color: C.lvD, delay: 120),
                              SizedBox(width: 8),
                              _LoadingDot(color: C.lmD, delay: 240),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitIcon extends StatelessWidget {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final IconData icon;
  final Color color;
  final double angle;

  const _OrbitIcon({this.left, this.right, this.top, this.bottom, required this.icon, required this.color, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.16)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

class _LoadingDot extends StatefulWidget {
  final Color color;
  final int delay;
  const _LoadingDot({required this.color, required this.delay});

  @override
  State<_LoadingDot> createState() => _LoadingDotState();
}

class _LoadingDotState extends State<_LoadingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 820));
    _scale = Tween<double>(begin: 0.72, end: 1.08).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}
