import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kYoutubeFallback = 'https://www.youtube.com/@moriknit';
const String _kInstagramFallback = 'https://instagram.com/moriknit_official';
const String _kBlogFallback = 'https://blog.naver.com/moriknit';

class SocialIntegrations {
  final String youtube;
  final String instagram;
  final String blog;
  final String kakao;

  const SocialIntegrations({
    this.youtube = '',
    this.instagram = '',
    this.blog = '',
    this.kakao = '',
  });

  String get youtubeUrl => youtube.isNotEmpty ? youtube : _kYoutubeFallback;
  String get instagramUrl => instagram.isNotEmpty ? instagram : _kInstagramFallback;
  String get blogUrl => blog.isNotEmpty ? blog : _kBlogFallback;
}

final socialIntegrationsProvider = StreamProvider<SocialIntegrations>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('social_integrations')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return const SocialIntegrations();
    final data = snap.data()!;
    return SocialIntegrations(
      youtube: data['youtube'] as String? ?? '',
      instagram: data['instagram'] as String? ?? '',
      blog: data['blog'] as String? ?? '',
      kakao: data['kakao'] as String? ?? '',
    );
  });
});

class AppConfig {
  final String maintenanceNotice;
  final String noticeType; // 'banner' | 'popup' | 'push'
  final bool communityWriteEnabled;
  final bool sellerSubmissionEnabled;
  final bool encyclopediaSuggestionEnabled;
  // ── 어드민 입력 팝업 (이슈 #812) ──────────────────────────────────────────
  final bool popupEnabled;
  final String popupTitle;
  final String popupMessage;
  /// 이슈 #817 — 팝업 본문 리치 텍스트 (flutter_quill Delta JSON).
  /// 비어 있으면 popupMessage(plain text) fallback 렌더링.
  final String popupBodyDelta;
  final String popupLinkUrl;
  /// 이슈 #835 — 팝업/배너 배경 이미지 URL (선택).
  /// 비어 있으면 기본 그라데이션 헤더 유지.
  final String backgroundImageUrl;
  /// 팝업 고유 식별자(저장 시각 기반). 변경되면 일회성 노출 상태 초기화.
  final String popupId;

  const AppConfig({
    this.maintenanceNotice = '',
    this.noticeType = 'banner',
    this.communityWriteEnabled = true,
    this.sellerSubmissionEnabled = true,
    this.encyclopediaSuggestionEnabled = true,
    this.popupEnabled = false,
    this.popupTitle = '',
    this.popupMessage = '',
    this.popupBodyDelta = '',
    this.popupLinkUrl = '',
    this.backgroundImageUrl = '',
    this.popupId = '',
  });

  /// 새 팝업이 켜져 있는지 (어드민 신규 경로).
  bool get hasAdminPopup =>
      popupEnabled && (popupTitle.isNotEmpty || popupMessage.isNotEmpty || popupBodyDelta.isNotEmpty);
}

final mockupImagesProvider = StreamProvider<Map<String, String>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('mockup_images')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return <String, String>{};
    final data = snap.data()!;
    return {for (final e in data.entries) e.key: (e.value as String? ?? '')};
  });
});

final appConfigProvider = StreamProvider<AppConfig>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('admin_support')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return const AppConfig();
    final data = snap.data()!;
    final popupTitle = data['popupTitle'] as String? ?? '';
    final popupMessage = data['popupMessage'] as String? ?? '';
    final popupBodyDelta = data['popupBodyDelta'] as String? ?? '';
    final popupLinkUrl = data['popupLinkUrl'] as String? ?? '';
    final popupEnabled = data['popupEnabled'] as bool? ?? false;
    // popupId: 어드민이 저장할 때 갱신되는 updatedAt 기반. 동일 팝업 재노출 방지용.
    // updatedAt이 없으면 내용 hash로 대체 (옛 저장 데이터 호환).
    final updatedAt = data['updatedAt'];
    String popupId = '';
    if (updatedAt is Timestamp) {
      popupId = updatedAt.millisecondsSinceEpoch.toString();
    } else if (popupEnabled) {
      popupId = '$popupTitle|$popupMessage|$popupLinkUrl'.hashCode.toString();
    }
    return AppConfig(
      maintenanceNotice: data['maintenanceNotice'] as String? ?? '',
      noticeType: data['noticeType'] as String? ?? 'banner',
      communityWriteEnabled: data['communityWriteEnabled'] as bool? ?? true,
      sellerSubmissionEnabled: data['sellerSubmissionEnabled'] as bool? ?? true,
      encyclopediaSuggestionEnabled:
          data['encyclopediaSuggestionEnabled'] as bool? ?? true,
      popupEnabled: popupEnabled,
      popupTitle: popupTitle,
      popupMessage: popupMessage,
      popupBodyDelta: popupBodyDelta,
      popupLinkUrl: popupLinkUrl,
      backgroundImageUrl: data['backgroundImageUrl'] as String? ?? '',
      popupId: popupId,
    );
  });
});
