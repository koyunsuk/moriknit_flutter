/// AI 변환 에러를 사용자 친화 메시지로 매핑.
/// raw API 응답(JSON 문자열 또는 Exception 메시지) → 분류된 사용자 메시지.
///
/// 이슈 #688 — AI 도안 변환기 에러 raw JSON 노출 차단 + 친화 메시지 + 구독 유도.
library;

class AiErrorInfo {
  AiErrorInfo({required this.message, this.action = AiErrorAction.none});

  /// 사용자에게 표시할 메시지 (raw JSON/스택트레이스 노출 금지).
  final String message;

  /// 사용자 행동 유도 (구독 / 재시도 / 없음).
  final AiErrorAction action;
}

enum AiErrorAction {
  /// "프로 구독으로 업그레이드" 유도 (스낵바 액션 버튼).
  upgradeSubscription,

  /// "다시 시도" 유도.
  retry,

  /// 별도 액션 없음.
  none,
}

class AiErrorMapper {
  AiErrorMapper._();

  /// HTTP 상태 코드 추출 — `"400 {...}"`, `"status: 503"`, `"code: 429"` 등 케이스 대응.
  /// 매칭 실패 시 null.
  static int? _extractStatusCode(String raw) {
    // "status: NNN" / "code: NNN" / "statusCode: NNN" / "HTTP NNN" 패턴.
    final labeled = RegExp(
      r'(?:status(?:[_\s-]?code)?|code|http)\s*[:=]?\s*(\d{3})',
      caseSensitive: false,
    ).firstMatch(raw);
    if (labeled != null) {
      final n = int.tryParse(labeled.group(1)!);
      if (n != null && n >= 100 && n < 600) return n;
    }
    // 선행 "NNN " 패턴 (예: `400 {"type":"error"...}`).
    final leading = RegExp(r'(?<![\d])(\d{3})(?![\d])').firstMatch(raw);
    if (leading != null) {
      final n = int.tryParse(leading.group(1)!);
      if (n != null && n >= 400 && n < 600) return n;
    }
    return null;
  }

  /// 에러 객체(Exception, String, response body 등) → [AiErrorInfo].
  static AiErrorInfo map(Object error, {required bool isKorean}) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    final status = _extractStatusCode(raw);

    // 1) rate_limit / quota / billing — 사용량/요금 한도.
    final isRateLimit = status == 429 ||
        lower.contains('rate_limit') ||
        lower.contains('rate limit') ||
        lower.contains('quota') ||
        lower.contains('insufficient_quota') ||
        lower.contains('billing') ||
        lower.contains('too_many_requests');
    if (isRateLimit) {
      return AiErrorInfo(
        message: isKorean
            ? 'AI 사용량이 많아요. 프로 요금제로 업그레이드하면 더 많이 사용할 수 있어요.'
            : 'AI usage limit reached. Upgrade to Pro for higher limits.',
        action: AiErrorAction.upgradeSubscription,
      );
    }

    // 2) auth / permission — 인증 만료 등 (사용자 재시도 유도).
    final isAuth = status == 401 ||
        status == 403 ||
        lower.contains('unauthorized') ||
        lower.contains('permission_denied') ||
        lower.contains('forbidden');
    if (isAuth) {
      return AiErrorInfo(
        message: isKorean
            ? '인증이 만료되었어요. 다시 로그인 후 시도해 주세요.'
            : 'Authentication expired. Please sign in again and retry.',
        action: AiErrorAction.retry,
      );
    }

    // 3) invalid_request / 파일 형식 — PDF 손상, 지원하지 않는 형식.
    final isInvalidRequest = status == 400 ||
        status == 415 ||
        status == 422 ||
        lower.contains('invalid_request') ||
        lower.contains('invalid request') ||
        lower.contains('invalid_argument') ||
        lower.contains('unsupported');
    if (isInvalidRequest) {
      return AiErrorInfo(
        message: isKorean
            ? '도안 파일을 분석하지 못했어요. 파일을 다시 확인해 주세요.'
            : 'Could not analyze the file. Please check the file and try again.',
        action: AiErrorAction.retry,
      );
    }

    // 4) timeout / network / 5xx 서버 오류.
    final is5xx = status != null && status >= 500 && status < 600;
    final isNetwork = is5xx ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('deadline_exceeded') ||
        lower.contains('socketexception') ||
        lower.contains('network') ||
        lower.contains('unavailable') ||
        lower.contains('internal_error') ||
        lower.contains('server error') ||
        lower.contains('bad gateway') ||
        lower.contains('gateway timeout');
    if (isNetwork) {
      return AiErrorInfo(
        message: isKorean
            ? '잠시 후 다시 시도해 주세요.'
            : 'Please try again in a moment.',
        action: AiErrorAction.retry,
      );
    }

    // 5) 기타 — 일반 메시지 (raw 절대 포함하지 않음).
    return AiErrorInfo(
      message: isKorean
          ? 'AI 분석에 실패했어요. 다시 시도해 주세요.'
          : 'AI analysis failed. Please try again.',
      action: AiErrorAction.retry,
    );
  }
}
