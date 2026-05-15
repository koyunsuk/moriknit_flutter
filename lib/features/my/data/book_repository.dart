import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/book_model.dart';

class BookRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _booksRef =>
      _db.collection('users').doc(_uid).collection('books');

  Future<BookModel> createBook(BookModel book) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final prepared = book.copyWith(updatedAt: DateTime.now());

    final docRef =
        book.id.isEmpty ? _booksRef.doc() : _booksRef.doc(book.id);

    await docRef.set({
      ...prepared.toJson(),
      'id': docRef.id,
      'uid': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDirty': false,
    });

    return prepared.copyWith(id: docRef.id, isDirty: false);
  }

  Stream<List<BookModel>> watchBooks() {
    if (_uid.isEmpty) return Stream.value([]);
    return _booksRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BookModel.fromFirestore(doc)).toList());
  }

  Future<List<BookModel>> getBooks() async {
    if (_uid.isEmpty) return [];
    final snapshot =
        await _booksRef.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => BookModel.fromFirestore(doc))
        .toList();
  }

  Future<BookModel?> getBook(String id) async {
    if (_uid.isEmpty || id.isEmpty) return null;
    final doc = await _booksRef.doc(id).get();
    if (!doc.exists) return null;
    return BookModel.fromFirestore(doc);
  }

  Future<BookModel> updateBook(BookModel book) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final updated = book.copyWith(updatedAt: DateTime.now());

    await _booksRef.doc(book.id).update({
      ...updated.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDirty': false,
    });
    return updated.copyWith(isDirty: false);
  }

  Future<void> deleteBook(String id) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    try {
      await _booksRef.doc(id).delete().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw Exception('인터넷 연결을 확인해 주세요');
    } catch (e) {
      debugPrint('[deleteBook] error: $e');
      rethrow;
    }
  }
}
