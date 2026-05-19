// 이슈 #834 — 시스템 유저 상수.
// @moriknit 공식 봇 계정 (어드민 발송 푸시 → 자동 DM 으로 누적).
//
// users/{kMoriknitSystemUid} 도큐먼트는 Cloud Function 측에서 first-call 시
// lazy create 됩니다 (handle: 'moriknit', displayName: '모리니트', isSystem: true).
// 클라이언트는 DM 룸 표시에서 isSystem 플래그를 활용해 차별화합니다.

class SystemUsers {
  /// @moriknit 공식 봇 계정 UID. 어드민 푸시·시스템 알림의 발신자.
  static const String moriknitUid = 'moriknit_system';

  /// 시스템 봇 핸들 (UI 표시용 — @moriknit)
  static const String moriknitHandle = 'moriknit';

  /// 시스템 봇 displayName (한국어 기본)
  static const String moriknitDisplayName = '모리니트';

  /// 주어진 uid 가 시스템 봇인지 여부.
  static bool isSystem(String uid) => uid == moriknitUid;
}
