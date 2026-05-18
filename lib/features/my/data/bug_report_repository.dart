import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/bug_report.dart';

class BugReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 이미지 바이트 리스트를 Storage에 업로드하고 URL 목록을 반환합니다.
  Future<List<String>> uploadImages(String uid, List<Uint8List> images) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      try {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ref = _storage.ref('bug_reports/$uid/${ts}_$i.jpg');
        await ref.putData(images[i], SettableMetadata(contentType: 'image/jpeg'));
        urls.add(await ref.getDownloadURL());
      } catch (e) {
        debugPrint('[BugReport] 이미지 업로드 실패 $i: $e');
      }
    }
    return urls;
  }

  Future<int?> submitBugReport(BugReport report) async {
    // 1. Firestore에 저장
    final docRef = await _firestore.collection('bug_reports').add(report.toJson());

    // 2. GitHub PAT 읽기
    String? pat;
    try {
      final configSnap = await _firestore.collection('app_config').doc('github_config').get();
      pat = configSnap.data()?['pat'] as String?;
    } catch (e) {
      debugPrint('[BugReport] app_config 읽기 실패: $e');
    }

    if (pat == null || pat.isEmpty) {
      debugPrint('[BugReport] GitHub PAT 미설정 — Firestore에만 저장됨');
      return null;
    }

    // 3. GitHub 이슈 생성
    try {
      final imageSection = report.imageUrls.isNotEmpty
          ? '\n\n**첨부 이미지**\n${report.imageUrls.map((u) => '![]($u)').join('\n')}'
          : '';

      final tierLabel = report.userTier == 'premium' ? '⭐ 유료회원 (우선처리)' : '무료회원';
      final replyLabel = report.wantsReply ? '✅ 예 (이메일: ${report.userEmail})' : '아니오';

      final onlineLabel = report.isOnline == 'true'
          ? '예'
          : report.isOnline == 'false'
              ? '아니오'
              : '알수없음';
      final screenLine = report.currentRoute.isEmpty
          ? ''
          : '**현재화면:** ${report.currentRoute}'
              '${report.currentScreenName.isNotEmpty ? ' (${report.currentScreenName})' : ''}';
      final screenSizeLine =
          report.screenSize.isEmpty ? '' : '**화면크기:** ${report.screenSize}';
      final localeLine =
          report.localeName.isEmpty ? '' : '**언어:** ${report.localeName}';
      final extraLine1 = [screenSizeLine, screenLine]
          .where((s) => s.isNotEmpty)
          .join(' | ');
      final extraLine2 =
          [localeLine, '**온라인:** $onlineLabel'].where((s) => s.isNotEmpty).join(' | ');

      final body = '''**카테고리:** ${report.category}
**플랫폼:** ${report.platform} | **OS:** ${report.osVersion} | **앱버전:** ${report.appVersion}
**기기:** ${report.deviceInfo}${extraLine1.isEmpty ? '' : '\n$extraLine1'}${extraLine2.isEmpty ? '' : '\n$extraLine2'}
**제출자:** ${report.userEmail} (${report.userName}) · uid: `${report.uid}`
**회원 등급:** $tierLabel
**답변 요청:** $replyLabel

---

**설명**
${report.description}

**재현 단계**
${report.steps.isEmpty ? '없음' : report.steps}$imageSection''';

      final response = await http.post(
        Uri.parse('https://api.github.com/repos/koyunsuk/moriknit_flutter/issues'),
        headers: {
          'Authorization': 'Bearer $pat',
          'Accept': 'application/vnd.github+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': [
            '[사용자]',
            if (report.userTier == 'premium') '[유료회원]',
            if (report.wantsReply) '[답변요청]',
            report.title,
          ].join(' '),
          'body': body,
          'labels': [
            'user-report',
            if (report.userTier == 'premium') 'priority: high',
          ],
        }),
      );

      debugPrint('[BugReport] GitHub API 응답: ${response.statusCode}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final issueNumber = json['number'] as int;
        final issueUrl = json['html_url'] as String;

        await docRef.update({
          'githubIssueNumber': issueNumber,
          'githubIssueUrl': issueUrl,
        });

        debugPrint('[BugReport] GitHub 이슈 생성 완료: #$issueNumber');
        return issueNumber;
      } else {
        debugPrint('[BugReport] GitHub API 실패: ${response.body}');
      }
    } catch (e) {
      debugPrint('[BugReport] GitHub API 예외: $e');
    }

    return null;
  }

  // ── AI 개발자 상주 시스템 Phase 1 (#813) ─────────────────────────────────
  // 어드민/PC 워커가 호출. 기존 submitBugReport 로직과 분리된 신규 메서드 묶음.

  CollectionReference<Map<String, dynamic>> get _bugReports =>
      _firestore.collection('bug_reports');

  /// 단계 시작/완료를 기록하면서 aiFixStatus를 변경한다.
  /// - status가 '동작 중' 단계명(analyzing/fixing/building/installing)이면
  ///   해당 step을 startedAt 와 함께 push.
  /// - 종료 단계(analyzed/approved/done/failed/rejected)이면 마지막 동일 step의
  ///   completedAt 을 채우고, 없으면 새 step을 startedAt + completedAt 으로 push.
  Future<void> updateAiFixStatus(
    String reportId,
    String status, {
    String? log,
  }) async {
    final docRef = _bugReports.doc(reportId);
    final snap = await docRef.get();
    final data = snap.data() ?? <String, dynamic>{};

    final steps = ((data['aiFixSteps'] as List<dynamic>?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    const inProgressStatuses = <String>{
      'analyzing',
      'fixing',
      'building',
      'installing',
    };
    const terminalStatuses = <String>{
      'analyzed',
      'approved',
      'done',
      'failed',
      'rejected',
    };

    // 동일 단계의 미완료 step을 찾는다.
    int openIndex = -1;
    for (var i = steps.length - 1; i >= 0; i--) {
      if (steps[i]['step'] == status && steps[i]['completedAt'] == null) {
        openIndex = i;
        break;
      }
    }

    if (inProgressStatuses.contains(status)) {
      // 진행 단계 시작: 이미 열린 동일 step이 없으면 새로 추가
      if (openIndex == -1) {
        steps.add({
          'step': status,
          'startedAt': Timestamp.now(),
          'completedAt': null,
          'log': log ?? '',
        });
      } else if (log != null) {
        // 진행 중 log 보강
        steps[openIndex] = {
          ...steps[openIndex],
          'log': log,
        };
      }
    } else if (terminalStatuses.contains(status)) {
      // 종료 단계: 직전 진행 step 완료 마크
      for (var i = steps.length - 1; i >= 0; i--) {
        if (steps[i]['completedAt'] == null) {
          steps[i] = {
            ...steps[i],
            'completedAt': Timestamp.now(),
            'log': log ?? (steps[i]['log'] ?? ''),
          };
          break;
        }
      }
      // 종료 그 자체도 별도 step으로 push (시각화용)
      steps.add({
        'step': status,
        'startedAt': Timestamp.now(),
        'completedAt': Timestamp.now(),
        'log': log ?? '',
      });
    } else {
      // pending 등 그 외 — 단순 step push
      steps.add({
        'step': status,
        'startedAt': Timestamp.now(),
        'completedAt': Timestamp.now(),
        'log': log ?? '',
      });
    }

    await docRef.update({
      'aiFixStatus': status,
      'aiFixSteps': steps,
    });
  }

  /// Claude 분석 결과(텍스트) 저장.
  Future<void> updateFixPlan(String reportId, String plan) async {
    await _bugReports.doc(reportId).update({
      'fixPlan': plan,
    });
  }

  /// git diff 미리보기 + 변경 파일 목록 + commit SHA 저장.
  Future<void> updateFixDiff(
    String reportId,
    String diff, {
    required List<String> fixedFiles,
    required String commitSha,
  }) async {
    await _bugReports.doc(reportId).update({
      'fixDiffPreview': diff,
      'fixedFiles': fixedFiles,
      'fixCommitSha': commitSha,
    });
  }

  /// APK 설치 완료 시각 기록. aiFixStatus 는 별도 updateAiFixStatus로 진행.
  Future<void> markApkInstalled(String reportId) async {
    await _bugReports.doc(reportId).update({
      'apkInstalledAt': Timestamp.now(),
    });
  }

  /// AI fix 실패 처리 — 상태를 failed 로 변경 + 사유 기록.
  Future<void> markAiFixFailed(String reportId, String errorMessage) async {
    await updateAiFixStatus(reportId, 'failed', log: errorMessage);
    await _bugReports.doc(reportId).update({
      'aiFixErrorMessage': errorMessage,
    });
  }

  /// 단일 버그리포트 실시간 스트림 — 어드민 패널에서 단계 시각화용.
  Stream<BugReport> watchBugReport(String reportId) {
    return _bugReports.doc(reportId).snapshots().map(
          (snap) => BugReport.fromFirestore(snap),
        );
  }
}
