// lib/features/blueprint/presentation/step_log_screen.dart
//
// 이슈 #687 (Phase C) — 단계로그 통일 화면.
//
// StepLogView 를 표준 화면 쉘로 감싸 단독 화면으로 진입할 때 사용.
// (목록·도안 상세에서 StepLogView 를 직접 임베드하는 경우도 가능.)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import 'step_log_view.dart';

class StepLogScreen extends ConsumerWidget {
  const StepLogScreen({
    super.key,
    required this.blueprintId,
    this.runId,
  });

  final String blueprintId;
  final String? runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '단계로그' : 'Step Log',
                    subtitle: isKorean
                        ? '작업 단계를 한 곳에서 기록해요'
                        : 'Track your work steps in one place',
                    trailing: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
                        onPressed: () => Navigator.pop(context),
                        tooltip: isKorean ? '뒤로' : 'Back',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StepLogView(
                    blueprintId: blueprintId,
                    runId: runId,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
