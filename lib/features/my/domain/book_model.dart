import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/firestore_json.dart';

part 'book_model.freezed.dart';
part 'book_model.g.dart';

@freezed
class BookModel with _$BookModel {
  const factory BookModel({
    required String id,
    required String uid,
    required String isbn,
    @Default('') String title,
    @Default('') String author,
    @Default('') String publisher,
    @Default('') String publishYear,
    @Default('') String coverUrl,
    @Default('') String description,
    @Default('') String tableOfContents,
    @Default('') String memo,
    @Default(<String>[]) List<String> photoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool isDirty,
  }) = _BookModel;

  factory BookModel.fromJson(Map<String, dynamic> json) =>
      _$BookModelFromJson(json);

  factory BookModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookModel.fromJson(normalizeFirestoreMap({...data, 'id': doc.id}));
  }

  factory BookModel.empty({required String uid}) {
    return BookModel(
      id: '',
      uid: uid,
      isbn: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
