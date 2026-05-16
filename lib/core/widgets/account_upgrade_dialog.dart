// lib/core/widgets/account_upgrade_dialog.dart
//
// 이슈 #729 — 익명(게스트) 사용자에게 일정량 데이터가 쌓이면 부드럽게 회원가입을 권유.
// 압박 X — [지금 만들기] / [다음에] 두 가지 선택. 다음에 누르면 1주 뒤에만 재표시.
//
// 트리거 조건 (둘 중 하나):
//   - 도안 5개 이상
//   - 카운터 누적 100회 이상
//   - 첫 진입 후 7일 경과
//
// Hive 'user' box 의 'upgrade_prompt' 키에 마지막 표시 시각 저장.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../core/constants/subscription_constants.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/sign_up_sheet.dart';
import '../../providers/auth_provider.dart';

class _UpgradePromptState {
  final DateTime? firstSeenAt;
  final DateTime? lastShownAt;

  const _UpgradePromptState({this.firstSeenAt, this.lastShownAt});

  factory _UpgradePromptState.read() {
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final raw = box.get('upgrade_prompt');
      if (raw == null) return const _UpgradePromptState();
      final firstSeen = raw['first_seen_at'];
      final lastShown = raw['last_shown_at'];
      return _UpgradePromptState(
        firstSeenAt: firstSeen is int
            ? DateTime.fromMillisecondsSinceEpoch(firstSeen)
            : null,
        lastShownAt: lastShown is int
            ? DateTime.fromMillisecondsSinceEpoch(lastShown)
            : null,
      );
    } catch (_) {
      return const _UpgradePromptState();
    }
  }

  Future<void> persist() async {
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      await box.put('upgrade_prompt', <String, dynamic>{
        if (firstSeenAt != null)
          'first_seen_at': firstSeenAt!.millisecondsSinceEpoch,
        if (lastShownAt != null)
          'last_shown_at': lastShownAt!.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}

/// 권유 다이얼로그 표시 조건을 체크하고, 충족 시 표시한다.
/// 호출 시점: 도안/카운터 저장 후, 마이페이지 진입 시 등.
///
/// [patternCount] 현재 사용자 도안 수
/// [counterTotalTaps] 카운터 누적 탭수 (있을 때만, 없으면 0)
Future<void> maybeShowAccountUpgradeDialog(
  BuildContext context,
  WidgetRef ref, {
  int patternCount = 0,
  int counterTotalTaps = 0,
}) async {
  // 익명 사용자가 아니면 절대 표시 안 함
  final isAnonymous = ref.read(isAnonymousUserProvider);
  if (!isAnonymous) return;

  final state = _UpgradePromptState.read();
  final now = DateTime.now();

  // 첫 진입 시각 기록 (아직 없으면)
  if (state.firstSeenAt == null) {
    await _UpgradePromptState(firstSeenAt: now, lastShownAt: state.lastShownAt)
        .persist();
  }
  final firstSeenAt = state.firstSeenAt ?? now;

  // 주 1회만 표시
  if (state.lastShownAt != null) {
    final since = now.difference(state.lastShownAt!);
    if (since.inDays < 7) return;
  }

  // 트리거 조건 — 셋 중 하나
  final hasEnoughPatterns = patternCount >= 5;
  final hasEnoughTaps = counterTotalTaps >= 100;
  final hasEnoughDays = now.difference(firstSeenAt).inDays >= 7;
  if (!hasEnoughPatterns && !hasEnoughTaps && !hasEnoughDays) return;

  if (!context.mounted) return;
  await _showDialog(context, ref);

  // 표시 시각 기록 (사용자가 [지금 만들기] 또는 [다음에] 어느 쪽을 눌렀든)
  await _UpgradePromptState(firstSeenAt: firstSeenAt, lastShownAt: now)
      .persist();
}

/// "Pro는 회원가입 후 이용할 수 있어요" — Pro 결제 차단 시 호출.
/// 데이터 기반 권유와 달리 빈도 제한 없이 즉시 표시.
Future<void> showProUpgradeBlockedDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final isKorean = ref.read(appLanguageProvider).isKorean;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AccountUpgradeDialog(
      isKorean: isKorean,
      title: isKorean ? 'Pro는 계정이 필요해요' : 'Pro requires an account',
      message: isKorean
          ? 'Pro는 계정을 만든 후 이용하실 수 있어요.\n지금 게스트 모드에서 작업한 내용은 계정에 그대로 연결돼요.'
          : 'Pro is available after creating an account.\nYour current guest data will be linked to your new account.',
      primaryLabel: isKorean ? '계정 만들기' : 'Create account',
      secondaryLabel: isKorean ? '다음에' : 'Later',
    ),
  );
  if (result == true && context.mounted) {
    // #757 — '회원가입하기' 다이얼로그 confirm 시 로그인 화면이 아닌 가입 시트로 직접 연결.
    showSignUpSheet(context, ref, true);
  }
}

Future<void> _showDialog(BuildContext context, WidgetRef ref) async {
  final isKorean = ref.read(appLanguageProvider).isKorean;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AccountUpgradeDialog(
      isKorean: isKorean,
      title: isKorean ? '계정을 만드시겠어요?' : 'Create an account?',
      message: isKorean
          ? '계정을 만들면 도안과 작업 기록이\n기기를 바꿔도 안전하게 보존돼요.'
          : 'Create an account to keep your patterns\nand progress safe across devices.',
      primaryLabel: isKorean ? '지금 만들기' : 'Create now',
      secondaryLabel: isKorean ? '다음에' : 'Later',
    ),
  );
  if (result == true && context.mounted) {
    // #757 — '회원가입하기' 다이얼로그 confirm 시 로그인 화면이 아닌 가입 시트로 직접 연결.
    showSignUpSheet(context, ref, true);
  }
}

class _AccountUpgradeDialog extends StatelessWidget {
  final bool isKorean;
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;

  const _AccountUpgradeDialog({
    required this.isKorean,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: C.lvL,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add_alt_1_rounded,
                color: C.lvD, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: T.h3)),
        ],
      ),
      content: Text(message, style: T.body.copyWith(height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(secondaryLabel, style: TextStyle(color: C.mu)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: C.lv,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(primaryLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
