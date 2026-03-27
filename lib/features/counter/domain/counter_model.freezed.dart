// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'counter_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CounterMark _$CounterMarkFromJson(Map<String, dynamic> json) {
  return _CounterMark.fromJson(json);
}

/// @nodoc
mixin _$CounterMark {
  DateTime get timestamp => throw _privateConstructorUsedError;
  int get stitchCount => throw _privateConstructorUsedError;
  int get rowCount => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CounterMarkCopyWith<CounterMark> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CounterMarkCopyWith<$Res> {
  factory $CounterMarkCopyWith(
          CounterMark value, $Res Function(CounterMark) then) =
      _$CounterMarkCopyWithImpl<$Res, CounterMark>;
  @useResult
  $Res call({DateTime timestamp, int stitchCount, int rowCount, String note});
}

/// @nodoc
class _$CounterMarkCopyWithImpl<$Res, $Val extends CounterMark>
    implements $CounterMarkCopyWith<$Res> {
  _$CounterMarkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? stitchCount = null,
    Object? rowCount = null,
    Object? note = null,
  }) {
    return _then(_value.copyWith(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      stitchCount: null == stitchCount
          ? _value.stitchCount
          : stitchCount // ignore: cast_nullable_to_non_nullable
              as int,
      rowCount: null == rowCount
          ? _value.rowCount
          : rowCount // ignore: cast_nullable_to_non_nullable
              as int,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CounterMarkImplCopyWith<$Res>
    implements $CounterMarkCopyWith<$Res> {
  factory _$$CounterMarkImplCopyWith(
          _$CounterMarkImpl value, $Res Function(_$CounterMarkImpl) then) =
      __$$CounterMarkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime timestamp, int stitchCount, int rowCount, String note});
}

/// @nodoc
class __$$CounterMarkImplCopyWithImpl<$Res>
    extends _$CounterMarkCopyWithImpl<$Res, _$CounterMarkImpl>
    implements _$$CounterMarkImplCopyWith<$Res> {
  __$$CounterMarkImplCopyWithImpl(
      _$CounterMarkImpl _value, $Res Function(_$CounterMarkImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? stitchCount = null,
    Object? rowCount = null,
    Object? note = null,
  }) {
    return _then(_$CounterMarkImpl(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      stitchCount: null == stitchCount
          ? _value.stitchCount
          : stitchCount // ignore: cast_nullable_to_non_nullable
              as int,
      rowCount: null == rowCount
          ? _value.rowCount
          : rowCount // ignore: cast_nullable_to_non_nullable
              as int,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CounterMarkImpl implements _CounterMark {
  const _$CounterMarkImpl(
      {required this.timestamp,
      this.stitchCount = 0,
      this.rowCount = 0,
      this.note = ''});

  factory _$CounterMarkImpl.fromJson(Map<String, dynamic> json) =>
      _$$CounterMarkImplFromJson(json);

  @override
  final DateTime timestamp;
  @override
  @JsonKey()
  final int stitchCount;
  @override
  @JsonKey()
  final int rowCount;
  @override
  @JsonKey()
  final String note;

  @override
  String toString() {
    return 'CounterMark(timestamp: $timestamp, stitchCount: $stitchCount, rowCount: $rowCount, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CounterMarkImpl &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.stitchCount, stitchCount) ||
                other.stitchCount == stitchCount) &&
            (identical(other.rowCount, rowCount) ||
                other.rowCount == rowCount) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, timestamp, stitchCount, rowCount, note);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CounterMarkImplCopyWith<_$CounterMarkImpl> get copyWith =>
      __$$CounterMarkImplCopyWithImpl<_$CounterMarkImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CounterMarkImplToJson(
      this,
    );
  }
}

abstract class _CounterMark implements CounterMark {
  const factory _CounterMark(
      {required final DateTime timestamp,
      final int stitchCount,
      final int rowCount,
      final String note}) = _$CounterMarkImpl;

  factory _CounterMark.fromJson(Map<String, dynamic> json) =
      _$CounterMarkImpl.fromJson;

  @override
  DateTime get timestamp;
  @override
  int get stitchCount;
  @override
  int get rowCount;
  @override
  String get note;
  @override
  @JsonKey(ignore: true)
  _$$CounterMarkImplCopyWith<_$CounterMarkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CounterModel _$CounterModelFromJson(Map<String, dynamic> json) {
  return _CounterModel.fromJson(json);
}

/// @nodoc
mixin _$CounterModel {
  String get id => throw _privateConstructorUsedError;
  String get uid => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get projectId => throw _privateConstructorUsedError;
  int get stitchCount => throw _privateConstructorUsedError;
  int get rowCount => throw _privateConstructorUsedError;
  int get targetStitchCount => throw _privateConstructorUsedError;
  int get targetRowCount => throw _privateConstructorUsedError;
  List<CounterMark> get marks => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  bool get isDirty => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CounterModelCopyWith<CounterModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CounterModelCopyWith<$Res> {
  factory $CounterModelCopyWith(
          CounterModel value, $Res Function(CounterModel) then) =
      _$CounterModelCopyWithImpl<$Res, CounterModel>;
  @useResult
  $Res call(
      {String id,
      String uid,
      String name,
      String projectId,
      int stitchCount,
      int rowCount,
      int targetStitchCount,
      int targetRowCount,
      List<CounterMark> marks,
      DateTime? createdAt,
      DateTime? updatedAt,
      bool isDirty});
}

/// @nodoc
class _$CounterModelCopyWithImpl<$Res, $Val extends CounterModel>
    implements $CounterModelCopyWith<$Res> {
  _$CounterModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? uid = null,
    Object? name = null,
    Object? projectId = null,
    Object? stitchCount = null,
    Object? rowCount = null,
    Object? targetStitchCount = null,
    Object? targetRowCount = null,
    Object? marks = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? isDirty = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: null == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String,
      stitchCount: null == stitchCount
          ? _value.stitchCount
          : stitchCount // ignore: cast_nullable_to_non_nullable
              as int,
      rowCount: null == rowCount
          ? _value.rowCount
          : rowCount // ignore: cast_nullable_to_non_nullable
              as int,
      targetStitchCount: null == targetStitchCount
          ? _value.targetStitchCount
          : targetStitchCount // ignore: cast_nullable_to_non_nullable
              as int,
      targetRowCount: null == targetRowCount
          ? _value.targetRowCount
          : targetRowCount // ignore: cast_nullable_to_non_nullable
              as int,
      marks: null == marks
          ? _value.marks
          : marks // ignore: cast_nullable_to_non_nullable
              as List<CounterMark>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isDirty: null == isDirty
          ? _value.isDirty
          : isDirty // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CounterModelImplCopyWith<$Res>
    implements $CounterModelCopyWith<$Res> {
  factory _$$CounterModelImplCopyWith(
          _$CounterModelImpl value, $Res Function(_$CounterModelImpl) then) =
      __$$CounterModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String uid,
      String name,
      String projectId,
      int stitchCount,
      int rowCount,
      int targetStitchCount,
      int targetRowCount,
      List<CounterMark> marks,
      DateTime? createdAt,
      DateTime? updatedAt,
      bool isDirty});
}

/// @nodoc
class __$$CounterModelImplCopyWithImpl<$Res>
    extends _$CounterModelCopyWithImpl<$Res, _$CounterModelImpl>
    implements _$$CounterModelImplCopyWith<$Res> {
  __$$CounterModelImplCopyWithImpl(
      _$CounterModelImpl _value, $Res Function(_$CounterModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? uid = null,
    Object? name = null,
    Object? projectId = null,
    Object? stitchCount = null,
    Object? rowCount = null,
    Object? targetStitchCount = null,
    Object? targetRowCount = null,
    Object? marks = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? isDirty = null,
  }) {
    return _then(_$CounterModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: null == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String,
      stitchCount: null == stitchCount
          ? _value.stitchCount
          : stitchCount // ignore: cast_nullable_to_non_nullable
              as int,
      rowCount: null == rowCount
          ? _value.rowCount
          : rowCount // ignore: cast_nullable_to_non_nullable
              as int,
      targetStitchCount: null == targetStitchCount
          ? _value.targetStitchCount
          : targetStitchCount // ignore: cast_nullable_to_non_nullable
              as int,
      targetRowCount: null == targetRowCount
          ? _value.targetRowCount
          : targetRowCount // ignore: cast_nullable_to_non_nullable
              as int,
      marks: null == marks
          ? _value._marks
          : marks // ignore: cast_nullable_to_non_nullable
              as List<CounterMark>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isDirty: null == isDirty
          ? _value.isDirty
          : isDirty // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CounterModelImpl implements _CounterModel {
  const _$CounterModelImpl(
      {required this.id,
      required this.uid,
      required this.name,
      this.projectId = '',
      this.stitchCount = 0,
      this.rowCount = 0,
      this.targetStitchCount = 0,
      this.targetRowCount = 0,
      final List<CounterMark> marks = const [],
      this.createdAt,
      this.updatedAt,
      this.isDirty = false})
      : _marks = marks;

  factory _$CounterModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$CounterModelImplFromJson(json);

  @override
  final String id;
  @override
  final String uid;
  @override
  final String name;
  @override
  @JsonKey()
  final String projectId;
  @override
  @JsonKey()
  final int stitchCount;
  @override
  @JsonKey()
  final int rowCount;
  @override
  @JsonKey()
  final int targetStitchCount;
  @override
  @JsonKey()
  final int targetRowCount;
  final List<CounterMark> _marks;
  @override
  @JsonKey()
  List<CounterMark> get marks {
    if (_marks is EqualUnmodifiableListView) return _marks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_marks);
  }

  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  @JsonKey()
  final bool isDirty;

  @override
  String toString() {
    return 'CounterModel(id: $id, uid: $uid, name: $name, projectId: $projectId, stitchCount: $stitchCount, rowCount: $rowCount, targetStitchCount: $targetStitchCount, targetRowCount: $targetRowCount, marks: $marks, createdAt: $createdAt, updatedAt: $updatedAt, isDirty: $isDirty)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CounterModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.stitchCount, stitchCount) ||
                other.stitchCount == stitchCount) &&
            (identical(other.rowCount, rowCount) ||
                other.rowCount == rowCount) &&
            (identical(other.targetStitchCount, targetStitchCount) ||
                other.targetStitchCount == targetStitchCount) &&
            (identical(other.targetRowCount, targetRowCount) ||
                other.targetRowCount == targetRowCount) &&
            const DeepCollectionEquality().equals(other._marks, _marks) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.isDirty, isDirty) || other.isDirty == isDirty));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      uid,
      name,
      projectId,
      stitchCount,
      rowCount,
      targetStitchCount,
      targetRowCount,
      const DeepCollectionEquality().hash(_marks),
      createdAt,
      updatedAt,
      isDirty);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CounterModelImplCopyWith<_$CounterModelImpl> get copyWith =>
      __$$CounterModelImplCopyWithImpl<_$CounterModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CounterModelImplToJson(
      this,
    );
  }
}

abstract class _CounterModel implements CounterModel {
  const factory _CounterModel(
      {required final String id,
      required final String uid,
      required final String name,
      final String projectId,
      final int stitchCount,
      final int rowCount,
      final int targetStitchCount,
      final int targetRowCount,
      final List<CounterMark> marks,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final bool isDirty}) = _$CounterModelImpl;

  factory _CounterModel.fromJson(Map<String, dynamic> json) =
      _$CounterModelImpl.fromJson;

  @override
  String get id;
  @override
  String get uid;
  @override
  String get name;
  @override
  String get projectId;
  @override
  int get stitchCount;
  @override
  int get rowCount;
  @override
  int get targetStitchCount;
  @override
  int get targetRowCount;
  @override
  List<CounterMark> get marks;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  bool get isDirty;
  @override
  @JsonKey(ignore: true)
  _$$CounterModelImplCopyWith<_$CounterModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
