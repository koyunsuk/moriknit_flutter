// 이슈 #834 — 앱 포그라운드 상태에서 푸시 도착 시 화면 상단 floating 알림 카드.
//
// 기존 SnackBar 를 대체 — 모리톡 채팅 풍선 스타일 (@moriknit 아바타 + 제목 + 본문 + CTA).
// OverlayEntry 로 띄우고 4.5초 뒤 자동 해제. 사용자 탭 시 즉시 해제 + 딥링크 이동.
//
// 호출:
//   ForegroundNotificationOverlay.show(
//     context,
//     title: '...',
//     body: '...',
//     onTap: () => router.push('/dm'),
//   );

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ForegroundNotificationOverlay {
  ForegroundNotificationOverlay._();

  static OverlayEntry? _current;
  static Timer? _dismissTimer;

  /// 알림 카드 표시. 기존 카드가 있으면 즉시 교체.
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onTap,
    Duration duration = const Duration(milliseconds: 4500),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    _dismiss();

    final entry = OverlayEntry(
      builder: (ctx) => _ForegroundCard(
        title: title,
        body: body,
        onTap: onTap == null
            ? null
            : () {
                _dismiss();
                onTap();
              },
        onClose: _dismiss,
      ),
    );
    _current = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _current?.remove();
    _current = null;
  }
}

class _ForegroundCard extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback onClose;

  const _ForegroundCard({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_ForegroundCard> createState() => _ForegroundCardState();
}

class _ForegroundCardState extends State<_ForegroundCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: mq.padding.top + 12,
      left: 12,
      right: 12,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: FadeTransition(
            opacity: _opacity,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: C.lv.withValues(alpha: 0.24)),
                    boxShadow: [
                      BoxShadow(
                        color: C.lv.withValues(alpha: 0.20),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        C.lvL.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // @moriknit 봇 아바타 (라벤더 톤 + 채팅 풍선 아이콘)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: C.lv,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: C.lv.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '@moriknit',
                                  style: T.caption.copyWith(
                                    color: C.lvD,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: C.lv.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '공식',
                                    style: T.caption.copyWith(
                                      color: C.lvD,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (widget.title.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.title,
                                style: T.bodyBold.copyWith(color: C.tx),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (widget.body.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                style: T.caption.copyWith(
                                  color: C.tx2,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          color: C.mu,
                          size: 18,
                        ),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
