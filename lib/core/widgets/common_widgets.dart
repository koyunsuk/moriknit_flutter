import 'package:flutter/material.dart';

export 'save_feedback.dart';

import 'package:hive/hive.dart';
import 'package:go_router/go_router.dart';

import '../../providers/avatar_provider.dart';
import '../localization/app_strings.dart';
import '../localization/strings/app_strings_en.dart';
import '../localization/strings/app_strings_ko.dart';
import '../constants/subscription_constants.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.color,
    this.borderColor,
    this.radius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? const Color(0xFF1E293B) : null);
    final effectiveBorder = borderColor ?? (isDark ? const Color(0xFF334155) : C.bd);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: effectiveBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x40000000) : const Color(0x2A6D4AFF),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
            const BoxShadow(
              color: Color(0x14FFFFFF),
              blurRadius: 2,
              offset: Offset(0, -1),
            ),
          ],
          gradient: effectiveColor == null
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF9FFFFFF), Color(0xF2FFF7FD)],
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}

enum ChipType { pink, lavender, lime, orange, white }

class MoriChip extends StatelessWidget {
  final String label;
  final ChipType type;
  final VoidCallback? onTap;

  const MoriChip({super.key, required this.label, this.type = ChipType.lavender, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = {
      ChipType.pink: (C.pk.withValues(alpha: 0.13), C.pkD, C.pk.withValues(alpha: 0.2)),
      ChipType.lavender: (C.lv.withValues(alpha: 0.13), C.lvD, C.lv.withValues(alpha: 0.2)),
      ChipType.lime: (C.lm.withValues(alpha: 0.11), C.lmD, C.lm.withValues(alpha: 0.22)),
      ChipType.orange: (C.og.withValues(alpha: 0.12), const Color(0xFFC2410C), C.og.withValues(alpha: 0.22)),
      ChipType.white: (Colors.white.withValues(alpha: 0.82), C.tx2, C.bd),
    };
    final (bg, tc, border) = colors[type]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 1))],
        ),
        child: Text(label, style: T.chip.copyWith(color: tc)),
      ),
    );
  }
}

class LimitBar extends StatelessWidget {
  final String label;
  final int current;
  final int max;
  final bool isReached;
  final VoidCallback? onUpgrade;

  const LimitBar({super.key, required this.label, required this.current, required this.max, required this.isReached, this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final progress = max == 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: isReached
          ? C.limitBar
          : BoxDecoration(
              color: C.tint(C.lv, 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd2),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$label  $current / $max', style: T.captionBold.copyWith(color: isReached ? C.og : C.mu)),
                    if (isReached) Text('Limit reached', style: T.captionBold.copyWith(color: C.og)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: C.bd2,
                    valueColor: AlwaysStoppedAnimation(isReached ? C.og : C.lv),
                  ),
                ),
              ],
            ),
          ),
          if (isReached && onUpgrade != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: C.lm, borderRadius: BorderRadius.circular(20)),
                child: Text('Upgrade', style: T.captionBold.copyWith(color: const Color(0xFF1a3000))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MoriTabDestination {
  final IconData icon;
  final String label;
  final Color accent;
  final String? avatarUrl;
  final String? avatarInitial;
  final DefaultAvatarPreset? avatarPreset;
  final int badgeCount;
  const MoriTabDestination(this.icon, this.label, this.accent, {this.avatarUrl, this.avatarInitial, this.avatarPreset, this.badgeCount = 0});
}

class MoriTabBar extends StatelessWidget {
  final int currentIndex;
  final List<MoriTabDestination> tabs;
  final ValueChanged<int> onTap;

  const MoriTabBar({super.key, required this.currentIndex, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: C.tabBarDeco,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) {
          final isOn = i == currentIndex;
          final tab = tabs[i];
          final accent = tab.accent;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.fromLTRB(2, isOn ? 0 : 4, 2, isOn ? 4 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: isOn ? accent.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: isOn ? Border.all(color: accent.withValues(alpha: 0.28)) : null,
                  boxShadow: isOn ? [BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 16, offset: const Offset(0, 8))] : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabBadge(tab: tab, accent: accent, isOn: isOn),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: (isOn ? T.tabOn : T.tabOff).copyWith(color: isOn ? accent : C.tx2),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  final MoriTabDestination tab;
  final Color accent;
  final bool isOn;
  const _TabBadge({required this.tab, required this.accent, required this.isOn});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (tab.avatarUrl != null && tab.avatarUrl!.isNotEmpty) || (tab.avatarInitial != null && tab.avatarInitial!.isNotEmpty);
    final iconWidget = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isOn ? accent.withValues(alpha: 0.18) : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: hasAvatar ? _ProfileBadge(url: tab.avatarUrl, initial: tab.avatarInitial, accent: accent, isOn: isOn, preset: tab.avatarPreset) : Icon(tab.icon, size: 18, color: accent),
    );

    if (tab.badgeCount <= 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              tab.badgeCount > 99 ? '99+' : '${tab.badgeCount}',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final String? url;
  final String? initial;
  final Color accent;
  final bool isOn;
  final DefaultAvatarPreset? preset;
  const _ProfileBadge({this.url, this.initial, required this.accent, required this.isOn, this.preset});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Center(
      child: MoriDefaultAvatar(
        size: 24,
        backgroundColor: Colors.white.withValues(alpha: isOn ? 0.92 : 0.82),
        borderRadius: 8,
        preset: preset,
      ),
    );
  }
}

class MoriDefaultAvatar extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final double borderRadius;
  final DefaultAvatarPreset? preset;

  const MoriDefaultAvatar({
    super.key,
    this.size = 40,
    this.backgroundColor,
    this.borderRadius = 999,
    this.preset,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPreset = preset ?? _readPreset();
    final (bg, accent) = _scheme(resolvedPreset);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(accent.withValues(alpha: 0.20), BlendMode.srcATop),
        child: Image.asset('assets/splash_cat.png', fit: BoxFit.contain),
      ),
    );
  }

  DefaultAvatarPreset _readPreset() {
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final raw = box.get('settings');
      final saved = raw == null ? null : raw['avatar_preset'] as String?;
      return DefaultAvatarPreset.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => DefaultAvatarPreset.moyangi,
      );
    } catch (_) {
      return DefaultAvatarPreset.moyangi;
    }
  }

  (Color, Color) _scheme(DefaultAvatarPreset preset) {
    switch (preset) {
      case DefaultAvatarPreset.moyangi:
        return (const Color(0xFFFFF1F6), const Color(0xFFD94F7D));
      case DefaultAvatarPreset.dalgomi:
        return (const Color(0xFFF5EEE4), const Color(0xFF8B4513));
      case DefaultAvatarPreset.kimdochi:
        return (const Color(0xFFF3F3F3), const Color(0xFF333333));
      case DefaultAvatarPreset.jwichuni:
        return (const Color(0xFFF5F3F0), const Color(0xFF536F9F));
    }
  }
}

class GaugeInput extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const GaugeInput({super.key, required this.label, required this.value, this.color, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.lv;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.25))),
      child: Column(
        children: [
          Text(label, style: T.caption),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GaugeBtn(icon: Icons.remove, color: c, filled: false, onTap: onMinus),
              Text(value == 0 ? '--' : '$value', style: T.numLG.copyWith(color: value == 0 ? C.mu : c)),
              _GaugeBtn(icon: Icons.add, color: c, filled: true, onTap: onPlus),
            ],
          ),
          const SizedBox(height: 4),
          Text('/10cm', style: T.caption.copyWith(fontSize: 9)),
        ],
      ),
    );
  }
}

class _GaugeBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _GaugeBtn({required this.icon, required this.color, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 34, height: 34, decoration: BoxDecoration(color: filled ? color : color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: filled ? Colors.white : color, size: 18)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: T.sm.copyWith(fontWeight: FontWeight.w700, color: C.tx2, letterSpacing: 0.3)),
        ?trailing,
      ],
    );
  }
}

class BgOrbs extends StatelessWidget {
  const BgOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _BgPatternPainter()),
      ),
    );
  }
}

class MoriEcosystemBackdrop extends StatelessWidget {
  const MoriEcosystemBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            const BgOrbs(),
            Positioned(
              top: -84,
              right: -90,
              child: Container(
                width: 228,
                height: 228,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      C.tint(C.lv, 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 92,
              left: -28,
              child: Container(
                width: 158,
                height: 158,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      C.pk.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
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

class _BgPatternPainter extends CustomPainter {
  static List<(IconData, Color)> get _items => [
    (Icons.favorite, C.pk),
    (Icons.auto_awesome, C.lv),
    (Icons.favorite_border, C.lmD),
    (Icons.star_rounded, C.pk),
    (Icons.auto_awesome, C.lv),
  ];
  static const _spacing = 52.0;
  static const _iconSize = 18.0;
  static const _opacity = 0.09;

  @override
  void paint(Canvas canvas, Size size) {
    int rowIdx = 0;
    for (double y = 0; y < size.height + _spacing; y += _spacing) {
      final xOffset = (rowIdx % 2 == 0) ? 0.0 : _spacing * 0.5;
      int colIdx = 0;
      for (double x = -_spacing + xOffset; x < size.width + _spacing; x += _spacing) {
        final item = _items[(rowIdx + colIdx) % _items.length];
        final tp = TextPainter(textDirection: TextDirection.ltr)
          ..text = TextSpan(
            text: String.fromCharCode(item.$1.codePoint),
            style: TextStyle(
              fontSize: _iconSize,
              fontFamily: item.$1.fontFamily,
              package: item.$1.fontPackage,
              color: item.$2.withValues(alpha: _opacity),
            ),
          )
          ..layout();
        tp.paint(canvas, Offset(x - _iconSize / 2, y - _iconSize / 2));
        colIdx++;
      }
      rowIdx++;
    }
  }

  @override
  bool shouldRepaint(_BgPatternPainter old) => false;
}

class MoriLogo extends StatelessWidget {
  final double size;
  const MoriLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/login_logo.png', width: size, height: size, fit: BoxFit.contain);
  }
}

class MoriKnitTitle extends StatelessWidget {
  final double fontSize;
  final double? width;
  const MoriKnitTitle({super.key, this.fontSize = 18, this.width});

  @override
  Widget build(BuildContext context) {
    final base = const TextStyle(
      fontFamilyFallback: [
        'Noto Sans KR',
        'Noto Sans CJK KR',
        'Segoe UI',
        'sans-serif',
      ],
    ).copyWith(
      fontSize: fontSize,
      height: 0.96,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
    );
    final title = RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(text: 'Mori', style: base.copyWith(color: C.pkD)),
          TextSpan(text: 'Knit', style: base.copyWith(color: C.tx, fontWeight: FontWeight.w900)),
        ],
      ),
    );
    if (width == null) return title;
    return SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: title,
      ),
    );
  }
}

class MoriBrandHeader extends StatelessWidget {
  final String? subtitle;
  final bool includeUrl;
  final bool compact;

  const MoriBrandHeader({super.key, this.subtitle, this.includeUrl = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // #660 헤더 비율 축소: compact 90→62, non-compact 150→104 (30~35% 축소)
    if (compact) {
      return Container(
        width: double.infinity,
        height: 90,
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Image.asset(
                  'assets/login_logo.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 1),
                MoriKnitTitle(fontSize: 14, width: 92),
              ],
            ),
            if (subtitle != null)
              Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.tint(C.lv, 0.18)),
                    boxShadow: [BoxShadow(color: C.tint(C.lv, 0.06), blurRadius: 6, offset: const Offset(0, 1))],
                  ),
                  child: Text(
                    subtitle!,
                    style: T.caption.copyWith(color: C.tx2, height: 1.25, fontSize: 10, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      height: 150,
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Image.asset(
                'assets/login_logo.png',
                width: 94,
                height: 94,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 0),
              MoriKnitTitle(fontSize: 19, width: 174),
            ],
          ),
          if (subtitle != null)
            Positioned(
              bottom: 3,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  // B&W: 연회색 헤더 위 흰 카드 → 구분 명확
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: C.tint(C.lv, 0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: C.tint(C.lv, 0.06),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  subtitle!,
                  style: T.caption.copyWith(
                    color: C.tx2,
                    height: 1.3,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MoriWideHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget>? trailing;
  final bool compact;

  const MoriWideHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (trailing == null || trailing!.isEmpty) {
      return MoriBrandHeader(subtitle: subtitle, compact: compact);
    }
    return Stack(
      children: [
        MoriBrandHeader(subtitle: subtitle, compact: compact),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: trailing!,
          ),
        ),
      ],
    );
  }
}

class MoriPageHeaderShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;

  const MoriPageHeaderShell({
    super.key,
    required this.child,
    this.maxWidth = 1380,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: C.headerBg,
        border: Border(bottom: BorderSide(color: C.headerBorder, width: 1.2)),
      ),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class UpgradeBanner extends StatelessWidget {
  final String message;
  final VoidCallback onTap;
  const UpgradeBanner({super.key, required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFC084FC)]), borderRadius: BorderRadius.circular(13)),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: T.sm.copyWith(color: Colors.white))),
            const Icon(Icons.chevron_right, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

Future<void> showLoginRequiredDialog(
  BuildContext context, {
  AppStrings? t,
  bool? isKorean,
  String? title,
  String? message,
  String? fromRoute,
}) {
  final strings = t ?? ((isKorean ?? true) ? const AppStringsKo() : const AppStringsEn());
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title ?? strings.loginRequiredDialogTitle, style: T.h3),
      content: Text(
        message ?? strings.loginRequiredDialogBody,
        style: T.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(strings.keepBrowsing),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            final target = fromRoute == null || fromRoute.isEmpty
                ? Routes.login
                : '${Routes.login}?from=${Uri.encodeComponent(fromRoute)}';
            context.go(target);
          },
          child: Text(strings.loginStartFree),
        ),
      ],
    ),
  );
}

Future<R> runWithMoriLoadingDialog<R>(
  BuildContext context, {
  required String message,
  String? subtitle,
  required Future<R> Function() task,
  bool barrierDismissible = false,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: true,
    builder: (dialogContext) => PopScope(
      canPop: barrierDismissible,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          borderColor: C.lv.withValues(alpha: 0.28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.lv.withValues(alpha: 0.1),
                  border: Border.all(color: C.lv.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 3.2,
                    valueColor: AlwaysStoppedAnimation<Color>(C.lv),
                    backgroundColor: C.pk.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: T.bodyBold.copyWith(color: C.tx),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle ?? 'Please wait a moment.',
                style: T.caption.copyWith(color: C.mu),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    return await task();
  } finally {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

/// 저장 버튼 공통 위젯 — 가득찬 너비, 높이 52px, radius 16, C.lv 배경
/// loading=true 시 CircularProgressIndicator 표시 + 비활성화
class MoriSaveButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const MoriSaveButton({
    super.key,
    this.label = '저장하기',
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: C.lv,
          foregroundColor: Colors.white,
          disabledBackgroundColor: C.lv.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// 체크박스 대체 토글 칩 — 선택 시 C.lv 배경, 미선택 시 C.gx 배경
/// AnimatedContainer 160ms 애니메이션 적용
class MoriToggleChip extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const MoriToggleChip({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: value ? C.lv.withValues(alpha: 0.14) : C.gx,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: value ? C.lv : C.bd,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: value ? C.lv : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: value ? C.lv : C.bd, width: 1.4),
              ),
              child: value
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: T.sm.copyWith(
                color: value ? C.lvD : C.tx2,
                fontWeight: value ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoriEmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onAction;

  const MoriEmptyState({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: iconColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title, style: T.bodyBold, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: T.caption.copyWith(color: C.mu), textAlign: TextAlign.center),
            if (buttonLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 소규모 옵션(카테고리 등) 선택용 공통 chip 위젯
/// DropdownButtonFormField 대신 사용하여 일관된 UI 제공
class MoriOptionChips<V> extends StatelessWidget {
  final List<({V value, String label})> options;
  final V selected;
  final ValueChanged<V> onSelected;
  final Color? activeColor;

  const MoriOptionChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? C.lv;
    const textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      fontFamilyFallback: [
        'Noto Sans KR',
        'Noto Sans CJK KR',
        'Segoe UI',
        'sans-serif',
      ],
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        return GestureDetector(
          onTap: () => onSelected(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? active.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: isSelected ? active : C.bd,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt.label,
              style: textStyle.copyWith(
                color: isSelected ? active : C.tx2,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 라이브러리 공통 카드 — Ravelry 스타일 기준 (도안/실 목록에 사용)
class MoriLibraryCard extends StatelessWidget {
  final String title;
  final String? subtitle1;
  final String? subtitle2;
  final Color? subtitle2Color;
  final String? thumbnailUrl;
  final IconData? fallbackIcon;
  final Color fallbackIconBg;
  final Color fallbackIconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MoriLibraryCard({
    super.key,
    required this.title,
    this.subtitle1,
    this.subtitle2,
    this.subtitle2Color,
    this.thumbnailUrl,
    this.fallbackIcon,
    this.fallbackIconBg = const Color(0xFFEDE9FF),
    this.fallbackIconColor = const Color(0xFF7C5CBF),
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: C.gx,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.bd),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fallbackIconBg,
                borderRadius: BorderRadius.circular(10),
                image: thumbnailUrl != null
                    ? DecorationImage(image: NetworkImage(thumbnailUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: (thumbnailUrl == null && fallbackIcon != null)
                  ? Icon(fallbackIcon, color: fallbackIconColor, size: 22)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.bodyBold, overflow: TextOverflow.ellipsis),
                  if (subtitle1 != null)
                    Text(subtitle1!, style: T.caption.copyWith(color: C.mu), overflow: TextOverflow.ellipsis),
                  if (subtitle2 != null)
                    Text(subtitle2!, style: T.caption.copyWith(color: subtitle2Color ?? C.lv), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// 컴팩트 목록 행 — leading 아이콘 + title/subtitle + trailing(팝업 등) + 화살표
// ── 화면 상단 통계 요약바 (세로구분선 + 추가버튼) ──────────────────────────────
class WorkStat {
  final String value;
  final String label;
  final Color? color;
  const WorkStat(this.value, this.label, {this.color});
}

class WorkspaceSummaryBar extends StatelessWidget {
  final List<WorkStat> stats;
  final String addLabel;
  final VoidCallback onAdd;

  const WorkspaceSummaryBar({
    super.key,
    required this.stats,
    required this.addLabel,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (int i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      Container(width: 1, color: C.bd),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stats[i].value,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: stats[i].color ?? C.tx,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stats[i].label,
                            style: TextStyle(fontSize: 10, color: C.mu),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(width: 1, color: C.bd),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 15),
              label: Text(addLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 라이브러리 화면 공통 요약카드 (ProjectSummaryCard 컨셉 통일) ──────────────
class LibrarySummaryRowData {
  final String badge;
  final Color badgeColor;
  final List<String> values;
  final List<Color> valueColors;
  const LibrarySummaryRowData({
    required this.badge,
    required this.badgeColor,
    required this.values,
    required this.valueColors,
  });
}

class LibrarySummaryCard extends StatelessWidget {
  final List<String> headers;
  final List<LibrarySummaryRowData> rows;
  final String? addLabel;
  final VoidCallback? onAdd;

  /// 셀 비율 — badge는 헤더/값보다 살짝 넓게 (1.4x). 사용자 보고 #621 — 좌측 치우침 해소.
  static const int _badgeFlex = 7;
  static const int _cellFlex = 5;

  const LibrarySummaryCard({
    super.key,
    required this.headers,
    required this.rows,
    this.addLabel,
    this.onAdd,
  });

  Widget _headerCell(String text) => Expanded(
        flex: _cellFlex,
        child: Center(
          child: Text(
            text,
            style: T.caption.copyWith(color: C.mu),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      );

  Widget _valueCell(String text, Color color) => Expanded(
        flex: _cellFlex,
        child: Center(
          child: Text(
            text,
            style: T.bodyBold.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      );

  Widget _badgeCell(String text, Color color) => Expanded(
        flex: _badgeFlex,
        child: Container(
          color: color.withValues(alpha: 0.07),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Center(
            child: Text(
              text,
              style: T.caption.copyWith(color: color, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(flex: _badgeFlex),
                        ...headers.map(_headerCell),
                      ],
                    ),
                    Divider(height: 1, thickness: 0.5, color: C.bd),
                    for (int i = 0; i < rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, thickness: 0.5, color: C.bd),
                      Row(
                        children: [
                          _badgeCell(rows[i].badge, rows[i].badgeColor),
                          for (int j = 0; j < rows[i].values.length; j++)
                            _valueCell(rows[i].values[j], rows[i].valueColors[j]),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (addLabel != null && onAdd != null) ...[
                VerticalDivider(width: 1, thickness: 1, color: C.bd),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: Text(
                          addLabel!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.lv,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 2행 요약카드 — 상단 MoriKnit 행 + 하단 Ravelry 행 + 우측 액션 버튼
/// 필드 용어: Dual-Source KPI Bar (이중 소스 KPI 바)
class DualSourceSummaryBar extends StatelessWidget {
  final List<WorkStat> row1Stats;
  final List<WorkStat> row2Stats;
  final String row1Badge;   // 예: 'MoriKnit'
  final String row2Badge;   // 예: 'Ravelry'
  final Color row1Color;
  final Color row2Color;
  final String addLabel;
  final VoidCallback onAdd;

  const DualSourceSummaryBar({
    super.key,
    required this.row1Stats,
    required this.row2Stats,
    required this.row1Badge,
    required this.row2Badge,
    required this.row1Color,
    required this.row2Color,
    required this.addLabel,
    required this.onAdd,
  });

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
      );

  Widget _row(List<WorkStat> stats) => Row(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) Container(width: 1, height: 28, color: C.bd),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(stats[i].value,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: stats[i].color ?? C.tx)),
                  const SizedBox(height: 1),
                  Text(stats[i].label,
                      style: TextStyle(fontSize: 9, color: C.mu), textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _badge(row1Badge, row1Color),
                const SizedBox(height: 4),
                _row(row1Stats),
                const SizedBox(height: 6),
                Container(height: 1, color: C.bd),
                const SizedBox(height: 6),
                _badge(row2Badge, row2Color),
                const SizedBox(height: 4),
                _row(row2Stats),
              ],
            ),
          ),
          Container(width: 1, height: 80, color: C.bd),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: Text(addLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class MoriCompactRow extends StatelessWidget {
  final VoidCallback onTap;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool dense;

  const MoriCompactRow({
    super.key,
    required this.onTap,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 6 : 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: T.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!, style: T.caption.copyWith(color: C.mu), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            ?trailing,
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
          ],
        ),
      ),
    );
  }
}
