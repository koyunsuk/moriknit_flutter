import 'package:cloud_firestore/cloud_firestore.dart';

class DmRoom {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantPhotos;
  /// 이슈 #771 — 참여자별 핸들(@아이디) 스냅샷.
  final Map<String, String> participantHandles;
  final String lastMessage;
  final DateTime lastMessageAt;
  final Map<String, int> unreadCount;
  /// 이슈 #834 — @moriknit 시스템 봇과의 공식 채널 여부.
  /// true 이면 DM 리스트/채팅 헤더에 '공식' 배지 + 라벤더 액센트 표시.
  final bool isSystemChannel;
  /// 이슈 #837 — 사용자 마지막 메시지 시각 (어드민 인박스 정렬용).
  /// 일반 DM 룸엔 없음 — null 허용.
  final DateTime? lastUserMessageAt;
  /// 이슈 #837 — 어드민 미응답 시작 시각.
  /// 사용자가 메시지를 처음 보낸 시점부터 어드민 답장 전까지 보존.
  /// 어드민 답장 시 Cloud Function 이 삭제.
  final DateTime? unrespondedSince;
  /// 이슈 #837 — 어드민 미확인 메시지 카운트.
  /// 어드민 답장 시 0 으로 리셋.
  final int unreadByAdmin;

  const DmRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.participantPhotos = const {},
    this.participantHandles = const {},
    this.lastMessage = '',
    required this.lastMessageAt,
    this.unreadCount = const {},
    this.isSystemChannel = false,
    this.lastUserMessageAt,
    this.unrespondedSince,
    this.unreadByAdmin = 0,
  });

  factory DmRoom.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return DmRoom(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? const <String>[]),
      participantNames: Map<String, String>.from(data['participantNames'] as Map? ?? const <String, String>{}),
      participantPhotos: Map<String, String>.from(data['participantPhotos'] as Map? ?? const <String, String>{}),
      participantHandles: Map<String, String>.from(data['participantHandles'] as Map? ?? const <String, String>{}),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)) ?? const <String, int>{},
      ),
      isSystemChannel: data['isSystemChannel'] as bool? ?? false,
      lastUserMessageAt: (data['lastUserMessageAt'] as Timestamp?)?.toDate(),
      unrespondedSince: (data['unrespondedSince'] as Timestamp?)?.toDate(),
      unreadByAdmin: (data['unreadByAdmin'] as num?)?.toInt() ?? 0,
    );
  }

  /// 이슈 #837 — 어드민 미응답 경과 시간 (분 단위).
  /// unrespondedSince 가 없으면 null.
  int? get unrespondedMinutes {
    if (unrespondedSince == null) return null;
    return DateTime.now().difference(unrespondedSince!).inMinutes;
  }

  /// 이슈 #837 — 미응답 경과를 사람이 읽기 좋은 문자열로 (예: '3시간 미응답').
  String unrespondedLabel({bool isKorean = true}) {
    final m = unrespondedMinutes;
    if (m == null) return '';
    if (m < 1) return isKorean ? '방금 도착' : 'just now';
    if (m < 60) return isKorean ? '$m분 미응답' : '${m}m waiting';
    final h = m ~/ 60;
    if (h < 24) return isKorean ? '$h시간 미응답' : '${h}h waiting';
    final d = h ~/ 24;
    return isKorean ? '$d일 미응답' : '${d}d waiting';
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

  /// 이슈 #771 — 상대방의 핸들(@아이디). 없으면 빈 문자열.
  String otherHandle(String myUid) {
    final other = otherUid(myUid);
    return participantHandles[other] ?? '';
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
  /// 이슈 #834 — 메시지별 읽음 추적 (uid → 읽은 시각).
  /// 어드민 브로드캐스트 메시지의 경우 클라이언트가 DM 진입 시 본인 uid 채움.
  final Map<String, DateTime> readBy;
  /// 이슈 #834 — 메시지 메타 (어드민 발송 시 broadcastId/deepLink 포함).
  /// 일반 메시지는 비어있음.
  final Map<String, dynamic> meta;
  /// 이슈 #848 — 풍부한 카드 메시지 (어드민 브로드캐스트 전용).
  /// 비어있으면 일반 텍스트 버블, 하나라도 있으면 카드 위젯으로 렌더링.
  final String imageUrl;
  /// 이슈 #848 — Quill Delta JSON 문자열. 본문 리치 텍스트.
  final String bodyDelta;
  /// 이슈 #848 — "자세히 보기" 버튼이 열 외부/내부 링크 URL.
  final String linkUrl;
  /// 이슈 #845 — 어드민 답장 파일 첨부 URL (PDF 등 비이미지 자료).
  /// 이미지는 [imageUrl] 사용. 비이미지 첨부는 본 필드 사용 → 채팅 버블 하단에
  /// 파일 칩(아이콘 + 파일명) 으로 렌더링.
  final String attachmentUrl;
  /// 이슈 #845 — 첨부 파일 표시명 (예: '안내문.pdf'). 비어있으면 URL 끝자락 사용.
  final String attachmentName;

  const DmMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.readBy = const {},
    this.meta = const {},
    this.imageUrl = '',
    this.bodyDelta = '',
    this.linkUrl = '',
    this.attachmentUrl = '',
    this.attachmentName = '',
  });

  factory DmMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final rawReadBy = data['readBy'] as Map?;
    final readBy = <String, DateTime>{};
    if (rawReadBy != null) {
      rawReadBy.forEach((k, v) {
        if (v is Timestamp) {
          readBy[k.toString()] = v.toDate();
        }
      });
    }
    return DmMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: readBy,
      meta: Map<String, dynamic>.from(data['meta'] as Map? ?? const {}),
      imageUrl: data['imageUrl'] as String? ?? '',
      bodyDelta: data['bodyDelta'] as String? ?? '',
      linkUrl: data['linkUrl'] as String? ?? '',
      attachmentUrl: data['attachmentUrl'] as String? ?? '',
      attachmentName: data['attachmentName'] as String? ?? '',
    );
  }

  /// 이슈 #845 — 파일 첨부(비이미지) 보유 여부.
  bool get hasAttachment => attachmentUrl.isNotEmpty;

  /// 이슈 #834 — 어드민 브로드캐스트 발송으로 생성된 메시지인지 여부.
  bool get isBroadcast {
    final source = meta['source'];
    return source is String && source == 'broadcast';
  }

  /// 이슈 #834 — 어드민 브로드캐스트 ID (없으면 null).
  String? get broadcastId {
    final id = meta['broadcastId'];
    return (id is String && id.isNotEmpty) ? id : null;
  }

  /// 이슈 #837 — 어드민이 시스템 명의로 보낸 답장 메시지인지 여부.
  /// meta.senderType == 'admin_as_system'
  bool get isAdminReply {
    final t = meta['senderType'];
    return t is String && t == 'admin_as_system';
  }

  /// 이슈 #848 — 풍부한 카드(이미지/Quill 본문/링크) 메시지 여부.
  /// meta.isRichBroadcast 플래그 우선, 폴백으로 필드 직접 검사.
  bool get isRichBroadcast {
    final flag = meta['isRichBroadcast'];
    if (flag is bool && flag) return true;
    return imageUrl.isNotEmpty || bodyDelta.isNotEmpty || linkUrl.isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
