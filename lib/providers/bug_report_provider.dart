import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/my/data/bug_report_repository.dart';
import '../features/my/domain/bug_report.dart';

final bugReportRepositoryProvider = Provider<BugReportRepository>((ref) {
  return BugReportRepository();
});

// 제출 상태: null = 초기, true = 성공(이슈 번호 있음), false = Firestore만 저장
class BugReportNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async => null;

  Future<int?> submit(BugReport report) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final repo = ref.read(bugReportRepositoryProvider);
      return repo.submitBugReport(report);
    });
    state = result;
    return result.valueOrNull;
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final bugReportProvider = AsyncNotifierProvider<BugReportNotifier, int?>(
  BugReportNotifier.new,
);
