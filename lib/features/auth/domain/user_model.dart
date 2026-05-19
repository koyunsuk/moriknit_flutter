import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/firestore_json.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    required String email,
    @Default('') String displayName,
    @Default('') String photoURL,
    @Default('') String bio,
    @Default(UserSubscription()) UserSubscription subscription,
    @Default(UserUsage()) UserUsage usage,
    String? locale,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    @Default(10000) int moriBalance,
    // 이슈 #749 — 질문게시판 답글 채택 포인트
    @Default(0) int points,
    // 이슈 #750 — 마이페이지 SNS 입력 필드.
    // keys: 'instagram', 'youtube', 'blog', 'kakaoId', 'whatsapp', 'email'
    // 값은 사용자가 입력한 URL/ID. Pro 회원만 글 작성 시 노출됨.
    @Default(<String, String>{}) Map<String, String> socialLinks,
    // 이슈 #750 — 휴대폰 인증 여부. Pro 결제 게이트의 선결 조건.
    @Default(false) bool phoneVerified,
    // 이슈 #750 — 인증된 휴대폰 번호 (E.164 형식 권장: +821012345678).
    // UI 노출 시 마스킹 처리 (예: 010-****-1234).
    String? phoneNumber,
    // 이슈 #771 — 회원 닉네임(@핸들) 시스템.
    // 형식: ^[a-z0-9_]{3,20}$ (소문자/숫자/언더스코어 3~20자).
    // handles/{handle} 컬렉션에 reservation 문서로 중복 방지.
    @Default('') String handle,
    // 이슈 #771 — 핸들 마지막 변경 시각. 30일 변경 제한 기준.
    DateTime? handleUpdatedAt,
    // 이슈 #831 — 외부 도안 이메일 인입 키 (4자 영숫자, 소문자).
    // 형식: ^[a-z0-9]{4,8}$. 인입 주소 = `{handle}_{key}@in.moriknit.com`.
    // 미발급(빈 문자열) 시 마이페이지 카드에서 1회 발급 버튼 노출.
    @Default('') String inboundEmailKey,
    // 이슈 #831 — 인입 키 마지막 갱신 시각 (스팸 누출 재발급 추적).
    DateTime? inboundEmailUpdatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final raw = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    // 일부 사용자 도큐먼트에 email/nested 필드 누락 시 fromJson 의 required String 캐스트
    // 에러로 어드민 회원 목록 화면 전체가 깨지는 회귀 방지.
    final data = <String, dynamic>{
      ...raw,
      'uid': doc.id,
      'email': (raw['email'] ?? '').toString(),
      'displayName': (raw['displayName'] ?? '').toString(),
      'photoURL': (raw['photoURL'] ?? '').toString(),
      'bio': (raw['bio'] ?? '').toString(),
      'handle': (raw['handle'] ?? '').toString(),
      'inboundEmailKey': (raw['inboundEmailKey'] ?? '').toString(),
    };
    try {
      return UserModel.fromJson(normalizeFirestoreMap(data));
    } catch (_) {
      // 깨진 도큐먼트 (nested subscription/usage 등 null) 도 어드민 목록에 표시 가능하도록 최소 모델 fallback.
      return UserModel(
        uid: doc.id,
        email: (raw['email'] ?? '').toString(),
        displayName: (raw['displayName'] ?? '').toString(),
        photoURL: (raw['photoURL'] ?? '').toString(),
        handle: (raw['handle'] ?? '').toString(),
      );
    }
  }

  factory UserModel.initial({
    required String uid,
    required String email,
    String displayName = '',
    String photoURL = '',
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      subscription: const UserSubscription(),
      usage: const UserUsage(),
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
  }
}

@freezed
class UserSubscription with _$UserSubscription {
  const factory UserSubscription({
    @Default('free') String planId,
    @Default('active') String status,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    @Default(false) bool cancelAtPeriodEnd,
    String? pgSubscriptionId,
    DateTime? trialEndAt,
  }) = _UserSubscription;

  factory UserSubscription.fromJson(Map<String, dynamic> json) => _$UserSubscriptionFromJson(json);
}

@freezed
class UserUsage with _$UserUsage {
  const factory UserUsage({
    @Default(0) int swatchCount,
    @Default(0) int projectCount,
    @Default(0) int counterCount,
    @Default(0) int editorSaveCount,
    @Default(0) int postsThisMonth,
    // 이슈 #754 — 마이페이지 AI 사용량 블록용 월별 카운터.
    // 매월 1일 reset (서버 또는 클라이언트 진입 시 monthKey 비교 후 0 리셋).
    @Default(0) int aiConversionThisMonth,
    // YYYY-MM 형식. 다음 달 진입 시 aiConversionThisMonth=0으로 리셋 트리거.
    @Default('') String aiConversionMonthKey,
    // 이슈 #754 — 사용자가 업로드한 이미지/파일 바이트 누적. 스토리지 추정용.
    @Default(0) int storageBytesUsed,
  }) = _UserUsage;

  factory UserUsage.fromJson(Map<String, dynamic> json) => _$UserUsageFromJson(json);
}
