// 이슈 #847 — 핸들 없는 가입자(소셜 로그인 + 기존 사용자)가 메인 진입 전
// 강제로 핸들을 등록하도록 차단하는 풀스크린 게이트.
//
// 사용:
//   main_shell.dart 진입 시 `currentUserProvider.handle` 가 비어있고
//   익명(`isAnonymousUserProvider == false`) 이면 본 화면을 강제 표시.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../data/handle_validator.dart';

enum _HandleStatus { idle, checking, available, invalidFormat, taken, error }

class HandleRegisterScreen extends ConsumerStatefulWidget {
  const HandleRegisterScreen({super.key});

  @override
  ConsumerState<HandleRegisterScreen> createState() =>
      _HandleRegisterScreenState();
}

class _HandleRegisterScreenState extends ConsumerState<HandleRegisterScreen> {
  final _ctrl = TextEditingController();
  _HandleStatus _status = _HandleStatus.idle;
  String? _error;
  bool _saving = false;

  final _validator = HandleValidator();

  Future<void> _check(String raw) async {
    final input = HandleValidator.normalize(raw);
    if (input.isEmpty) {
      setState(() {
        _status = _HandleStatus.idle;
        _error = null;
      });
      return;
    }
    if (!HandleValidator.isValidHandleFormat(input)) {
      setState(() {
        _status = _HandleStatus.invalidFormat;
        _error = null;
      });
      return;
    }
    setState(() {
      _status = _HandleStatus.checking;
      _error = null;
    });
    try {
      final ok = await _validator.isHandleAvailable(input);
      if (!mounted) return;
      setState(() {
        _status = ok ? _HandleStatus.available : _HandleStatus.taken;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _HandleStatus.error);
    }
  }

  Future<void> _save(bool isKorean) async {
    final input = HandleValidator.normalize(_ctrl.text);
    if (_status != _HandleStatus.available || input.isEmpty) {
      setState(() {
        _error = isKorean
            ? '핸들을 확인해 주세요. (영문/숫자 3~20자, 중복 불가)'
            : 'Please check the handle (3-20 alphanumeric, unique).';
      });
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => _validator.reserveHandle(uid: user.uid, handle: input),
      );
      // currentUserProvider 가 users 문서 stream 이므로 자동 갱신 → 가드 통과 → 메인 진입
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final isAvailable = _status == _HandleStatus.available;
    final statusText = switch (_status) {
      _HandleStatus.idle => '',
      _HandleStatus.checking => isKorean ? '확인 중...' : 'Checking...',
      _HandleStatus.available => isKorean ? '✓ 사용 가능' : '✓ Available',
      _HandleStatus.invalidFormat =>
        isKorean ? '영문 소문자/숫자/_ 3~20자' : '3-20 lowercase/digit/_',
      _HandleStatus.taken => isKorean ? '이미 사용 중' : 'Already taken',
      _HandleStatus.error => isKorean ? '확인 실패' : 'Check failed',
    };
    final statusColor = switch (_status) {
      _HandleStatus.available => C.lmD,
      _HandleStatus.checking => C.mu,
      _HandleStatus.idle => Colors.transparent,
      _ => C.og,
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Icon(Icons.alternate_email_rounded, size: 56, color: C.lv),
              const SizedBox(height: 16),
              Text(
                isKorean ? '핸들을 등록해 주세요' : 'Register your handle',
                style: T.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isKorean
                    ? '다른 회원이 모리톡에서 당신을 찾는 데 사용됩니다.\n핸들 없이는 메인 화면에 진입할 수 없습니다.'
                    : 'Used by others to find you in MoriTalk.\nMain screens are locked until you set a handle.',
                style: T.body.copyWith(color: C.mu, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _ctrl,
                onChanged: _check,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isKorean ? '핸들' : 'Handle',
                  hintText: isKorean ? '예: koyunsuk' : 'e.g. koyunsuk',
                  prefix: Text('@',
                      style: TextStyle(color: C.mu, fontWeight: FontWeight.w500)),
                  filled: true,
                  fillColor: C.gx,
                  helperText: statusText.isEmpty ? null : statusText,
                  helperStyle: T.caption.copyWith(color: statusColor),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: T.caption.copyWith(color: C.og), textAlign: TextAlign.center),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: (!isAvailable || _saving) ? null : () => _save(isKorean),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isKorean ? '핸들 등록 후 시작' : 'Register and continue',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
