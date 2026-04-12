import 'package:cloud_firestore/cloud_firestore.dart';

class DmRoom {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantPhotos;
  final String lastMessage;
  final DateTime lastMessageAt;
  final Map<String, int> unreadCount;

  const DmRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.participantPhotos = const {},
    this.lastMessage = '',
    required this.lastMessageAt,
    this.unreadCount = const {},
  });

  factory DmRoom.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return DmRoom(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? const <String>[]),
      participantNames: Map<String, String>.from(data['participantNames'] as Map? ?? const <String, String>{}),
      participantPhotos: Map<String, String>.from(data['participantPhotos'] as Map? ?? const <String, String>{}),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)) ?? const <String, int>{},
      ),
    );
  }

  /// Returns the other participant's UID given the current user's UID.
  String otherUid(String myUid) => participants.firstWhere((uid) => uid != myUid, orElse: () => '');

  /// Returns the other participant's display name.
  String otherName(String myUid) {
    final other = otherUid(myUid);
    return participantNames[other] ?? '';
  }

  /// Returns the other participant's photo URL (empty string if none).
  String otherPhoto(String myUid) {
    final other = otherUid(myUid);
    return participantPhotos[other] ?? '';
  }

  /// Returns the unread count for the given user.
  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  String get timeAgo {
    final diff = DateTime.now().difference(lastMessageAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${lastMessageAt.month}/${lastMessageAt.day}';
  }
}

class DmMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  const DmMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory DmMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return DmMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
