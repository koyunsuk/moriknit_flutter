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
  // 확장 메타데이터 (#778)
  final String screenSize; // "412x915"
  final String currentRoute; // "/swatch/abc123"
  final String currentScreenName; // "swatch"
  final String localeName; // "ko_KR" / "en_US"
  final String isOnline; // "true" | "false" | "" (unknown)
  final String viewportInsets; // "top:24 bottom:0"
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

  // ── AI 개발자 상주 시스템 Phase 1 (#813) ──────────────────────────────
  /// AI fix 진행 상태:
  /// 'pending' | 'analyzing' | 'analyzed' | 'approved' |
  /// 'fixing' | 'building' | 'installing' | 'done' | 'failed' | 'rejected'
  final String aiFixStatus;

  /// 각 단계 로그: [{step, startedAt, completedAt, log}, ...]
  final List<Map<String, dynamic>> aiFixSteps;

  /// Claude 분석 결과 텍스트
  final String fixPlan;

  /// git diff 미리보기
  final String fixDiffPreview;

  /// 수정 commit SHA
  final String fixCommitSha;

  /// 변경된 파일 경로 목록
  final List<String> fixedFiles;

  /// APK 설치 완료 시각
  final DateTime? apkInstalledAt;

  /// AI fix 실패 사유 (failed 상태일 때)
  final String aiFixErrorMessage;

  /// 다중 프로젝트 지원 (Phase 1에선 'moriknit' 고정)
  final String targetProject;

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
    this.screenSize = '',
    this.currentRoute = '',
    this.currentScreenName = '',
    this.localeName = '',
    this.isOnline = '',
    this.viewportInsets = '',
    required this.uid,
    required this.userEmail,
    this.userName = '',
    this.imageUrls = const [],
    this.wantsReply = false,
    this.userTier = 'free',
    this.githubIssueNumber,
    this.githubIssueUrl,
    required this.createdAt,
    // AI 워크플로우 (Phase 1 — #813)
    this.aiFixStatus = 'pending',
    this.aiFixSteps = const [],
    this.fixPlan = '',
    this.fixDiffPreview = '',
    this.fixCommitSha = '',
    this.fixedFiles = const [],
    this.apkInstalledAt,
    this.aiFixErrorMessage = '',
    this.targetProject = 'moriknit',
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
        'screenSize': screenSize,
        'currentRoute': currentRoute,
        'currentScreenName': currentScreenName,
        'localeName': localeName,
        'isOnline': isOnline,
        'viewportInsets': viewportInsets,
        'uid': uid,
        'userEmail': userEmail,
        'userName': userName,
        'imageUrls': imageUrls,
        'wantsReply': wantsReply,
        'userTier': userTier,
        'createdAt': Timestamp.fromDate(createdAt),
        'githubIssueNumber': githubIssueNumber,
        'githubIssueUrl': githubIssueUrl,
        // AI 워크플로우 (#813)
        'aiFixStatus': aiFixStatus,
        'aiFixSteps': aiFixSteps,
        'fixPlan': fixPlan,
        'fixDiffPreview': fixDiffPreview,
        'fixCommitSha': fixCommitSha,
        'fixedFiles': fixedFiles,
        'apkInstalledAt':
            apkInstalledAt == null ? null : Timestamp.fromDate(apkInstalledAt!),
        'aiFixErrorMessage': aiFixErrorMessage,
        'targetProject': targetProject,
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
      screenSize: json['screenSize'] as String? ?? '',
      currentRoute: json['currentRoute'] as String? ?? '',
      currentScreenName: json['currentScreenName'] as String? ?? '',
      localeName: json['localeName'] as String? ?? '',
      isOnline: json['isOnline'] as String? ?? '',
      viewportInsets: json['viewportInsets'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      userEmail: json['userEmail'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      wantsReply: json['wantsReply'] as bool? ?? false,
      userTier: json['userTier'] as String? ?? 'free',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      githubIssueNumber: json['githubIssueNumber'] as int?,
      githubIssueUrl: json['githubIssueUrl'] as String?,
      // AI 워크플로우 (#813)
      aiFixStatus: json['aiFixStatus'] as String? ?? 'pending',
      aiFixSteps: (json['aiFixSteps'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      fixPlan: json['fixPlan'] as String? ?? '',
      fixDiffPreview: json['fixDiffPreview'] as String? ?? '',
      fixCommitSha: json['fixCommitSha'] as String? ?? '',
      fixedFiles: (json['fixedFiles'] as List<dynamic>?)?.cast<String>() ?? const [],
      apkInstalledAt: (json['apkInstalledAt'] as Timestamp?)?.toDate(),
      aiFixErrorMessage: json['aiFixErrorMessage'] as String? ?? '',
      targetProject: json['targetProject'] as String? ?? 'moriknit',
    );
  }

  factory BugReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BugReport.fromJson(data, id: doc.id);
  }
}
