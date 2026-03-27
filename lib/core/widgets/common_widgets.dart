import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.borderColor,
    this.radius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? C.bd, width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1F6D4AFF),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            const BoxShadow(
              color: Color(0x14FFFFFF),
              blurRadius: 2,
              offset: Offset(0, -1),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF9FFFFFF), Color(0xF2FFF7FD)],
          ),
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
              color: C.lv.withValues(alpha: 0.06),
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
  const MoriTabDestination(this.icon, this.label, this.accent, {this.avatarUrl, this.avatarInitial});
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
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isOn ? accent.withValues(alpha: 0.18) : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: hasAvatar ? _ProfileBadge(url: tab.avatarUrl, initial: tab.avatarInitial, accent: accent, isOn: isOn) : Icon(tab.icon, size: 18, color: accent),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final String? url;
  final String? initial;
  final Color accent;
  final bool isOn;
  const _ProfileBadge({this.url, this.initial, required this.accent, required this.isOn});

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
    final text = (initial == null || initial!.isEmpty) ? 'M' : initial!;
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isOn ? 0.92 : 0.82),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(text, style: T.captionBold.copyWith(color: accent, fontSize: 10)),
      ),
    );
  }
}

class GaugeInput extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const GaugeInput({super.key, required this.label, required this.value, this.color = C.lv, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(
        children: [
          Text(label, style: T.caption),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GaugeBtn(icon: Icons.remove, color: color, filled: false, onTap: onMinus),
              Text(value == 0 ? '--' : '$value', style: T.numLG.copyWith(color: value == 0 ? C.mu : color)),
              _GaugeBtn(icon: Icons.add, color: color, filled: true, onTap: onPlus),
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
        Text(title, style: T.captionBold.copyWith(letterSpacing: 0.2, color: C.mu)),
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
        child: Stack(
          children: [
            Positioned(top: -88, right: -86, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [C.lv.withValues(alpha: 0.14), Colors.transparent])))),
            Positioned(bottom: 90, left: -20, child: Container(width: 165, height: 165, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [C.pk.withValues(alpha: 0.34), Colors.transparent])))),
          ],
        ),
      ),
    );
  }
}

class MoriLogo extends StatelessWidget {
  final double size;
  const MoriLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.contain);
  }
}

class MoriKnitTitle extends StatelessWidget {
  final double fontSize;
  const MoriKnitTitle({super.key, this.fontSize = 18});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
        children: const [
          TextSpan(text: 'M', style: TextStyle(color: C.pk, fontWeight: FontWeight.w900)),
          TextSpan(text: 'ori', style: TextStyle(color: C.tx)),
          TextSpan(text: 'K', style: TextStyle(color: C.lmD, fontWeight: FontWeight.w900)),
          TextSpan(text: 'nit', style: TextStyle(color: C.tx)),
        ],
      ),
    );
  }
}

class MoriBrandHeader extends StatelessWidget {
  final double logoSize;
  final double titleSize;
  final String? subtitle;
  final bool includeUrl;

  const MoriBrandHeader({super.key, this.logoSize = 92, this.titleSize = 30, this.subtitle, this.includeUrl = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: C.pk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.pk.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: C.pk.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          MoriLogo(size: logoSize),
          const SizedBox(height: 10),
          MoriKnitTitle(fontSize: titleSize),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: T.sm.copyWith(color: C.tx2, height: 1.35), textAlign: TextAlign.center),
          ],
          if (includeUrl) ...[
            const SizedBox(height: 6),
            Text('MoriKnit.com', style: T.captionBold.copyWith(color: C.lvD, letterSpacing: 0.4)),
          ],
        ],
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
