// 이슈 #721/#722 — 네트워크/DB 장애를 화면에서 일관되게 분류하기 위한 typed exception.

class ServerUnavailableException implements Exception {
  final String? message;
  const ServerUnavailableException([this.message]);

  @override
  String toString() => 'ServerUnavailableException(${message ?? "no message"})';
}

/// 이슈 #803 — Firestore rules 거부(permission-denied)를 별도 분류.
/// 사용자에게는 "권한 문제" 안내, 개발자는 코드/룰 검증.
class PermissionDeniedException implements Exception {
  final String? message;
  const PermissionDeniedException([this.message]);

  @override
  String toString() => 'PermissionDeniedException(${message ?? "no message"})';
}
