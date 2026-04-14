import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/web_utils_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.js_interop) '../../../core/utils/web_utils.dart';
import '../../../providers/auth_provider.dart';
import 'landing_scaffold.dart';

const String _mainAppUrl = 'https://moriknit-ceea9.web.app';

class LandingSignupScreen extends ConsumerStatefulWidget {
  const LandingSignupScreen({super.key, this.source});

  final String? source;

  @override
  ConsumerState<LandingSignupScreen> createState() => _LandingSignupScreenState();
}

class _LandingSignupScreenState extends ConsumerState<LandingSignupScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  String? _error;
  bool _loading = false;
  late final StreamSubscription<User?> _sub;

  @override
  void initState() {
    super.initState();
    // 이미 로그인된 경우 메인 앱으로 이동
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        goToWebUrl(_mainAppUrl);
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _pwCtrl.text.trim();
    if (!RegExp(r'^\d{6,}$').hasMatch(pw)) {
      setState(() => _error = '비밀번호는 숫자 6자리 이상이어야 합니다.');
      return;
    }
    if (pw != _pw2Ctrl.text.trim()) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _emailCtrl.text.trim();
      await repo.signUpWithEmail(
        email: email,
        password: pw,
        displayName: email.split('@').first,
        signupSource: widget.source ?? 'landing',
      );
      // authStateChanges listener가 앱으로 리다이렉트 처리
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return LandingScaffold(
      backgroundColor: C.bg,
      slivers: [
        SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 440 : double.infinity),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('회원가입', style: T.h1),
                      const SizedBox(height: 8),
                      Text(
                        '무료로 시작해보세요. 베타 기간 Pro 플랜 무료 제공.',
                        style: T.body.copyWith(color: C.tx2),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          hintText: 'example@email.com',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pwCtrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                          hintText: '숫자 6자리 이상',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pw2Ctrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '비밀번호 확인',
                          hintText: '비밀번호를 다시 입력하세요',
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: T.caption.copyWith(color: const Color(0xFFDC2626)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: C.lv,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('가입하기',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('이미 계정이 있으신가요?',
                              style: T.body.copyWith(color: C.tx2)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              '로그인',
                              style: T.bodyBold.copyWith(color: C.lv),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
    );
  }
}
