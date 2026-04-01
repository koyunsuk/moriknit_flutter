// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  String get uid => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String get photoURL => throw _privateConstructorUsedError;
  String get bio => throw _privateConstructorUsedError;
  UserSubscription get subscription => throw _privateConstructorUsedError;
  UserUsage get usage => throw _privateConstructorUsedError;
  String? get locale => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get lastActiveAt => throw _privateConstructorUsedError;
  int get moriBalance => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call(
      {String uid,
      String email,
      String displayName,
      String photoURL,
      String bio,
      UserSubscription subscription,
      UserUsage usage,
      String? locale,
      DateTime? createdAt,
      DateTime? lastActiveAt,
      int moriBalance});

  $UserSubscriptionCopyWith<$Res> get subscription;
  $UserUsageCopyWith<$Res> get usage;
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? displayName = null,
    Object? photoURL = null,
    Object? bio = null,
    Object? subscription = null,
    Object? usage = null,
    Object? locale = freezed,
    Object? createdAt = freezed,
    Object? lastActiveAt = freezed,
    Object? moriBalance = null,
  }) {
    return _then(_value.copyWith(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      photoURL: null == photoURL
          ? _value.photoURL
          : photoURL // ignore: cast_nullable_to_non_nullable
              as String,
      bio: null == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String,
      subscription: null == subscription
          ? _value.subscription
          : subscription // ignore: cast_nullable_to_non_nullable
              as UserSubscription,
      usage: null == usage
          ? _value.usage
          : usage // ignore: cast_nullable_to_non_nullable
              as UserUsage,
      locale: freezed == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastActiveAt: freezed == lastActiveAt
          ? _value.lastActiveAt
          : lastActiveAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      moriBalance: null == moriBalance
          ? _value.moriBalance
          : moriBalance // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $UserSubscriptionCopyWith<$Res> get subscription {
    return $UserSubscriptionCopyWith<$Res>(_value.subscription, (value) {
      return _then(_value.copyWith(subscription: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $UserUsageCopyWith<$Res> get usage {
    return $UserUsageCopyWith<$Res>(_value.usage, (value) {
      return _then(_value.copyWith(usage: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
          _$UserModelImpl value, $Res Function(_$UserModelImpl) then) =
      __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String uid,
      String email,
      String displayName,
      String photoURL,
      String bio,
      UserSubscription subscription,
      UserUsage usage,
      String? locale,
      DateTime? createdAt,
      DateTime? lastActiveAt,
      int moriBalance});

  @override
  $UserSubscriptionCopyWith<$Res> get subscription;
  @override
  $UserUsageCopyWith<$Res> get usage;
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
      _$UserModelImpl _value, $Res Function(_$UserModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? displayName = null,
    Object? photoURL = null,
    Object? bio = null,
    Object? subscription = null,
    Object? usage = null,
    Object? locale = freezed,
    Object? createdAt = freezed,
    Object? lastActiveAt = freezed,
    Object? moriBalance = null,
  }) {
    return _then(_$UserModelImpl(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      photoURL: null == photoURL
          ? _value.photoURL
          : photoURL // ignore: cast_nullable_to_non_nullable
              as String,
      bio: null == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String,
      subscription: null == subscription
          ? _value.subscription
          : subscription // ignore: cast_nullable_to_non_nullable
              as UserSubscription,
      usage: null == usage
          ? _value.usage
          : usage // ignore: cast_nullable_to_non_nullable
              as UserUsage,
      locale: freezed == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastActiveAt: freezed == lastActiveAt
          ? _value.lastActiveAt
          : lastActiveAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      moriBalance: null == moriBalance
          ? _value.moriBalance
          : moriBalance // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserModelImpl implements _UserModel {
  const _$UserModelImpl(
      {required this.uid,
      required this.email,
      this.displayName = '',
      this.photoURL = '',
      this.bio = '',
      this.subscription = const UserSubscription(),
      this.usage = const UserUsage(),
      this.locale,
      this.createdAt,
      this.lastActiveAt,
      this.moriBalance = 10000});

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  @override
  final String uid;
  @override
  final String email;
  @override
  @JsonKey()
  final String displayName;
  @override
  @JsonKey()
  final String photoURL;
  @override
  @JsonKey()
  final String bio;
  @override
  @JsonKey()
  final UserSubscription subscription;
  @override
  @JsonKey()
  final UserUsage usage;
  @override
  final String? locale;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? lastActiveAt;
  @override
  @JsonKey()
  final int moriBalance;

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, photoURL: $photoURL, bio: $bio, subscription: $subscription, usage: $usage, locale: $locale, createdAt: $createdAt, lastActiveAt: $lastActiveAt, moriBalance: $moriBalance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoURL, photoURL) ||
                other.photoURL == photoURL) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.subscription, subscription) ||
                other.subscription == subscription) &&
            (identical(other.usage, usage) || other.usage == usage) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastActiveAt, lastActiveAt) ||
                other.lastActiveAt == lastActiveAt) &&
            (identical(other.moriBalance, moriBalance) ||
                other.moriBalance == moriBalance));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      uid,
      email,
      displayName,
      photoURL,
      bio,
      subscription,
      usage,
      locale,
      createdAt,
      lastActiveAt,
      moriBalance);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(
      this,
    );
  }
}

abstract class _UserModel implements UserModel {
  const factory _UserModel(
      {required final String uid,
      required final String email,
      final String displayName,
      final String photoURL,
      final String bio,
      final UserSubscription subscription,
      final UserUsage usage,
      final String? locale,
      final DateTime? createdAt,
      final DateTime? lastActiveAt,
      final int moriBalance}) = _$UserModelImpl;

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override
  String get uid;
  @override
  String get email;
  @override
  String get displayName;
  @override
  String get photoURL;
  @override
  String get bio;
  @override
  UserSubscription get subscription;
  @override
  UserUsage get usage;
  @override
  String? get locale;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get lastActiveAt;
  @override
  int get moriBalance;
  @override
  @JsonKey(ignore: true)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UserSubscription _$UserSubscriptionFromJson(Map<String, dynamic> json) {
  return _UserSubscription.fromJson(json);
}

/// @nodoc
mixin _$UserSubscription {
  String get planId => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime? get currentPeriodStart => throw _privateConstructorUsedError;
  DateTime? get currentPeriodEnd => throw _privateConstructorUsedError;
  bool get cancelAtPeriodEnd => throw _privateConstructorUsedError;
  String? get pgSubscriptionId => throw _privateConstructorUsedError;
  DateTime? get trialEndAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserSubscriptionCopyWith<UserSubscription> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserSubscriptionCopyWith<$Res> {
  factory $UserSubscriptionCopyWith(
          UserSubscription value, $Res Function(UserSubscription) then) =
      _$UserSubscriptionCopyWithImpl<$Res, UserSubscription>;
  @useResult
  $Res call(
      {String planId,
      String status,
      DateTime? currentPeriodStart,
      DateTime? currentPeriodEnd,
      bool cancelAtPeriodEnd,
      String? pgSubscriptionId,
      DateTime? trialEndAt});
}

/// @nodoc
class _$UserSubscriptionCopyWithImpl<$Res, $Val extends UserSubscription>
    implements $UserSubscriptionCopyWith<$Res> {
  _$UserSubscriptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? planId = null,
    Object? status = null,
    Object? currentPeriodStart = freezed,
    Object? currentPeriodEnd = freezed,
    Object? cancelAtPeriodEnd = null,
    Object? pgSubscriptionId = freezed,
    Object? trialEndAt = freezed,
  }) {
    return _then(_value.copyWith(
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      currentPeriodStart: freezed == currentPeriodStart
          ? _value.currentPeriodStart
          : currentPeriodStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      currentPeriodEnd: freezed == currentPeriodEnd
          ? _value.currentPeriodEnd
          : currentPeriodEnd // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelAtPeriodEnd: null == cancelAtPeriodEnd
          ? _value.cancelAtPeriodEnd
          : cancelAtPeriodEnd // ignore: cast_nullable_to_non_nullable
              as bool,
      pgSubscriptionId: freezed == pgSubscriptionId
          ? _value.pgSubscriptionId
          : pgSubscriptionId // ignore: cast_nullable_to_non_nullable
              as String?,
      trialEndAt: freezed == trialEndAt
          ? _value.trialEndAt
          : trialEndAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserSubscriptionImplCopyWith<$Res>
    implements $UserSubscriptionCopyWith<$Res> {
  factory _$$UserSubscriptionImplCopyWith(_$UserSubscriptionImpl value,
          $Res Function(_$UserSubscriptionImpl) then) =
      __$$UserSubscriptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String planId,
      String status,
      DateTime? currentPeriodStart,
      DateTime? currentPeriodEnd,
      bool cancelAtPeriodEnd,
      String? pgSubscriptionId,
      DateTime? trialEndAt});
}

/// @nodoc
class __$$UserSubscriptionImplCopyWithImpl<$Res>
    extends _$UserSubscriptionCopyWithImpl<$Res, _$UserSubscriptionImpl>
    implements _$$UserSubscriptionImplCopyWith<$Res> {
  __$$UserSubscriptionImplCopyWithImpl(_$UserSubscriptionImpl _value,
      $Res Function(_$UserSubscriptionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? planId = null,
    Object? status = null,
    Object? currentPeriodStart = freezed,
    Object? currentPeriodEnd = freezed,
    Object? cancelAtPeriodEnd = null,
    Object? pgSubscriptionId = freezed,
    Object? trialEndAt = freezed,
  }) {
    return _then(_$UserSubscriptionImpl(
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      currentPeriodStart: freezed == currentPeriodStart
          ? _value.currentPeriodStart
          : currentPeriodStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      currentPeriodEnd: freezed == currentPeriodEnd
          ? _value.currentPeriodEnd
          : currentPeriodEnd // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelAtPeriodEnd: null == cancelAtPeriodEnd
          ? _value.cancelAtPeriodEnd
          : cancelAtPeriodEnd // ignore: cast_nullable_to_non_nullable
              as bool,
      pgSubscriptionId: freezed == pgSubscriptionId
          ? _value.pgSubscriptionId
          : pgSubscriptionId // ignore: cast_nullable_to_non_nullable
              as String?,
      trialEndAt: freezed == trialEndAt
          ? _value.trialEndAt
          : trialEndAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserSubscriptionImpl implements _UserSubscription {
  const _$UserSubscriptionImpl(
      {this.planId = 'free',
      this.status = 'active',
      this.currentPeriodStart,
      this.currentPeriodEnd,
      this.cancelAtPeriodEnd = false,
      this.pgSubscriptionId,
      this.trialEndAt});

  factory _$UserSubscriptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserSubscriptionImplFromJson(json);

  @override
  @JsonKey()
  final String planId;
  @override
  @JsonKey()
  final String status;
  @override
  final DateTime? currentPeriodStart;
  @override
  final DateTime? currentPeriodEnd;
  @override
  @JsonKey()
  final bool cancelAtPeriodEnd;
  @override
  final String? pgSubscriptionId;
  @override
  final DateTime? trialEndAt;

  @override
  String toString() {
    return 'UserSubscription(planId: $planId, status: $status, currentPeriodStart: $currentPeriodStart, currentPeriodEnd: $currentPeriodEnd, cancelAtPeriodEnd: $cancelAtPeriodEnd, pgSubscriptionId: $pgSubscriptionId, trialEndAt: $trialEndAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserSubscriptionImpl &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.currentPeriodStart, currentPeriodStart) ||
                other.currentPeriodStart == currentPeriodStart) &&
            (identical(other.currentPeriodEnd, currentPeriodEnd) ||
                other.currentPeriodEnd == currentPeriodEnd) &&
            (identical(other.cancelAtPeriodEnd, cancelAtPeriodEnd) ||
                other.cancelAtPeriodEnd == cancelAtPeriodEnd) &&
            (identical(other.pgSubscriptionId, pgSubscriptionId) ||
                other.pgSubscriptionId == pgSubscriptionId) &&
            (identical(other.trialEndAt, trialEndAt) ||
                other.trialEndAt == trialEndAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      planId,
      status,
      currentPeriodStart,
      currentPeriodEnd,
      cancelAtPeriodEnd,
      pgSubscriptionId,
      trialEndAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserSubscriptionImplCopyWith<_$UserSubscriptionImpl> get copyWith =>
      __$$UserSubscriptionImplCopyWithImpl<_$UserSubscriptionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserSubscriptionImplToJson(
      this,
    );
  }
}

abstract class _UserSubscription implements UserSubscription {
  const factory _UserSubscription(
      {final String planId,
      final String status,
      final DateTime? currentPeriodStart,
      final DateTime? currentPeriodEnd,
      final bool cancelAtPeriodEnd,
      final String? pgSubscriptionId,
      final DateTime? trialEndAt}) = _$UserSubscriptionImpl;

  factory _UserSubscription.fromJson(Map<String, dynamic> json) =
      _$UserSubscriptionImpl.fromJson;

  @override
  String get planId;
  @override
  String get status;
  @override
  DateTime? get currentPeriodStart;
  @override
  DateTime? get currentPeriodEnd;
  @override
  bool get cancelAtPeriodEnd;
  @override
  String? get pgSubscriptionId;
  @override
  DateTime? get trialEndAt;
  @override
  @JsonKey(ignore: true)
  _$$UserSubscriptionImplCopyWith<_$UserSubscriptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UserUsage _$UserUsageFromJson(Map<String, dynamic> json) {
  return _UserUsage.fromJson(json);
}

/// @nodoc
mixin _$UserUsage {
  int get swatchCount => throw _privateConstructorUsedError;
  int get projectCount => throw _privateConstructorUsedError;
  int get counterCount => throw _privateConstructorUsedError;
  int get editorSaveCount => throw _privateConstructorUsedError;
  int get postsThisMonth => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserUsageCopyWith<UserUsage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserUsageCopyWith<$Res> {
  factory $UserUsageCopyWith(UserUsage value, $Res Function(UserUsage) then) =
      _$UserUsageCopyWithImpl<$Res, UserUsage>;
  @useResult
  $Res call(
      {int swatchCount,
      int projectCount,
      int counterCount,
      int editorSaveCount,
      int postsThisMonth});
}

/// @nodoc
class _$UserUsageCopyWithImpl<$Res, $Val extends UserUsage>
    implements $UserUsageCopyWith<$Res> {
  _$UserUsageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? swatchCount = null,
    Object? projectCount = null,
    Object? counterCount = null,
    Object? editorSaveCount = null,
    Object? postsThisMonth = null,
  }) {
    return _then(_value.copyWith(
      swatchCount: null == swatchCount
          ? _value.swatchCount
          : swatchCount // ignore: cast_nullable_to_non_nullable
              as int,
      projectCount: null == projectCount
          ? _value.projectCount
          : projectCount // ignore: cast_nullable_to_non_nullable
              as int,
      counterCount: null == counterCount
          ? _value.counterCount
          : counterCount // ignore: cast_nullable_to_non_nullable
              as int,
      editorSaveCount: null == editorSaveCount
          ? _value.editorSaveCount
          : editorSaveCount // ignore: cast_nullable_to_non_nullable
              as int,
      postsThisMonth: null == postsThisMonth
          ? _value.postsThisMonth
          : postsThisMonth // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserUsageImplCopyWith<$Res>
    implements $UserUsageCopyWith<$Res> {
  factory _$$UserUsageImplCopyWith(
          _$UserUsageImpl value, $Res Function(_$UserUsageImpl) then) =
      __$$UserUsageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int swatchCount,
      int projectCount,
      int counterCount,
      int editorSaveCount,
      int postsThisMonth});
}

/// @nodoc
class __$$UserUsageImplCopyWithImpl<$Res>
    extends _$UserUsageCopyWithImpl<$Res, _$UserUsageImpl>
    implements _$$UserUsageImplCopyWith<$Res> {
  __$$UserUsageImplCopyWithImpl(
      _$UserUsageImpl _value, $Res Function(_$UserUsageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? swatchCount = null,
    Object? projectCount = null,
    Object? counterCount = null,
    Object? editorSaveCount = null,
    Object? postsThisMonth = null,
  }) {
    return _then(_$UserUsageImpl(
      swatchCount: null == swatchCount
          ? _value.swatchCount
          : swatchCount // ignore: cast_nullable_to_non_nullable
              as int,
      projectCount: null == projectCount
          ? _value.projectCount
          : projectCount // ignore: cast_nullable_to_non_nullable
              as int,
      counterCount: null == counterCount
          ? _value.counterCount
          : counterCount // ignore: cast_nullable_to_non_nullable
              as int,
      editorSaveCount: null == editorSaveCount
          ? _value.editorSaveCount
          : editorSaveCount // ignore: cast_nullable_to_non_nullable
              as int,
      postsThisMonth: null == postsThisMonth
          ? _value.postsThisMonth
          : postsThisMonth // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserUsageImpl implements _UserUsage {
  const _$UserUsageImpl(
      {this.swatchCount = 0,
      this.projectCount = 0,
      this.counterCount = 0,
      this.editorSaveCount = 0,
      this.postsThisMonth = 0});

  factory _$UserUsageImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserUsageImplFromJson(json);

  @override
  @JsonKey()
  final int swatchCount;
  @override
  @JsonKey()
  final int projectCount;
  @override
  @JsonKey()
  final int counterCount;
  @override
  @JsonKey()
  final int editorSaveCount;
  @override
  @JsonKey()
  final int postsThisMonth;

  @override
  String toString() {
    return 'UserUsage(swatchCount: $swatchCount, projectCount: $projectCount, counterCount: $counterCount, editorSaveCount: $editorSaveCount, postsThisMonth: $postsThisMonth)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserUsageImpl &&
            (identical(other.swatchCount, swatchCount) ||
                other.swatchCount == swatchCount) &&
            (identical(other.projectCount, projectCount) ||
                other.projectCount == projectCount) &&
            (identical(other.counterCount, counterCount) ||
                other.counterCount == counterCount) &&
            (identical(other.editorSaveCount, editorSaveCount) ||
                other.editorSaveCount == editorSaveCount) &&
            (identical(other.postsThisMonth, postsThisMonth) ||
                other.postsThisMonth == postsThisMonth));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, swatchCount, projectCount,
      counterCount, editorSaveCount, postsThisMonth);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserUsageImplCopyWith<_$UserUsageImpl> get copyWith =>
      __$$UserUsageImplCopyWithImpl<_$UserUsageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserUsageImplToJson(
      this,
    );
  }
}

abstract class _UserUsage implements UserUsage {
  const factory _UserUsage(
      {final int swatchCount,
      final int projectCount,
      final int counterCount,
      final int editorSaveCount,
      final int postsThisMonth}) = _$UserUsageImpl;

  factory _UserUsage.fromJson(Map<String, dynamic> json) =
      _$UserUsageImpl.fromJson;

  @override
  int get swatchCount;
  @override
  int get projectCount;
  @override
  int get counterCount;
  @override
  int get editorSaveCount;
  @override
  int get postsThisMonth;
  @override
  @JsonKey(ignore: true)
  _$$UserUsageImplCopyWith<_$UserUsageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
