import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_language.dart';

final uiCopyProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('ui_copy')
      .snapshots()
      .map((doc) => doc.data() ?? <String, dynamic>{});
});

String resolveUiCopy({
  required Map<String, dynamic>? data,
  required AppLanguage language,
  required String key,
  required String fallback,
}) {
  if (data == null) return fallback;
  final code = language.code;
  final localized = data['${key}_$code'];
  if (localized is String && localized.trim().isNotEmpty) return localized.trim();
  final plain = data[key];
  if (plain is String && plain.trim().isNotEmpty) return plain.trim();
  return fallback;
}
