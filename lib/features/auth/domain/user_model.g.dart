// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? '',
      photoURL: json['photoURL'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      subscription: json['subscription'] == null
          ? const UserSubscription()
          : UserSubscription.fromJson(
              json['subscription'] as Map<String, dynamic>),
      usage: json['usage'] == null
          ? const UserUsage()
          : UserUsage.fromJson(json['usage'] as Map<String, dynamic>),
      locale: json['locale'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      lastActiveAt: json['lastActiveAt'] == null
          ? null
          : DateTime.parse(json['lastActiveAt'] as String),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'email': instance.email,
      'displayName': instance.displayName,
      'photoURL': instance.photoURL,
      'bio': instance.bio,
      'subscription': instance.subscription,
      'usage': instance.usage,
      'locale': instance.locale,
      'createdAt': instance.createdAt?.toIso8601String(),
      'lastActiveAt': instance.lastActiveAt?.toIso8601String(),
    };

_$UserSubscriptionImpl _$$UserSubscriptionImplFromJson(
        Map<String, dynamic> json) =>
    _$UserSubscriptionImpl(
      planId: json['planId'] as String? ?? 'free',
      status: json['status'] as String? ?? 'active',
      currentPeriodStart: json['currentPeriodStart'] == null
          ? null
          : DateTime.parse(json['currentPeriodStart'] as String),
      currentPeriodEnd: json['currentPeriodEnd'] == null
          ? null
          : DateTime.parse(json['currentPeriodEnd'] as String),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      pgSubscriptionId: json['pgSubscriptionId'] as String?,
      trialEndAt: json['trialEndAt'] == null
          ? null
          : DateTime.parse(json['trialEndAt'] as String),
    );

Map<String, dynamic> _$$UserSubscriptionImplToJson(
        _$UserSubscriptionImpl instance) =>
    <String, dynamic>{
      'planId': instance.planId,
      'status': instance.status,
      'currentPeriodStart': instance.currentPeriodStart?.toIso8601String(),
      'currentPeriodEnd': instance.currentPeriodEnd?.toIso8601String(),
      'cancelAtPeriodEnd': instance.cancelAtPeriodEnd,
      'pgSubscriptionId': instance.pgSubscriptionId,
      'trialEndAt': instance.trialEndAt?.toIso8601String(),
    };

_$UserUsageImpl _$$UserUsageImplFromJson(Map<String, dynamic> json) =>
    _$UserUsageImpl(
      swatchCount: (json['swatchCount'] as num?)?.toInt() ?? 0,
      projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      counterCount: (json['counterCount'] as num?)?.toInt() ?? 0,
      editorSaveCount: (json['editorSaveCount'] as num?)?.toInt() ?? 0,
      postsThisMonth: (json['postsThisMonth'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$UserUsageImplToJson(_$UserUsageImpl instance) =>
    <String, dynamic>{
      'swatchCount': instance.swatchCount,
      'projectCount': instance.projectCount,
      'counterCount': instance.counterCount,
      'editorSaveCount': instance.editorSaveCount,
      'postsThisMonth': instance.postsThisMonth,
    };
