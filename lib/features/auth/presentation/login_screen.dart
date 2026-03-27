import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import 'sign_up_sheet.dart';
import 'social_login_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [C.bg, Color(0xFFFFEEF6)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const BgOrbs(),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    MoriBrandHeader(
                      logoSize: 100,
                      titleSize: 28,
                      subtitle: isKorean
                          ? '스와치, 프로젝트, 카운터를 한곳에서 기록하고 이어가세요.'
                          : 'Keep your swatches, projects, and counters in one place.',
                      includeUrl: true,
                    ),
                    const SizedBox(height: 28),
                    SocialLoginButton(
                      color: const Color(0xFFFEE500),
                      textColor: const Color(0xFF191919),
                      label: isKorean ? '카카오톡으로 계속하기' : 'Continue with Kakao',
                      leading: const _KakaoIcon(),
                      onTap: _loginKakao,
                    ),
                    const SizedBox(height: 12),
                    SocialLoginButton(
                      color: Colors.white.withValues(alpha: 0.88),
                      textColor: C.tx,
                      label: isKorean ? 'Google로 계속하기' : 'Continue with Google',
                      leading: const _GoogleIcon(),
                      onTap: _loginGoogle,
                    ),
                    const SizedBox(height: 12),
                    SocialLoginButton(
                      color: Colors.white.withValues(alpha: 0.88),
                      textColor: C.tx,
                      label: isKorean ? 'Apple로 계속하기' : 'Continue with Apple',
                      leading: const _AppleIcon(),
                      onTap: () {},
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: C.bd2)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(isKorean ? '또는' : 'or', style: T.caption),
                          ),
                          Expanded(child: Divider(color: C.bd2)),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(hintText: isKorean ? '이메일' : 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pwCtrl,
                      obscureText: true,
                      decoration: InputDecoration(hintText: isKorean ? '비밀번호' : 'Password'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: T.caption.copyWith(color: const Color(0xFFDC2626))),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _loginEmail,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isKorean ? '로그인' : 'Log in'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => showSignUpSheet(context, ref, mounted),
                      child: RichText(
                        text: TextSpan(
                          style: T.caption,
                          children: [
                            TextSpan(text: isKorean ? '아직 계정이 없나요? ' : 'No account yet? '),
                            TextSpan(
                              text: isKorean ? '새로 만들기' : 'Create one',
                              style: T.captionBold.copyWith(color: C.lvD),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithEmail(email: _emailCtrl.text.trim(), password: _pwCtrl.text);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithGoogle();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginKakao() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithKakao();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

class _KakaoIcon extends StatelessWidget {
  const _KakaoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.chat_bubble_rounded, size: 17, color: Color(0xFFFEE500)),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: const [
          Positioned(top: 5, child: CircleAvatar(radius: 3, backgroundColor: Color(0xFFEA4335))),
          Positioned(left: 5, child: CircleAvatar(radius: 3, backgroundColor: Color(0xFF4285F4))),
          Positioned(right: 5, child: CircleAvatar(radius: 3, backgroundColor: Color(0xFF34A853))),
          Positioned(bottom: 5, child: CircleAvatar(radius: 3, backgroundColor: Color(0xFFFBBC05))),
        ],
      ),
    );
  }
}

class _AppleIcon extends StatelessWidget {
  const _AppleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.apple_rounded, size: 18, color: Colors.white),
    );
  }
}
