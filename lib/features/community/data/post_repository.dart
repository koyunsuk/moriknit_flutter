import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/post_model.dart';

class PostRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  Stream<List<PostModel>> watchPosts({String? category}) {
    final aliases = _categoryAliases(category);
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      final all = snap.docs.map(PostModel.fromFirestore).toList();
      if (aliases.isEmpty) return all;
      return all.where((p) => aliases.contains(p.category)).toList();
    });
  }

  List<String> _categoryAliases(String? category) {
    switch (category) {
      case null:
      case '':
      case 'all':
      case '전체':
      case 'All':
        return const <String>[];
      case 'showcase':
      case '작품':
      case 'Showcase':
        return const <String>['showcase', '작품', 'Showcase'];
      case 'questions':
      case '질문':
      case 'Questions':
        return const <String>['questions', '질문', 'Questions'];
      case 'pattern_share':
      case '도안공유':
      case 'Pattern Share':
        return const <String>[
          'pattern_share',
          '도안공유',
          'Pattern Share',
        ];
      default:
        return <String>[category];
    }
  }

  Future<List<String>> uploadImages(
    String uid,
    List<Uint8List> imageBytesList,
  ) async {
    final urls = <String>[];
    for (final bytes in imageBytesList) {
      final fileName =
          'community/$uid/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
      final ref = _storage.ref(fileName);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<List<String>> uploadFiles(
    String uid,
    List<Map<String, dynamic>> files,
  ) async {
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = file['bytes'] as Uint8List;
      final name = file['name'] as String? ?? 'file_$i';
      final ext = name.contains('.') ? name.split('.').last : 'bin';
      final path = 'community/$uid/files/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'application/octet-stream'));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> createPost(PostModel post) async {
    await _posts.add({
      ...post.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
  }

  Future<void> updatePost(String postId, {required String title, required String content, List<String>? imageUrls}) async {
    final data = <String, dynamic>{
      'title': title,
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (imageUrls != null) data['imageUrls'] = imageUrls;
    await _posts.doc(postId).update(data);
  }

  Future<void> toggleLike(String postId, String uid) async {
    final doc = await _posts.doc(postId).get();
    final likedBy = List<String>.from((doc.data()?['likedBy'] as List?) ?? []);
    if (likedBy.contains(uid)) {
      await _posts.doc(postId).update({
        'likedBy': FieldValue.arrayRemove([uid]),
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await _posts.doc(postId).update({
        'likedBy': FieldValue.arrayUnion([uid]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }
}
