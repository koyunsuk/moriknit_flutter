import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/subscription_constants.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
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
  bool _obscure = true;
  bool _rememberMe = true;
  bool _adminMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    C.apply(AppThemeMode.lavender);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appThemeProvider.notifier).resetTheme();
    });
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final settings = box.get('settings');
      if (settings != null && settings['remember_me'] == false) {
        _rememberMe = false;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    C.apply(AppThemeMode.lavender);
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRememberMe(bool value) async {
    try {
      final box = Hive.box<Map>(SubscriptionConstants.boxUser);
      final current = Map<String, dynamic>.from(box.get('settings') ?? <String, dynamic>{});
      current['remember_me'] = value;
      await box.put('settings', current);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isWideWeb = kIsWeb && MediaQuery.of(context).size.width >= 720;

    if (isWideWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F3F5),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  // Left brand panel
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [C.lv.withValues(alpha: 0.18), C.pk.withValues(alpha: 0.12)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          bottomLeft: Radius.circular(24),
                        ),
                      ),
                      child: const _LoginBrandPanel(),
                    ),
                  ),
                  // Right login form
                  SizedBox(
                    width: 400,
                    child: LoginPanel(
                      emailCtrl: _emailCtrl,
                      pwCtrl: _pwCtrl,
                      loading: _loading,
                      obscure: _obscure,
                      rememberMe: _rememberMe,
                      error: _error,
                      adminMode: _adminMode,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onRememberMeChanged: (v) {
                        setState(() => _rememberMe = v);
                        _saveRememberMe(v);
                      },
                      onAdminModeChanged: (v) => setState(() => _adminMode = v),
                      onLoginEmail: _loginEmail,
                      onLoginGoogle: _loginGoogle,
                      onShowSignUp: () => showSignUpSheet(context, ref, mounted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: C.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              C.bg,
              Color.alphaBlend(C.pk.withValues(alpha: 0.07), C.bg),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const BgOrbs(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 392),
                  child: LoginPanel(
                    emailCtrl: _emailCtrl,
                    pwCtrl: _pwCtrl,
                    loading: _loading,
                    obscure: _obscure,
                    rememberMe: _rememberMe,
                    error: _error,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onRememberMeChanged: (v) {
                      setState(() => _rememberMe = v);
                      _saveRememberMe(v);
                    },
                    onLoginEmail: _loginEmail,
                    onLoginGoogle: _loginGoogle,
                    onShowSignUp: () => showSignUpSheet(context, ref, mounted),
                  ),
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
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: _emailCtrl.text.trim(),
            password: _pwCtrl.text,
          );
      if (mounted && _adminMode) context.go(Routes.admin);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted && _adminMode) context.go(Routes.admin);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

Future<void> showWebLoginOverlayDialog(
  BuildContext context, {
  String? title,
  String? message,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _LoginOverlayCard(title: title, message: message),
      ),
    ),
  );
}

class _LoginOverlayCard extends ConsumerStatefulWidget {
  final String? title;
  final String? message;

  const _LoginOverlayCard({this.title, this.message});

  @override
  ConsumerState<_LoginOverlayCard> createState() => _LoginOverlayCardState();
}

class _LoginOverlayCardState extends ConsumerState<_LoginOverlayCard> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LoginPanel(
              emailCtrl: _emailCtrl,
              pwCtrl: _pwCtrl,
              loading: _loading,
              obscure: _obscure,
              rememberMe: _rememberMe,
              error: _error,
              title: widget.title,
              message: widget.message,
              showOverlayIntro: true,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onRememberMeChanged: (v) => setState(() => _rememberMe = v),
              onLoginEmail: _loginEmail,
              onLoginGoogle: _loginGoogle,
              onShowSignUp: () => showSignUpSheet(context, ref, mounted),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loginEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: _emailCtrl.text.trim(),
            password: _pwCtrl.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class LoginPanel extends ConsumerWidget {
  final TextEditingController emailCtrl;
  final TextEditingController pwCtrl;
  final bool loading;
  final bool obscure;
  final bool rememberMe;
  final String? error;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onLoginEmail;
  final VoidCallback onLoginGoogle;
  final VoidCallback onShowSignUp;
  final bool showOverlayIntro;
  final String? title;
  final String? message;
  final bool adminMode;
  final ValueChanged<bool>? onAdminModeChanged;

  const LoginPanel({
    super.key,
    required this.emailCtrl,
    required this.pwCtrl,
    required this.loading,
    required this.obscure,
    required this.rememberMe,
    required this.error,
    required this.onToggleObscure,
    required this.onRememberMeChanged,
    required this.onLoginEmail,
    required this.onLoginGoogle,
    required this.onShowSignUp,
    this.showOverlayIntro = false,
    this.title,
    this.message,
    this.adminMode = false,
    this.onAdminModeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    final t = ref.watch(appStringsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        children: [
          if (showOverlayIntro && (title != null || message != null)) ...[
            if (title != null) Text(title!, style: T.h3, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: T.body.copyWith(color: C.tx2), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 14),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: C.bd2),
                boxShadow: [
                  BoxShadow(
                    color: C.lv.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset('assets/login_logo.png', fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SocialLoginButton(
            color: Colors.white.withValues(alpha: 0.92),
            textColor: C.tx,
            label: t.continueWithGoogle,
            leading: const _GoogleIcon(),
            onTap: onLoginGoogle,
          ),
          const SizedBox(height: 8),
          _ComingSoonButton(
            color: const Color(0xFFFEE500),
            textColor: const Color(0xFF191919),
            label: t.continueWithKakao,
            leading: const _KakaoIcon(),
            badgeLabel: t.preparing,
          ),
          const SizedBox(height: 8),
          _ComingSoonButton(
            color: const Color(0xFF111111).withValues(alpha: 0.88),
            textColor: Colors.white,
            label: t.continueWithApple,
            leading: const _AppleIcon(),
            badgeLabel: t.preparing,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: C.bd2)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(t.orSignInWithEmail, style: T.caption),
                ),
                Expanded(child: Divider(color: C.bd2)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.bd2),
              boxShadow: [
                BoxShadow(
                  color: C.lv.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: t.email,
                    prefixIcon: Icon(Icons.mail_outline_rounded, color: C.mu, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.bd),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.bd),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.lv, width: 1.6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pwCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: t.password,
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: C.mu, size: 20),
                    suffixIcon: GestureDetector(
                      onTap: onToggleObscure,
                      child: Icon(
                        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: C.mu,
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.bd),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.bd),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.lv, width: 1.6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error!,
                      style: T.caption.copyWith(color: const Color(0xFFDC2626)),
                    ),
                  ),
                ],
                Row(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Checkbox(
                        value: rememberMe,
                        activeColor: C.lv,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (v) => onRememberMeChanged(v ?? true),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(t.rememberMe, style: T.caption.copyWith(color: C.tx2)),
                    if (kIsWeb && onAdminModeChanged != null) ...[
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: adminMode,
                          activeColor: C.og,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) => onAdminModeChanged!(v ?? false),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('관리자', style: T.caption.copyWith(color: adminMode ? C.og : C.tx2)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : onLoginEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            t.logIn,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onShowSignUp,
            child: RichText(
              text: TextSpan(
                style: T.caption,
                children: [
                  TextSpan(text: t.noAccountYet),
                  TextSpan(
                    text: t.createOne,
                    style: T.captionBold.copyWith(color: C.lvD),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LangChip(
                label: AppLanguage.ko.label,
                selected: language == AppLanguage.ko,
                onTap: () => ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.ko),
              ),
              const SizedBox(width: 8),
              _LangChip(
                label: AppLanguage.en.label,
                selected: language == AppLanguage.en,
                onTap: () => ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.en),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.57, 3.14, true, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 1.57, 1.57, true, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 3.14, 0.785, true, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 3.925, 0.785, true, paint);

    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.58, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(cx, cy - r * 0.15, r * 0.95, r * 0.3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KakaoIcon extends StatelessWidget {
  const _KakaoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFF191919),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'K',
          style: TextStyle(
            color: Color(0xFFFEE500),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AppleIcon extends StatelessWidget {
  const _AppleIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.apple, color: Colors.white, size: 20);
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.lvL : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.lvD : C.bd),
        ),
        child: Text(
          label,
          style: T.caption.copyWith(
            color: selected ? C.lvD : C.mu,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MoriLogo(size: 72),
          const SizedBox(height: 20),
          const MoriKnitTitle(fontSize: 28),
          const SizedBox(height: 12),
          Text(
            '뜨개 프로젝트, 스와치,\n커뮤니티를 한곳에서',
            style: T.h2.copyWith(height: 1.5),
          ),
          const SizedBox(height: 32),
          ...[
            (Icons.folder_special_rounded, '프로젝트 기록', C.lv),
            (Icons.grid_view_rounded, '스와치 보관함', C.lmD),
            (Icons.storefront_rounded, '도안 마켓', C.pkD),
            (Icons.people_alt_rounded, '커뮤니티', C.og),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: item.$3.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.$1, size: 18, color: item.$3),
                  ),
                  const SizedBox(width: 12),
                  Text(item.$2, style: T.bodyBold.copyWith(color: C.tx2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonButton extends StatelessWidget {
  final Color color;
  final Color textColor;
  final String label;
  final Widget leading;
  final String badgeLabel;

  const _ComingSoonButton({
    required this.color,
    required this.textColor,
    required this.label,
    required this.leading,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: SocialLoginButton(
        color: color,
        textColor: textColor,
        label: label,
        leading: leading,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeLabel,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        onTap: null,
      ),
    );
  }
}
