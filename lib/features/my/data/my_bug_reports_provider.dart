// 이슈 #855 — 마이페이지에서 본인이 제출한 버그/의견 이력을 노출하기 위한 스트림 Provider.
//
// - myBugReportsProvider: `bug_reports` where uid == currentUid (최신순 20건)
//   · GitHub 이슈 연동 여부와 무관하게 노출 (githubIssueUrl 있으면 외부 링크로 진입)
//   · 비로그인/익명 상태에서는 빈 스트림 (마이페이지 자체가 인증 후 진입이지만 방어)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../domain/bug_report.dart';

/// 본인이 제출한 버그/의견 이력 — `bug_reports.where(uid).orderBy(createdAt desc).limit(20)`
final myBugReportsProvider = StreamProvider<List<BugReport>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <BugReport>[]);
  }
  return FirebaseFirestore.instance
      .collection('bug_reports')
      .where('uid', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map(BugReport.fromFirestore).toList());
});
