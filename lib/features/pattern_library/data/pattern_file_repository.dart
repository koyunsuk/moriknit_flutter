import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/pattern_file.dart';

class PatternFileRepository {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(_uid).collection('pattern_files');

  /// createdAt 역순으로 파일 목록 스트림
  Stream<List<PatternFile>> watchFiles() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PatternFile.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Storage 업로드 후 Firestore 저장
  Future<PatternFile> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required PatternFileSource source,
    Map<String, dynamic>? sourceMeta,
    void Function(double)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = _sanitizeFileName(fileName);
    final storagePath = 'users/$_uid/pattern_files/${timestamp}_$sanitized';

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(contentType: mimeType);

    final uploadTask = ref.putData(bytes, metadata);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }

    await uploadTask;
    final storageUrl = await ref.getDownloadURL();

    final now = DateTime.now();
    final docRef = _col.doc();
    final file = PatternFile(
      id: docRef.id,
      fileName: fileName,
      storagePath: storagePath,
      storageUrl: storageUrl,
      mimeType: mimeType,
      fileSize: bytes.length,
      source: source,
      sourceMeta: sourceMeta,
      parseStatus: PatternParseStatus.pending,
      createdAt: now,
    );

    await docRef.set(file.toMap());
    return file;
  }

  /// AI 판독 완료 — parsedChartId + parseStatus=done 업데이트
  Future<void> markParsed(String fileId, String chartId) async {
    await _col.doc(fileId).update({
      'parsedChartId': chartId,
      'parseStatus': PatternParseStatus.done.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// AI 판독 진행 중 — parseStatus=parsing 업데이트
  Future<void> markParsing(String fileId) async {
    await _col.doc(fileId).update({
      'parseStatus': PatternParseStatus.parsing.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Storage 파일 + Firestore 문서 동시 삭제
  Future<void> delete(String fileId) async {
    final doc = await _col.doc(fileId).get();
    if (!doc.exists) return;

    final file = PatternFile.fromMap(doc.id, doc.data()!);

    await Future.wait([
      _storage.ref(file.storagePath).delete().catchError((_) {}),
      _col.doc(fileId).delete(),
    ]);
  }

  /// 파일명에서 Storage 경로에 안전한 문자열만 남김
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w.\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}
