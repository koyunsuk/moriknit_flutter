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

  const AppConfig({
    this.maintenanceNotice = '',
    this.noticeType = 'banner',
    this.communityWriteEnabled = true,
    this.sellerSubmissionEnabled = true,
    this.encyclopediaSuggestionEnabled = true,
  });
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
    return AppConfig(
      maintenanceNotice: data['maintenanceNotice'] as String? ?? '',
      noticeType: data['noticeType'] as String? ?? 'banner',
      communityWriteEnabled: data['communityWriteEnabled'] as bool? ?? true,
      sellerSubmissionEnabled: data['sellerSubmissionEnabled'] as bool? ?? true,
      encyclopediaSuggestionEnabled:
          data['encyclopediaSuggestionEnabled'] as bool? ?? true,
    );
  });
});
