import 'package:cloud_firestore/cloud_firestore.dart';

class BugReport {
  final String id;
  final String title;
  final String description;
  final String category; // 'ui' | 'crash' | 'feature' | 'other'
  final String steps;
  // 시스템 정보
  final String deviceInfo;
  final String osVersion;
  final String appVersion;
  final String platform; // 'android' | 'ios' | 'web' | 'other'
  // 사용자 정보
  final String uid;
  final String userEmail;
  final String userName;
  // 이미지
  final List<String> imageUrls;
  // 사용자 요청
  final bool wantsReply;
  // 회원 정보
  final String userTier; // 'free' | 'premium'
  // GitHub 연동
  int? githubIssueNumber;
  String? githubIssueUrl;
  final DateTime createdAt;

  BugReport({
    this.id = '',
    required this.title,
    required this.description,
    required this.category,
    required this.steps,
    required this.deviceInfo,
    this.osVersion = '',
    required this.appVersion,
    this.platform = '',
    required this.uid,
    required this.userEmail,
    this.userName = '',
    this.imageUrls = const [],
    this.wantsReply = false,
    this.userTier = 'free',
    this.githubIssueNumber,
    this.githubIssueUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'steps': steps,
        'deviceInfo': deviceInfo,
        'osVersion': osVersion,
        'appVersion': appVersion,
        'platform': platform,
        'uid': uid,
        'userEmail': userEmail,
        'userName': userName,
        'imageUrls': imageUrls,
        'wantsReply': wantsReply,
        'userTier': userTier,
        'createdAt': Timestamp.fromDate(createdAt),
        'githubIssueNumber': githubIssueNumber,
        'githubIssueUrl': githubIssueUrl,
      };

  factory BugReport.fromJson(Map<String, dynamic> json, {String id = ''}) {
    return BugReport(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      steps: json['steps'] as String? ?? '',
      deviceInfo: json['deviceInfo'] as String? ?? '',
      osVersion: json['osVersion'] as String? ?? '',
      appVersion: json['appVersion'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      userEmail: json['userEmail'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      wantsReply: json['wantsReply'] as bool? ?? false,
      userTier: json['userTier'] as String? ?? 'free',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      githubIssueNumber: json['githubIssueNumber'] as int?,
      githubIssueUrl: json['githubIssueUrl'] as String?,
    );
  }

  factory BugReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BugReport.fromJson(data, id: doc.id);
  }
}
