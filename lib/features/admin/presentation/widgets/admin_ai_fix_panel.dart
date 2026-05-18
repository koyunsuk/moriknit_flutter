// AI 개발자 상주 시스템 Phase 1 (#813)
// 어드민의 버그리포트 상세에 노출되는 AI 자동 fix 진행 패널.
// - 8단계 시각화 (pending → done)
// - 진행률 바
// - fixPlan / fixDiffPreview / fixedFiles 표시
// - 액션 버튼 4종 (분석 시작 / 수정 승인 / 릴리즈 승인 / 거부)
//
// admin_screen.dart 와의 통합은 메인 세션에서 처리. 본 위젯은 순수 표현·콜백 기반.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../my/domain/bug_report.dart';

/// 단계 순서 (8단계). 순환 정의 외 상태 (failed/rejected) 는 별도 처리.
const List<String> _kFixSteps = [
  'pending',
  'analyzing',
  'analyzed',
  'approved',
  'fixing',
  'building',
  'installing',
  'done',
];

const Map<String, String> _kStepLabels = {
  'pending': '대기',
  'analyzing': 'AI 분석 중',
  'analyzed': '분석 완료',
  'approved': '수정 승인됨',
  'fixing': '코드 수정 중',
  'building': 'APK 빌드 중',
  'installing': '폰 설치 중',
  'done': '설치 완료',
  'failed': '실패',
  'rejected': '거부됨',
};

class AdminAIFixPanel extends StatelessWidget {
  final BugReport report;
  final VoidCallback onAnalysisStart;
  final VoidCallback onApprove;
  final VoidCallback onReleaseApprove;
  final VoidCallback onReject;

  const AdminAIFixPanel({
    super.key,
    required this.report,
    required this.onAnalysisStart,
    required this.onApprove,
    required this.onReleaseApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return MoriBlockShell(
      label: 'AI 자동 fix',
      icon: Icons.smart_toy,
      accent: C.lv,
      trailing: _StatusBadge(status: report.aiFixStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressBar(status: report.aiFixStatus),
          const SizedBox(height: 14),
          _StepChecklist(report: report),
          if (report.aiFixStatus == 'failed' &&
              report.aiFixErrorMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ErrorBox(message: report.aiFixErrorMessage),
          ],
          if (report.fixPlan.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionLabel(text: '분석 결과 (fixPlan)', color: C.lvD),
            const SizedBox(height: 6),
            _PlanTextBox(text: report.fixPlan),
          ],
          if (report.fixDiffPreview.isNotEmpty &&
              _stepIndex(report.aiFixStatus) >= _stepIndex('approved')) ...[
            const SizedBox(height: 16),
            _SectionLabel(
              text: 'git diff 미리보기',
              color: C.lvD,
              trailing: report.fixCommitSha.isEmpty
                  ? null
                  : Text(
                      report.fixCommitSha.length >= 7
                          ? report.fixCommitSha.substring(0, 7)
                          : report.fixCommitSha,
                      style: T.caption.copyWith(
                        color: C.mu,
                        fontFamily: 'monospace',
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            _DiffBox(diff: report.fixDiffPreview),
          ],
          if (report.fixedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionLabel(text: '변경 파일 (${report.fixedFiles.length})', color: C.lvD),
            const SizedBox(height: 6),
            _FixedFilesList(files: report.fixedFiles),
          ],
          const SizedBox(height: 18),
          _ActionButtons(
            status: report.aiFixStatus,
            apkInstalled: report.apkInstalledAt != null,
            onAnalysisStart: onAnalysisStart,
            onApprove: onApprove,
            onReleaseApprove: onReleaseApprove,
            onReject: onReject,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// 단계 인덱스 헬퍼

int _stepIndex(String status) {
  final i = _kFixSteps.indexOf(status);
  if (i >= 0) return i;
  // failed/rejected: 단계 외 — -1 반환하면 호출처에서 따로 분기
  return -1;
}

// ──────────────────────────────────────────────────────────────────────
// 상태 뱃지 (헤더 우측)

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case 'done':
        color = C.lmD;
        break;
      case 'failed':
      case 'rejected':
        color = C.og;
        break;
      case 'pending':
        color = C.mu;
        break;
      default:
        color = C.lv;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _kStepLabels[status] ?? status,
        style: T.caption.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// 진행률 바

class _ProgressBar extends StatelessWidget {
  final String status;
  const _ProgressBar({required this.status});

  @override
  Widget build(BuildContext context) {
    final idx = _stepIndex(status);
    // failed/rejected: 0%로 표시 + 색상 변경
    final isAbnormal = status == 'failed' || status == 'rejected';
    final double ratio = isAbnormal
        ? 0.0
        : (idx <= 0 ? 0.0 : (idx + 1) / _kFixSteps.length).clamp(0.0, 1.0);
    final Color barColor = isAbnormal ? C.og : (status == 'done' ? C.lmD : C.lv);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('진행률', style: T.caption.copyWith(color: C.tx2)),
            Text(
              '${(ratio * 100).round()}%',
              style: T.captionBold.copyWith(color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: C.lm.withValues(alpha: 0.45),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// 8단계 체크리스트

class _StepChecklist extends StatelessWidget {
  final BugReport report;
  const _StepChecklist({required this.report});

  @override
  Widget build(BuildContext context) {
    // step 별 completedAt 매핑 — aiFixSteps 의 동일 step 중 가장 최근 completedAt 사용
    final Map<String, DateTime?> completedMap = {};
    for (final s in report.aiFixSteps) {
      final stepName = s['step'] as String?;
      final ts = s['completedAt'];
      if (stepName == null) continue;
      DateTime? dt;
      if (ts is DateTime) {
        dt = ts;
      } else if (ts != null) {
        // Firestore Timestamp 직렬화 후의 toDate() 처리
        try {
          dt = (ts as dynamic).toDate() as DateTime?;
        } catch (_) {
          dt = null;
        }
      }
      if (dt != null) {
        final prev = completedMap[stepName];
        if (prev == null || dt.isAfter(prev)) {
          completedMap[stepName] = dt;
        }
      }
    }

    final currentIdx = _stepIndex(report.aiFixStatus);
    final isAbnormal =
        report.aiFixStatus == 'failed' || report.aiFixStatus == 'rejected';

    return Column(
      children: List.generate(_kFixSteps.length, (i) {
        final stepName = _kFixSteps[i];
        final completedAt = completedMap[stepName];

        final bool isCompleted = completedAt != null ||
            (!isAbnormal && currentIdx >= 0 && i < currentIdx);
        final bool isCurrent =
            !isAbnormal && currentIdx >= 0 && i == currentIdx && !isCompleted;

        return _StepRow(
          label: _kStepLabels[stepName] ?? stepName,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          completedAt: completedAt,
          isLast: i == _kFixSteps.length - 1,
        );
      }),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final DateTime? completedAt;
  final bool isLast;

  const _StepRow({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.completedAt,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor =
        isCompleted ? C.lmD : (isCurrent ? C.lv : C.mu);
    final Color textColor =
        isCompleted ? C.tx : (isCurrent ? C.lvD : C.mu);

    Widget icon;
    if (isCompleted) {
      icon = Icon(Icons.check_circle, size: 20, color: iconColor);
    } else if (isCurrent) {
      icon = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
        ),
      );
    } else {
      icon = Icon(Icons.radio_button_unchecked, size: 20, color: iconColor);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: T.sm.copyWith(
                color: textColor,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (completedAt != null)
            Text(
              _formatTime(completedAt!),
              style: T.caption.copyWith(color: C.mu),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

// ──────────────────────────────────────────────────────────────────────
// 섹션 라벨

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Widget? trailing;

  const _SectionLabel({required this.text, required this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: T.captionBold.copyWith(color: color, fontSize: 12),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// fixPlan 텍스트박스

class _PlanTextBox extends StatelessWidget {
  final String text;
  const _PlanTextBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.lvL,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.lv.withValues(alpha: 0.20)),
      ),
      child: SelectableText(
        text,
        style: T.sm.copyWith(color: C.tx, height: 1.5),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// git diff 코드 박스 (모노스페이스)

class _DiffBox extends StatelessWidget {
  final String diff;
  const _DiffBox({required this.diff});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.tx.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.bd),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              diff,
              style: TextStyle(
                fontSize: 11.5,
                color: C.tx,
                height: 1.45,
                fontFamily: 'monospace',
                fontFamilyFallback: const [
                  'Consolas',
                  'Menlo',
                  'Courier New',
                  'monospace',
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// 변경 파일 목록

class _FixedFilesList extends StatelessWidget {
  final List<String> files;
  const _FixedFilesList({required this.files});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.gx,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: files.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.check_box_outlined, size: 16, color: C.lmD),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    f,
                    style: T.sm.copyWith(
                      color: C.tx2,
                      fontFamily: 'monospace',
                      fontFamilyFallback: const [
                        'Consolas',
                        'Menlo',
                        'Courier New',
                        'monospace',
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// 에러 박스

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.og.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.og.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: C.og),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message,
              style: T.sm.copyWith(color: C.og, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// 액션 버튼 4종

class _ActionButtons extends StatelessWidget {
  final String status;
  final bool apkInstalled;
  final VoidCallback onAnalysisStart;
  final VoidCallback onApprove;
  final VoidCallback onReleaseApprove;
  final VoidCallback onReject;

  const _ActionButtons({
    required this.status,
    required this.apkInstalled,
    required this.onAnalysisStart,
    required this.onApprove,
    required this.onReleaseApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final canAnalyze = status == 'pending';
    final canApprove = status == 'analyzed';
    final canRelease = status == 'done' && apkInstalled;
    // 거부는 종결 단계가 아닌 동안 항상 활성
    final canReject = status != 'rejected' && status != 'done';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionButton(
          label: '🤖 AI 분석 시작',
          color: C.lv,
          enabled: canAnalyze,
          onPressed: onAnalysisStart,
        ),
        _ActionButton(
          label: '수정 승인',
          color: C.lmD,
          enabled: canApprove,
          onPressed: onApprove,
        ),
        _ActionButton(
          label: '릴리즈 승인',
          color: C.pk,
          enabled: canRelease,
          onPressed: onReleaseApprove,
        ),
        _ActionButton(
          label: '거부',
          color: C.og,
          enabled: canReject,
          onPressed: onReject,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: C.mu.withValues(alpha: 0.25),
        disabledForegroundColor: C.mu,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: T.bodyBold.copyWith(fontSize: 13),
      ),
      child: Text(label),
    );
  }
}
