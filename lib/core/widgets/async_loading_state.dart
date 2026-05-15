import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 이슈 #706 — DB 연결 지연 시 무한로딩 차단 + 친화 메시지 통일
///
/// 사용법:
/// ```dart
/// final async = ref.watch(myProvider);
/// return AsyncTimeoutGuard<List<Item>>(
///   async: async,
///   onRetry: () => ref.invalidate(myProvider),
///   builder: (data) => MyDataView(data),
/// );
/// ```
///
/// 동작:
/// - loading 5초 이내: CircularProgressIndicator만 표시
/// - loading 5초 초과: "인터넷 연결이 지연되고 있어요" 친화 메시지 + 재시도 버튼
/// - error: 친화 메시지 + 재시도 버튼 (raw 예외는 노출 안 함, debug에서만 확인)
class AsyncTimeoutGuard<D> extends StatelessWidget {
  final AsyncValue<D> async;
  final Widget Function(D data) builder;
  final VoidCallback onRetry;
  final Duration timeout;
  final bool isKorean;
  final EdgeInsetsGeometry padding;

  /// 압축 모드 — 인디케이터 크기·여백 축소 (목록 카드 내부용)
  final bool compact;

  const AsyncTimeoutGuard({
    super.key,
    required this.async,
    required this.builder,
    required this.onRetry,
    required this.isKorean,
    this.timeout = const Duration(seconds: 5),
    this.padding = const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: builder,
      error: (e, _) => AsyncDelayedFriendly(
        isKorean: isKorean,
        onRetry: onRetry,
        padding: padding,
        compact: compact,
      ),
      loading: () => AsyncLoadingFriendly(
        timeout: timeout,
        isKorean: isKorean,
        onRetry: onRetry,
        padding: padding,
        compact: compact,
      ),
    );
  }
}

/// 로딩 인디케이터 — 일정 시간 경과 시 친화 메시지로 전환
class AsyncLoadingFriendly extends StatefulWidget {
  final Duration timeout;
  final bool isKorean;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const AsyncLoadingFriendly({
    super.key,
    this.timeout = const Duration(seconds: 5),
    required this.isKorean,
    required this.onRetry,
    this.padding = const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    this.compact = false,
  });

  @override
  State<AsyncLoadingFriendly> createState() => _AsyncLoadingFriendlyState();
}

class _AsyncLoadingFriendlyState extends State<AsyncLoadingFriendly> {
  Timer? _timer;
  bool _delayed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.timeout, () {
      if (mounted) setState(() => _delayed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_delayed) {
      return AsyncDelayedFriendly(
        isKorean: widget.isKorean,
        onRetry: widget.onRetry,
        padding: widget.padding,
        compact: widget.compact,
      );
    }
    final size = widget.compact ? 20.0 : 32.0;
    final stroke = widget.compact ? 2.4 : 3.0;
    return Padding(
      padding: widget.padding,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: stroke,
            valueColor: AlwaysStoppedAnimation<Color>(C.lv),
          ),
        ),
      ),
    );
  }
}

/// 연결 지연/오류 친화 안내 + 재시도 버튼 (공용)
class AsyncDelayedFriendly extends StatelessWidget {
  final bool isKorean;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const AsyncDelayedFriendly({
    super.key,
    required this.isKorean,
    required this.onRetry,
    this.padding = const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 28.0 : 44.0;
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: C.mu, size: iconSize),
            SizedBox(height: compact ? 8 : 12),
            Text(
              loadingDelayMessage(isKorean),
              style: (compact ? T.caption : T.body).copyWith(color: C.tx2),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: compact ? 10 : 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(isKorean ? '다시 시도' : 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 18,
                  vertical: compact ? 8 : 10,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 통일 메시지 — 연결 지연/오류 시 사용
String loadingDelayMessage(bool isKorean) => isKorean
    ? '인터넷 연결이 지연되고 있어요.\n잠시 후 다시 시도해 주세요.'
    : 'Internet connection is slow.\nPlease try again later.';
