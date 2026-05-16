// 이슈 #722 — 모든 데이터 로딩 화면의 통일 표시.
// 로딩 / 서버 장애 / 빈 데이터 / 정상 데이터를 일관되게 표시.
// 블록 크기에 맞는 플레이스홀더로 흰 공백 방지.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/network_errors.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// AsyncValue를 받아 로딩/에러/데이터 상태를 통일 UI로 표시.
///
/// - loading: 블록 크기에 맞는 스켈레톤 행(rows) 표시
/// - error (ServerUnavailableException 포함): "서버 연결에 장애가 있음" + 재시도
/// - data: builder 호출
///
/// [emptyBuilder]가 제공되면 데이터가 비어있을 때 호출 (List/Map 자동 판별 불가하므로 [isEmpty] 콜백 사용).
class AsyncDataView<D> extends StatelessWidget {
  final AsyncValue<D> async;
  final Widget Function(D data) builder;
  final bool Function(D data)? isEmpty;
  final Widget Function()? emptyBuilder;
  final VoidCallback? onRetry;
  final int placeholderRows;
  final double rowHeight;
  final String? loadingHint;

  const AsyncDataView({
    super.key,
    required this.async,
    required this.builder,
    this.isEmpty,
    this.emptyBuilder,
    this.onRetry,
    this.placeholderRows = 3,
    this.rowHeight = 50,
    this.loadingHint,
  });

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => _LoadingPlaceholder(
        rows: placeholderRows,
        rowHeight: rowHeight,
        hint: loadingHint,
      ),
      error: (e, _) => _ServerErrorPlaceholder(
        rows: placeholderRows,
        rowHeight: rowHeight,
        isServerError: e is ServerUnavailableException,
        onRetry: onRetry,
      ),
      data: (data) {
        final empty = isEmpty?.call(data) ?? false;
        if (empty && emptyBuilder != null) return emptyBuilder!();
        return builder(data);
      },
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  final int rows;
  final double rowHeight;
  final String? hint;
  const _LoadingPlaceholder({
    required this.rows,
    required this.rowHeight,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rows; i++)
          Container(
            height: rowHeight,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd.withValues(alpha: 0.5)),
            ),
          ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              hint!,
              style: T.caption.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

class _ServerErrorPlaceholder extends StatelessWidget {
  final int rows;
  final double rowHeight;
  final bool isServerError;
  final VoidCallback? onRetry;
  const _ServerErrorPlaceholder({
    required this.rows,
    required this.rowHeight,
    required this.isServerError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rows; i++)
          Container(
            height: rowHeight,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd.withValues(alpha: 0.5)),
            ),
          ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 16, color: C.og),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '서버 연결에 장애가 있어요',
                  style: T.caption.copyWith(color: C.og),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '재시도',
                    style: T.caption.copyWith(color: C.lv, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 빈 데이터용 플레이스홀더. 블록 크기에 맞춰 스켈레톤 행 + 안내 문구 표시.
class EmptyBlockPlaceholder extends StatelessWidget {
  final String message;
  final int rows;
  final double rowHeight;
  const EmptyBlockPlaceholder({
    super.key,
    required this.message,
    this.rows = 3,
    this.rowHeight = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rows; i++)
          Container(
            height: rowHeight,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: C.gx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.bd.withValues(alpha: 0.5)),
            ),
          ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            message,
            style: T.caption.copyWith(color: C.mu, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
