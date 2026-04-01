import 'package:cloud_firestore/cloud_firestore.dart';

class GuestbookEntry {
  final String id;
  final String uid;
  final String displayName;
  final String avatarUrl;
  final String message;
  final DateTime createdAt;

  const GuestbookEntry({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.message,
    required this.createdAt,
  });

  factory GuestbookEntry.fromMap(Map<String, dynamic> data, String id) {
    return GuestbookEntry(
      id: id,
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// "방금 전", "N분 전", "N시간 전", "N일 전"
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String timeAgoLocalized({required bool isKorean}) {
    final diff = DateTime.now().difference(createdAt);
    if (isKorean) {
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${diff.inDays}일 전';
    } else {
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
  }
}
