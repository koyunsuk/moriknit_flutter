import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> normalizeFirestoreMap(Map<String, dynamic> source) {
  return source.map((key, value) => MapEntry(key, _normalizeFirestoreValue(value)));
}

dynamic _normalizeFirestoreValue(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is Map<String, dynamic>) return normalizeFirestoreMap(value);
  if (value is Map) {
    return value.map((key, nested) => MapEntry(key.toString(), _normalizeFirestoreValue(nested)));
  }
  if (value is Iterable) return value.map(_normalizeFirestoreValue).toList();
  return value;
}
