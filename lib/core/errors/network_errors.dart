// 이슈 #721/#722 — 네트워크/DB 장애를 화면에서 일관되게 분류하기 위한 typed exception.

class ServerUnavailableException implements Exception {
  final String? message;
  const ServerUnavailableException([this.message]);

  @override
  String toString() => 'ServerUnavailableException(${message ?? "no message"})';
}
