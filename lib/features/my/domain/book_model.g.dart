// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookModelImpl _$$BookModelImplFromJson(Map<String, dynamic> json) =>
    _$BookModelImpl(
      id: json['id'] as String,
      uid: json['uid'] as String,
      isbn: json['isbn'] as String,
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      publishYear: json['publishYear'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tableOfContents: json['tableOfContents'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isDirty: json['isDirty'] as bool? ?? false,
    );

Map<String, dynamic> _$$BookModelImplToJson(_$BookModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'isbn': instance.isbn,
      'title': instance.title,
      'author': instance.author,
      'publisher': instance.publisher,
      'publishYear': instance.publishYear,
      'coverUrl': instance.coverUrl,
      'description': instance.description,
      'tableOfContents': instance.tableOfContents,
      'memo': instance.memo,
      'photoUrls': instance.photoUrls,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isDirty': instance.isDirty,
    };
