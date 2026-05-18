// 이슈 #783 후속 — 마이페이지 내 활동(내가 쓴 글/댓글/QnA) 스트림 Provider.
//
// - myPostsProvider: `posts` where uid == currentUid
// - myCommentsProvider: collectionGroup('comments') where uid == currentUid
//   (커뮤니티 댓글은 `posts/{postId}/comments` sub-collection, uid 필드 사용)
// - myQnaProvider: `landing_boards/qa/posts` where authorUid == currentUid

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../community/domain/post_model.dart';
import '../../landing/data/landing_board_repository.dart';

/// 댓글 미리보기 항목.
/// - 댓글 본문 미리보기 + 원글 link (postId) 제공
class MyCommentPreview {
  final String commentId;
  final String postId;
  final String content;
  final DateTime createdAt;

  const MyCommentPreview({
    required this.commentId,
    required this.postId,
    required this.content,
    required this.createdAt,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt.month}/${createdAt.day}';
  }
}

/// 내가 쓴 커뮤니티 글 — `posts` where uid == currentUid (최신순).
final myPostsProvider = StreamProvider<List<PostModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <PostModel>[]);
  }
  return FirebaseFirestore.instance
      .collection('posts')
      .where('uid', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map(PostModel.fromFirestore).toList());
});

/// 내가 쓴 커뮤니티 댓글 — collectionGroup('comments') where uid == currentUid.
/// 본문 미리보기 + 원글 link(postId) 포함.
final myCommentsProvider = StreamProvider<List<MyCommentPreview>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <MyCommentPreview>[]);
  }
  return FirebaseFirestore.instance
      .collectionGroup('comments')
      .where('uid', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) {
    final list = <MyCommentPreview>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      // 원글 ID — 부모 문서 ID (posts/{postId}/comments/{commentId})
      final parent = doc.reference.parent.parent;
      if (parent == null) continue;
      // 커뮤니티 댓글만 — 부모 컬렉션이 'posts' 인 경우만 (랜딩보드/공개 프로젝트 제외)
      final parentCollection = parent.parent.id;
      if (parentCollection.isNotEmpty && parentCollection != 'posts') continue;
      list.add(MyCommentPreview(
        commentId: doc.id,
        postId: parent.id,
        content: data['content'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ));
    }
    return list;
  });
});

/// 내가 쓴 QnA 문의 — `landing_boards/qa/posts` where authorUid == currentUid.
final myQnaProvider = StreamProvider<List<LandingPost>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <LandingPost>[]);
  }
  return FirebaseFirestore.instance
      .collection('landing_boards')
      .doc('qa')
      .collection('posts')
      .where('authorUid', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map(LandingPost.fromDoc).toList());
});
