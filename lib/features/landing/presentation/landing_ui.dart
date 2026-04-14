import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

const double landingMaxWidth = 1160;

class LandingBackdrop extends StatelessWidget {
  const LandingBackdrop({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFFCFE),
            C.pk.withValues(alpha: 0.05),
            C.lv.withValues(alpha: 0.04),
            const Color(0xFFF8FBFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: landingMaxWidth),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class LandingHeroPanel extends StatelessWidget {
  const LandingHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions,
    this.footer,
    this.centered = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget>? actions;
  final Widget? footer;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            const Color(0xFFFFF5FB),
            const Color(0xFFF5F8FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: C.lv.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: C.lv.withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -8,
            child: _LandingGlow(
              size: 156,
              color: C.pk.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -18,
            child: _LandingGlow(
              size: 180,
              color: C.lv.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: [
                LandingSoftChip(
                  label: eyebrow,
                  dense: true,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1.16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1B4B),
                    letterSpacing: -0.8,
                  ),
                  textAlign: textAlign,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: centered ? 780 : 720,
                  ),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.75,
                      color: Color(0xFF5F4E99),
                    ),
                    textAlign: textAlign,
                  ),
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment:
                        centered ? WrapAlignment.center : WrapAlignment.start,
                    children: actions!,
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 24),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LandingSectionCard extends StatelessWidget {
  const LandingSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: C.lv.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: C.lv.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class LandingSoftChip extends StatelessWidget {
  const LandingSoftChip({
    super.key,
    required this.label,
    this.icon,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 12 : 14,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 14 : 16, color: C.lv),
            SizedBox(width: dense ? 6 : 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: C.lvD,
              fontSize: dense ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingGlow extends StatelessWidget {
  const _LandingGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
