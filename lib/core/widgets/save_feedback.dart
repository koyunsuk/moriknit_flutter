import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 저장 중 오버레이 컨트롤러 — .close() 로 해제.
class SavingOverlayController {
  final OverlayEntry _entry;
  bool _removed = false;
  SavingOverlayController(this._entry);

  void close() {
    if (_removed) return;
    _removed = true;
    _entry.remove();
  }
}

/// 화면 중앙에 작은 저장 팝업을 표시합니다.
/// 반환된 컨트롤러의 .close() 로 해제해야 합니다.
SavingOverlayController showSavingOverlay(BuildContext context, {String? message}) {
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SavingPopup(message: message ?? '저장하는 중입니다.'),
  );
  Overlay.of(context).insert(entry);
  return SavingOverlayController(entry);
}

class _SavingPopup extends StatelessWidget {
  final String message;
  const _SavingPopup({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(C.lvL),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                message,
                style: T.sm.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 저장 완료 스낵바를 표시합니다.
void showSavedSnackBar(Object contextOrMessenger, {String? message}) {
  final messenger = contextOrMessenger is ScaffoldMessengerState
      ? contextOrMessenger
      : ScaffoldMessenger.of(contextOrMessenger as BuildContext);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      backgroundColor: C.lvD,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            message ?? '저장되었습니다.',
            style: T.sm.copyWith(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

/// 저장 실패 스낵바를 표시합니다.
void showSaveErrorSnackBar(Object contextOrMessenger, {String? message}) {
  final messenger = contextOrMessenger is ScaffoldMessengerState
      ? contextOrMessenger
      : ScaffoldMessenger.of(contextOrMessenger as BuildContext);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: C.og,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            message ?? '저장에 실패했습니다.',
            style: T.sm.copyWith(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

/// 저장 동작을 실행하며 피드백 UI를 자동으로 처리하는 헬퍼입니다.
Future<void> runWithSaveFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
  String? errorMessage,
}) async {
  final controller = showSavingOverlay(context);
  try {
    await action();
    controller.close();
    if (context.mounted) {
      showSavedSnackBar(context, message: successMessage);
    }
  } catch (e) {
    controller.close();
    if (context.mounted) {
      showSaveErrorSnackBar(context, message: errorMessage);
    }
    rethrow;
  }
}

/// 필수 항목 누락 시 AlertDialog 표시. missing이 비어 있으면 아무것도 하지 않고 true 반환.
/// Returns false if dialog was shown (validation failed), true if all fields are present.
Future<bool> showMissingFieldsDialog(
  BuildContext context, {
  required List<String> missing,
  bool isKorean = true,
}) async {
  if (missing.isEmpty) return true;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isKorean ? '필수 항목을 입력해 주세요' : 'Required fields missing',
        style: T.h3,
      ),
      content: Text(
        missing.map((e) => '• $e').join('\n'),
        style: T.body,
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: C.lv,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(isKorean ? '확인' : 'OK'),
        ),
      ],
    ),
  );
  return false;
}
