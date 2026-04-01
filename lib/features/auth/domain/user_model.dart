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
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromJson(normalizeFirestoreMap({...data, 'uid': doc.id}));
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
  }) = _UserUsage;

  factory UserUsage.fromJson(Map<String, dynamic> json) => _$UserUsageFromJson(json);
}
