import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _pwCtrl = TextEditingController();
  bool _confirmed = false;
  bool _loading = false;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  String get _providerType {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'email';
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('google.com')) return 'google';
    if (providers.contains('oidc.kakao')) return 'kakao';
    return 'email';
  }

  Future<void> _deleteAccount() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(authRepositoryProvider);

    setState(() => _loading = true);
    try {
      // 이메일 계정: 비밀번호로 재인증
      if (_providerType == 'email') {
        final user = FirebaseAuth.instance.currentUser;
        if (user?.email == null) throw Exception(isKorean ? '이메일 정보를 찾을 수 없어요.' : 'Email not found.');
        await repo.reauthWithEmail(email: user!.email!, password: _pwCtrl.text.trim());
      } else if (_providerType == 'google') {
        await repo.reauthWithGoogle();
      }
      // 계정 삭제
      await repo.deleteAccount();
      if (!mounted) return;
      context.go('/login');
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      final msg = e.code == 'requires-recent-login'
          ? (isKorean ? '보안을 위해 다시 로그인 후 시도해 주세요.' : 'Please sign in again for security.')
          : e.code == 'wrong-password'
              ? (isKorean ? '비밀번호가 올바르지 않아요.' : 'Incorrect password.')
              : '${e.message}';
      messenger.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    } catch (e) {
      setState(() => _loading = false);
      final errStr = '$e'.toLowerCase();
      final isCancelled = errStr.contains('cancel') || errStr.contains('sign_in_failed') || errStr.contains('network_error');
      final msg = isCancelled
          ? (isKorean ? '구글 재인증이 취소되었습니다. 다시 시도해 주세요.' : 'Google re-authentication was cancelled.')
          : (isKorean ? '오류가 발생했습니다. 다시 시도해 주세요.' : 'An error occurred. Please try again.');
      messenger.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final provider = _providerType;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => context.pop(),
        ),
        title: Text(isKorean ? '회원 탈퇴' : 'Delete Account', style: T.h3),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 경고 배너
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.og.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.og.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: C.og, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            isKorean ? '탈퇴 전 꼭 확인하세요' : 'Please read before deleting',
                            style: T.bodyBold.copyWith(color: C.og),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...[
                        isKorean ? '모든 프로젝트, 스와치, 카운터 기록이 삭제됩니다.' : 'All projects, swatches, and counter records will be deleted.',
                        isKorean ? '작성한 게시글과 댓글도 함께 삭제됩니다.' : 'Your posts and comments will also be removed.',
                        isKorean ? '삭제된 데이터는 복구할 수 없습니다.' : 'Deleted data cannot be recovered.',
                        isKorean ? '구독 중인 경우 서비스를 먼저 해지해 주세요.' : 'Cancel your subscription before deleting.',
                      ].map((msg) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Icon(Icons.circle, size: 6, color: C.og),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(msg, style: T.body.copyWith(color: C.tx2, height: 1.4))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 이메일 계정: 비밀번호 확인
                if (provider == 'email') ...[
                  SectionTitle(title: isKorean ? '비밀번호 확인' : 'Confirm Password'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isKorean ? '현재 비밀번호' : 'Current password',
                      hintText: isKorean ? '비밀번호를 입력해 주세요' : 'Enter your password',
                      filled: true,
                      fillColor: C.gx,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  GlassCard(
                    child: Row(
                      children: [
                        Icon(
                          provider == 'google' ? Icons.g_mobiledata_rounded : Icons.chat_bubble_rounded,
                          color: C.lv,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isKorean
                                ? '${provider == 'google' ? '구글' : '카카오'} 계정으로 로그인됨\n탈퇴 시 ${provider == 'google' ? '구글' : '카카오'} 재인증이 진행됩니다.'
                                : 'Signed in with ${provider == 'google' ? 'Google' : 'Kakao'}\nYou will be asked to re-authenticate.',
                            style: T.body.copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 동의 체크박스
                GestureDetector(
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: _confirmed ? C.og : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _confirmed ? C.og : C.bd, width: 1.5),
                        ),
                        child: _confirmed
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isKorean
                              ? '위 내용을 모두 확인하였으며, 회원 탈퇴에 동의합니다.'
                              : 'I have read the above and agree to delete my account.',
                          style: T.body.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 탈퇴 버튼
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (!_confirmed || _loading)
                        ? null
                        : (provider == 'email' && _pwCtrl.text.trim().isEmpty)
                            ? null
                            : _deleteAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.og,
                      disabledBackgroundColor: C.bd,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            isKorean ? '회원 탈퇴' : 'Delete My Account',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      isKorean ? '취소하고 돌아가기' : 'Cancel',
                      style: T.caption.copyWith(color: C.mu),
                    ),
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
