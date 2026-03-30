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

      final body = '''**카테고리:** ${report.category}
**플랫폼:** ${report.platform} | **OS:** ${report.osVersion} | **앱버전:** ${report.appVersion}
**기기:** ${report.deviceInfo}
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
}
