// ============================================================
// MoriKnit — validators.dart
// 시방서 v2 정규식 규칙 완전 반영
// 파일명: validators.dart (snake_case)
// 클래스명: Validators (PascalCase)
// 상수: SCREAMING_SNAKE_CASE
// ============================================================

// ignore_for_file: constant_identifier_names

/// MoriKnit 입력 검증 유틸
/// 시방서 v2 정규식 규칙 기반
class Validators {

  Validators._(); // 인스턴스 생성 방지

  // ── 구독 한도 상수 (시방서 3.3) ─────────────────────────────
  static const int MAX_FREE_SWATCHES       = 5;
  static const int FREE_PROJECT_LIMIT      = 3;
  static const int FREE_COUNTER_LIMIT      = 1;
  static const int STARTER_EDITOR_LIMIT    = 10;
  static const int FREE_MONTHLY_POST_LIMIT = 5;

  // ── 게이지 범위 상수 ─────────────────────────────────────────
  static const int GAUGE_MIN   = 1;
  static const int GAUGE_MAX   = 99;
  static const double NEEDLE_MIN = 0.0;
  static const double NEEDLE_MAX = 25.0;

  // ── 이름 길이 상수 ───────────────────────────────────────────
  static const int PROJECT_NAME_MAX  = 50;
  static const int SWATCH_NAME_MAX   = 30;
  static const int BRAND_NAME_MAX    = 40;
  static const int PRICE_MAX         = 9999999; // ₩9,999,999

  // ================================================================
  // 정규식 패턴 (시방서 v2 섹션 4)
  // ================================================================

  /// 이메일: ^[\w\.-]+@[\w\.-]+\.\w{2,}$
  static final RegExp _emailRegex =
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');

  /// 전화번호: ^01[016789]-?\d{3,4}-?\d{4}$
  static final RegExp _phoneRegex =
      RegExp(r'^01[016789]-?\d{3,4}-?\d{4}$');

  /// 색상 코드: ^#[0-9A-Fa-f]{6}$
  static final RegExp _colorCodeRegex =
      RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// 게이지 코/단 수: ^([1-9]|[1-9][0-9])$ (1~99 정수)
  static final RegExp _gaugeRegex =
      RegExp(r'^([1-9]|[1-9][0-9])$');

  /// 바늘 사이즈: ^([0-9]|1[0-9]|2[0-5])(\.5)?$ (0~25, 0.5단위)
  static final RegExp _needleSizeRegex =
      RegExp(r'^([0-9]|1[0-9]|2[0-5])(\.5)?$');

  /// 가격 KRW: ^[0-9]{1,7}$ (0~9,999,999)
  static final RegExp _priceRegex =
      RegExp(r'^[0-9]{1,7}$');

  /// URL: ^https?:\/\/[\w\-\.]+\.[a-z]{2,}.*$
  static final RegExp _urlRegex =
      RegExp(r'^https?:\/\/[\w\-\.]+\.[a-z]{2,}.*$');

  /// Firebase UID: [a-zA-Z0-9]{28}
  static final RegExp _firebaseUidRegex =
      RegExp(r'^[a-zA-Z0-9]{28}$');

  // ================================================================
  // 검증 메서드
  // ================================================================

  /// 이메일 검증
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return '이메일을 입력해주세요';
    if (!_emailRegex.hasMatch(value.trim())) return '올바른 이메일 형식이 아닙니다';
    return null;
  }

  /// 전화번호 검증
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return '전화번호를 입력해주세요';
    if (!_phoneRegex.hasMatch(value.trim())) return '올바른 전화번호 형식이 아닙니다 (예: 010-1234-5678)';
    return null;
  }

  /// 색상 코드 검증 (#RRGGBB)
  static String? colorCode(String? value) {
    if (value == null || value.trim().isEmpty) return '색상 코드를 입력해주세요';
    if (!_colorCodeRegex.hasMatch(value.trim())) return '올바른 색상 코드가 아닙니다 (예: #F472B6)';
    return null;
  }

  /// 게이지 코 수 / 단 수 검증 (1~99 정수)
  static String? gauge(String? value, {String label = '게이지'}) {
    if (value == null || value.trim().isEmpty) return '$label를 입력해주세요';
    if (!_gaugeRegex.hasMatch(value.trim())) {
      return '$label는 1~99 사이의 정수여야 합니다';
    }
    return null;
  }

  /// 코 수 검증
  static String? stitchCount(String? value) =>
      gauge(value, label: '코 수');

  /// 단 수 검증
  static String? rowCount(String? value) =>
      gauge(value, label: '단 수');

  /// 바늘 사이즈 검증 (0~25mm, 0.5단위)
  static String? needleSize(String? value) {
    if (value == null || value.trim().isEmpty) return '바늘 사이즈를 입력해주세요';
    if (!_needleSizeRegex.hasMatch(value.trim())) {
      return '바늘 사이즈는 0~25mm 범위, 0.5단위여야 합니다 (예: 3.5, 4.0)';
    }
    return null;
  }

  /// 프로젝트 이름 검증 (최대 50자)
  static String? projectName(String? value) {
    if (value == null || value.trim().isEmpty) return '프로젝트 이름을 입력해주세요';
    if (value.trim().length > PROJECT_NAME_MAX) {
      return '프로젝트 이름은 최대 $PROJECT_NAME_MAX자까지 입력 가능합니다';
    }
    return null;
  }

  /// 스와치 이름 검증 (최대 30자)
  static String? swatchName(String? value) {
    if (value == null || value.trim().isEmpty) return '스와치 이름을 입력해주세요';
    if (value.trim().length > SWATCH_NAME_MAX) {
      return '스와치 이름은 최대 $SWATCH_NAME_MAX자까지 입력 가능합니다';
    }
    return null;
  }

  /// 브랜드 이름 검증 — yarnBrands / needleBrands (최대 40자)
  static String? brandName(String? value) {
    if (value == null || value.trim().isEmpty) return '브랜드 이름을 입력해주세요';
    if (value.trim().length > BRAND_NAME_MAX) {
      return '브랜드 이름은 최대 $BRAND_NAME_MAX자까지 입력 가능합니다';
    }
    return null;
  }

  /// 가격 검증 (KRW, 0~9,999,999 / 0=무료)
  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) return '가격을 입력해주세요 (무료=0)';
    if (!_priceRegex.hasMatch(value.trim())) {
      return '가격은 0~9,999,999 사이의 숫자여야 합니다';
    }
    final int p = int.parse(value.trim());
    if (p > PRICE_MAX) return '최대 가격은 ₩${PRICE_MAX.toString()}입니다';
    return null;
  }

  /// URL 검증 (https 필수)
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) return 'URL을 입력해주세요';
    if (!_urlRegex.hasMatch(value.trim())) {
      return '올바른 URL 형식이 아닙니다 (https:// 로 시작해야 합니다)';
    }
    return null;
  }

  /// Firebase UID 검증 (내부용)
  static bool isValidFirebaseUid(String uid) =>
      _firebaseUidRegex.hasMatch(uid);

  // ================================================================
  // 구독 한도 체크 (featureGates 기반 — UI 레이어용)
  // ================================================================

  /// Free 스와치 한도 초과 여부
  static bool isSwatchLimitReached(int currentCount) =>
      currentCount >= MAX_FREE_SWATCHES;

  /// Free 스와치 남은 개수
  static int swatchRemaining(int currentCount) =>
      (MAX_FREE_SWATCHES - currentCount).clamp(0, MAX_FREE_SWATCHES);

  /// Free 프로젝트 한도 초과 여부
  static bool isProjectLimitReached(int currentCount) =>
      currentCount >= FREE_PROJECT_LIMIT;

  /// Free 카운터 한도 초과 여부
  static bool isCounterLimitReached(int currentCount) =>
      currentCount >= FREE_COUNTER_LIMIT;

  /// Free 월 게시글 한도 초과 여부
  static bool isMonthlyPostLimitReached(int monthlyCount) =>
      monthlyCount >= FREE_MONTHLY_POST_LIMIT;

  /// 월 게시글 남은 횟수
  static int monthlyPostRemaining(int monthlyCount) =>
      (FREE_MONTHLY_POST_LIMIT - monthlyCount).clamp(0, FREE_MONTHLY_POST_LIMIT);

  // ================================================================
  // 편의 메서드
  // ================================================================

  /// 값이 유효한 게이지 정수인지 확인 (UI ±버튼용)
  static bool isValidGaugeInt(int value) =>
      value >= GAUGE_MIN && value <= GAUGE_MAX;

  /// 값이 유효한 바늘 사이즈인지 확인 (0.5 단위)
  static bool isValidNeedleSize(double value) =>
      value >= NEEDLE_MIN &&
      value <= NEEDLE_MAX &&
      (value * 2) == (value * 2).roundToDouble();

  /// 정가 포맷 (₩3,500 형식)
  static String formatPrice(int price) {
    if (price == 0) return '무료';
    return '₩${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }
}
