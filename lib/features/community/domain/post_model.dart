import 'package:cloud_firestore/cloud_firestore.dart';

/// 본문 저장 포맷.
/// - `plain`: 기존 게시글 호환용 일반 텍스트
/// - `quill`: flutter_quill Delta JSON 문자열 (이슈 #747)
class PostBodyFormat {
  static const String plain = 'plain';
  static const String quill = 'quill';
}

class PostModel {
  final String id;
  final String uid;
  final String authorName;
  /// 이슈 #771 — 작성자 핸들(@아이디) 스냅샷. 작성 시점의 users/{uid}.handle.
  final String authorHandle;
  final String authorPhotoUrl;
  /// #761 — 작성자 등급 스냅샷. 'free' | 'pro' | 'business'. 작성 시점의 users/{uid}.subscription.planId.
  /// 추후 등급 변경되어도 게시글에는 작성 당시 등급 유지.
  final String authorTier;
  final String category;
  final String title;
  final String content;
  /// 본문 저장 포맷 (이슈 #747). `plain` 또는 `quill`. 기본 `plain` (기존 글 호환).
  final String bodyFormat;
  /// `bodyFormat == quill` 일 때 Delta JSON 문자열. 기존 plain 게시글은 빈 문자열.
  final String bodyDelta;
  final List<String> imageUrls;
  final List<String> attachmentUrls;
  final List<String> attachmentNames;
  /// 본문에 첨부된 유튜브 링크 (이슈 #748). 게시글 상세 화면에서 임베드 카드로 렌더링.
  final List<String> youtubeUrls;
  final int likeCount;
  final int commentCount;
  final List<String> likedBy;
  final DateTime createdAt;
  /// 작성 시점의 작성자 SNS 스냅샷 (이슈 #750).
  /// Pro 회원이 글 작성 시 users/{uid}.socialLinks 값을 복사해 게시글에 저장.
  /// 추후 작성자가 SNS 값을 변경해도 게시글에는 작성 당시 값이 유지됨.
  /// keys: 'instagram', 'youtube', 'blog', 'kakaoId', 'whatsapp', 'email'
  final Map<String, String>? authorSocialSnapshot;

  const PostModel({
    required this.id,
    required this.uid,
    required this.authorName,
    this.authorHandle = '',
    this.authorPhotoUrl = '',
    this.authorTier = 'free',
    required this.category,
    required this.title,
    required this.content,
    this.bodyFormat = PostBodyFormat.plain,
    this.bodyDelta = '',
    this.imageUrls = const [],
    this.attachmentUrls = const [],
    this.attachmentNames = const [],
    this.youtubeUrls = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedBy = const [],
    required this.createdAt,
    this.authorSocialSnapshot,
  });

  /// 리치 텍스트 게시글 여부 (이슈 #747).
  bool get isRichBody =>
      bodyFormat == PostBodyFormat.quill && bodyDelta.isNotEmpty;

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PostModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Anonymous',
      authorHandle: data['authorHandle'] as String? ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String? ?? '',
      authorTier: data['authorTier'] as String? ?? 'free',
      category: data['category'] as String? ?? 'all',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      bodyFormat: data['bodyFormat'] as String? ?? PostBodyFormat.plain,
      bodyDelta: data['bodyDelta'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? const <String>[]),
      attachmentUrls: List<String>.from(data['attachmentUrls'] as List? ?? const <String>[]),
      attachmentNames: List<String>.from(data['attachmentNames'] as List? ?? const <String>[]),
      youtubeUrls: List<String>.from(data['youtubeUrls'] as List? ?? const <String>[]),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(data['likedBy'] as List? ?? const <String>[]),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorSocialSnapshot: _parseSocialSnapshot(data['authorSocialSnapshot']),
    );
  }

  /// authorSocialSnapshot 파싱 — Firestore `Map<String, dynamic>`를 `Map<String, String>?`로 변환.
  /// 빈 맵은 null로 정규화.
  static Map<String, String>? _parseSocialSnapshot(dynamic raw) {
    if (raw is! Map) return null;
    final result = <String, String>{};
    raw.forEach((key, value) {
      if (key is String && value is String && value.isNotEmpty) {
        result[key] = value;
      }
    });
    return result.isEmpty ? null : result;
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'authorName': authorName,
        if (authorHandle.isNotEmpty) 'authorHandle': authorHandle,
        'authorPhotoUrl': authorPhotoUrl,
        'authorTier': authorTier,
        'category': category,
        'title': title,
        'content': content,
        'bodyFormat': bodyFormat,
        'bodyDelta': bodyDelta,
        'imageUrls': imageUrls,
        'attachmentUrls': attachmentUrls,
        'attachmentNames': attachmentNames,
        'youtubeUrls': youtubeUrls,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'likedBy': likedBy,
        if (authorSocialSnapshot != null && authorSocialSnapshot!.isNotEmpty)
          'authorSocialSnapshot': authorSocialSnapshot,
      };

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${createdAt.month}/${createdAt.day}';
  }
}
