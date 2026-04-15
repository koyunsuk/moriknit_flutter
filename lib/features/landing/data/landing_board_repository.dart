import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── 모델 ─────────────────────────────────────────────────────────────────────

class LandingPost {
  final String id;
  final String title;
  final String content;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;
  final int viewCount;
  final int commentCount;
  final String type; // 'review' | 'release' | 'qa'
  final bool isNotice;
  final bool isPinned;
  final String imageUrl;

  const LandingPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.viewCount = 0,
    this.commentCount = 0,
    this.type = '',
    this.isNotice = false,
    this.isPinned = false,
    this.imageUrl = '',
  });

  factory LandingPost.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LandingPost(
      id: doc.id,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewCount: (data['viewCount'] as int?) ?? 0,
      commentCount: (data['commentCount'] as int?) ?? 0,
      type: data['type'] as String? ?? '',
      isNotice: data['isNotice'] as bool? ?? false,
      isPinned: data['isPinned'] as bool? ?? false,
      imageUrl: data['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'authorUid': authorUid,
        'authorName': authorName,
        'createdAt': Timestamp.fromDate(createdAt),
        'viewCount': viewCount,
        'commentCount': commentCount,
        'type': type,
        'isNotice': isNotice,
        'isPinned': isPinned,
        'imageUrl': imageUrl,
      };
}

class LandingComment {
  final String id;
  final String content;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;

  const LandingComment({
    required this.id,
    required this.content,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
  });

  factory LandingComment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LandingComment(
      id: doc.id,
      content: data['content'] as String? ?? '',
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'content': content,
        'authorUid': authorUid,
        'authorName': authorName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ── Repository ───────────────────────────────────────────────────────────────

class LandingBoardRepository {
  final FirebaseFirestore _db;

  LandingBoardRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // 게시글 목록 스트림 (landing_boards/{type}/posts)
  Stream<List<LandingPost>> getPosts(String type) {
    return _db
        .collection('landing_boards')
        .doc(type)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LandingPost.fromDoc).toList());
  }

  // 게시글 단건 조회
  Future<LandingPost?> getPost(String type, String postId) async {
    final doc = await _db
        .collection('landing_boards')
        .doc(type)
        .collection('posts')
        .doc(postId)
        .get();
    if (!doc.exists) return null;
    // 조회수 증가
    _db
        .collection('landing_boards')
        .doc(type)
        .collection('posts')
        .doc(postId)
        .update({'viewCount': FieldValue.increment(1)});
    return LandingPost.fromDoc(doc);
  }

  // 게시글 작성 → postId 반환
  Future<String> createPost(LandingPost post) async {
    final ref = await _db
        .collection('landing_boards')
        .doc(post.type)
        .collection('posts')
        .add(post.toMap());
    return ref.id;
  }

  // 댓글 목록 스트림 (collection: 'landing_boards/{type}/posts' or 'landing_notices')
  Stream<List<LandingComment>> getComments(
      String collection, String postId) {
    return _db
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(LandingComment.fromDoc).toList());
  }

  // 댓글 목록 스트림 — 게시판 전용 (type 기반 경로)
  Stream<List<LandingComment>> getBoardComments(
      String type, String postId) {
    return _db
        .collection('landing_boards')
        .doc(type)
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(LandingComment.fromDoc).toList());
  }

  // 댓글 작성 (generic path: collection/postId/comments)
  Future<void> addComment(
      String collection, String postId, LandingComment comment) async {
    await _db
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .add(comment.toMap());
  }

  // 게시판 댓글 작성 (type 기반 경로)
  Future<void> addBoardComment(
      String type, String postId, LandingComment comment) async {
    final postRef = _db
        .collection('landing_boards')
        .doc(type)
        .collection('posts')
        .doc(postId);
    await postRef.collection('comments').add(comment.toMap());
    await postRef.update({'commentCount': FieldValue.increment(1)});
  }

  // 공지사항 목록 스트림 (landing_notices)
  Stream<List<LandingPost>> getNotices() {
    return _db
        .collection('landing_notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final posts = snap.docs.map(LandingPost.fromDoc).toList();
          // 클라이언트 정렬: isPinned 우선, 같으면 createdAt 최신순
          posts.sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          return posts;
        });
  }

  // 공지사항 단건 조회
  Future<LandingPost?> getNotice(String noticeId) async {
    final doc =
        await _db.collection('landing_notices').doc(noticeId).get();
    if (!doc.exists) return null;
    return LandingPost.fromDoc(doc);
  }

  // 공지사항 작성 → noticeId 반환
  Future<String> createNotice(LandingPost notice) async {
    final ref =
        await _db.collection('landing_notices').add(notice.toMap());
    return ref.id;
  }

  // 공지사항 댓글 스트림
  Stream<List<LandingComment>> getNoticeComments(String noticeId) {
    return _db
        .collection('landing_notices')
        .doc(noticeId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(LandingComment.fromDoc).toList());
  }

  // 공지사항 댓글 작성
  Future<void> addNoticeComment(
      String noticeId, LandingComment comment) async {
    final noticeRef =
        _db.collection('landing_notices').doc(noticeId);
    await noticeRef.collection('comments').add(comment.toMap());
    await noticeRef.update({'commentCount': FieldValue.increment(1)});
  }
}

// ── Riverpod Provider ────────────────────────────────────────────────────────

final landingBoardRepositoryProvider =
    Provider<LandingBoardRepository>((ref) {
  return LandingBoardRepository();
});
