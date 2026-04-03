import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pattern_chart.dart';

class PatternRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _ref =>
      _db.collection('users').doc(_uid).collection('pattern_charts');

  Future<PatternChart> save(PatternChart chart) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final docRef = chart.id.isEmpty ? _ref.doc() : _ref.doc(chart.id);
    final saved = PatternChart(
      id: docRef.id,
      title: chart.title,
      rows: chart.rows,
      cols: chart.cols,
      mode: chart.mode,
      grid: chart.grid,
    );
    await docRef.set({
      ...saved.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return saved;
  }

  Future<void> delete(String id) async {
    await _ref.doc(id).delete();
  }

  Future<PatternChart> duplicate(PatternChart original) async {
    final copy = PatternChart(
      id: '',
      title: '${original.title} (복사)',
      rows: original.rows,
      cols: original.cols,
      mode: original.mode,
      grid: original.grid,
      narrativeText: original.narrativeText,
    );
    return save(copy);
  }

  Stream<List<PatternChart>> watchAll() {
    if (_uid.isEmpty) return const Stream.empty();
    return _ref
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PatternChart.fromJson(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<PatternChart?> get(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists) return null;
    return PatternChart.fromJson(doc.data() as Map<String, dynamic>);
  }

  Future<String> _uploadFile(File file, String folder) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final ext = file.path.split('.').last;
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users/$_uid/patterns/$folder/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await storageRef.putFile(file);
    return storageRef.getDownloadURL();
  }

  Future<PatternChart> saveImagePattern({
    required String title,
    required File imageFile,
  }) async {
    final imageUrl = await _uploadFile(imageFile, 'images');
    final docRef = _ref.doc();
    final chart = PatternChart(
      id: docRef.id,
      title: title,
      rows: 0,
      cols: 0,
      mode: ChartMode.color,
      grid: const <List<CellData>>[],
      type: PatternType.image,
      imageUrl: imageUrl,
    );
    await docRef.set({
      ...chart.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return chart;
  }

  Future<PatternChart> savePdfPattern({
    required String title,
    required File pdfFile,
  }) async {
    final pdfUrl = await _uploadFile(pdfFile, 'pdfs');
    final docRef = _ref.doc();
    final chart = PatternChart(
      id: docRef.id,
      title: title,
      rows: 0,
      cols: 0,
      mode: ChartMode.color,
      grid: const <List<CellData>>[],
      type: PatternType.pdf,
      pdfUrl: pdfUrl,
    );
    await docRef.set({
      ...chart.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return chart;
  }
}

final patternRepositoryProvider = Provider<PatternRepository>((ref) => PatternRepository());

final patternListProvider = StreamProvider<List<PatternChart>>((ref) {
  final repo = ref.watch(patternRepositoryProvider);
  return repo.watchAll();
});
