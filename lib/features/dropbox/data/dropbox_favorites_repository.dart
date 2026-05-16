import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 이슈 #654 — Dropbox 즐겨찾기 (사용자별 파일 경로 즐겨찾기).
///
/// Firestore 경로: users/{uid}/dropbox_favorites/{fileId}
/// - fileId: dropboxPath의 sanitized 형태 (= 슬래시·점·콜론 등을 underscore 변환)
class DropboxFavoritesRepository {
  DropboxFavoritesRepository();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _ref => _db
      .collection('users')
      .doc(_uid)
      .collection('dropbox_favorites');

  /// dropbox path를 Firestore 문서 ID로 안전하게 변환.
  static String pathToId(String dropboxPath) {
    if (dropboxPath.isEmpty) return 'root';
    return dropboxPath.replaceAll(RegExp(r'[\\/.:#\[\]]'), '_');
  }

  /// 즐겨찾기 토글. 추가 시 true, 제거 시 false 반환.
  /// isFolder: 폴더 단위 즐겨찾기 구분 (목록 표시 + 진입 시 활용)
  Future<bool> toggle({
    required String dropboxPath,
    required String name,
    bool isFolder = false,
  }) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    final id = pathToId(dropboxPath);
    final doc = _ref.doc(id);
    final snap = await doc.get();
    if (snap.exists) {
      await doc.delete();
      return false;
    }
    await doc.set({
      'path': dropboxPath,
      'name': name,
      'isFolder': isFolder,
      'addedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// 즐겨찾기 목록 스트림 (path 집합).
  /// 이슈 #722 — Stream.empty()는 emit 안 됨(무한로딩). Stream.value({})로 교체.
  Stream<Set<String>> watchFavoritePaths() {
    if (_uid.isEmpty) return Stream.value(<String>{});
    return _ref.snapshots().map((snap) {
      return snap.docs
          .map((d) => (d.data()['path'] as String?) ?? '')
          .where((p) => p.isNotEmpty)
          .toSet();
    });
  }

  /// 즐겨찾기 단건 확인.
  Future<bool> isFavorite(String dropboxPath) async {
    if (_uid.isEmpty) return false;
    final snap = await _ref.doc(pathToId(dropboxPath)).get();
    return snap.exists;
  }
}

final dropboxFavoritesRepositoryProvider =
    Provider<DropboxFavoritesRepository>((ref) {
  return DropboxFavoritesRepository();
});

final dropboxFavoritePathsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(dropboxFavoritesRepositoryProvider).watchFavoritePaths();
});
