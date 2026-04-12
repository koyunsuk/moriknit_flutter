import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
