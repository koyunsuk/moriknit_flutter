import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../data/handle_validator.dart';
import 'social_login_button.dart';

/// #771 — 핸들 입력 상태.
enum _HandleStatus { idle, checking, available, invalidFormat, taken, error }

/// #759 — 회원가입 중단(취소/네트워크 등) 시 한글 알림팝업.
/// 기술적 에러 코드는 사용자에게 노출하지 않고 디버그 콘솔에만 기록.
Future<void> _showSignupNotCompletedDialog(BuildContext context, Object error, bool isKorean) async {
  debugPrint('[SignUp] 회원가입 중단: $error');
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: C.og.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.info_outline, color: C.og, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isKorean ? '회원가입이 완료되지 않았습니다' : 'Signup was not completed',
              style: T.h3,
            ),
          ),
        ],
      ),
      content: Text(
        isKorean
            ? '다시 시도하시려면 가입 버튼을 다시 눌러주세요.'
            : 'To try again, please tap the signup button again.',
        style: T.body.copyWith(height: 1.5),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: C.lv,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(isKorean ? '확인' : 'OK',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void showSignUpSheet(BuildContext context, WidgetRef ref, bool isMounted) {
  final emailCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  final pw2Ctrl = TextEditingController();
  final referrerCtrl = TextEditingController();
  // #771 — 핸들(@아이디) 입력
  final handleCtrl = TextEditingController();
  final t = ref.read(appStringsProvider);
  final isKorean = ref.read(appLanguageProvider).isKorean;
  String? sheetError;
  bool sheetLoading = false;
  // #771 — 핸들 검증 상태
  _HandleStatus handleStatus = _HandleStatus.idle;
  Timer? handleDebounce;
  final handleValidator = HandleValidator();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.createAccount, style: T.h2),
                const SizedBox(height: 16),
                // #728 — 카카오톡 회원가입 (이메일/비번 위에 노출)
                if (!kIsWeb) ...[
                  SocialLoginButton(
                    color: const Color(0xFFFEE500),
                    textColor: const Color(0xFF191919),
                    label: isKorean
                        ? '카카오톡으로 회원가입'
                        : 'Sign up with Kakao',
                    leading: const _KakaoSignUpIcon(),
                    onTap: sheetLoading
                        ? null
                        : () async {
                            final nav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(ctx);
                            final referrerInput = referrerCtrl.text.trim();
                            // #771 — 핸들 검증 통과해야 가입 진행 (빈 핸들 허용).
                            final handleInput =
                                HandleValidator.normalize(handleCtrl.text);
                            if (handleInput.isNotEmpty &&
                                handleStatus != _HandleStatus.available) {
                              setSheetState(() {
                                sheetError = isKorean
                                    ? '핸들을 확인해 주세요. (형식 또는 중복)'
                                    : 'Please check the handle (format or duplicate).';
                              });
                              return;
                            }
                            String? resolvedReferrerId;
                            if (referrerInput.isNotEmpty) {
                              resolvedReferrerId =
                                  await _resolveReferrerId(referrerInput);
                            }
                            if (!ctx.mounted) return;
                            try {
                              UserModelLite? created;
                              await runWithMoriLoadingDialog<void>(
                                ctx,
                                message: isKorean
                                    ? '카카오로 회원가입 중입니다.'
                                    : 'Signing up with Kakao...',
                                subtitle: isKorean
                                    ? '잠시만 기다려 주세요.'
                                    : 'Please wait.',
                                task: () async {
                                  final res = await ref
                                      .read(authRepositoryProvider)
                                      .signUpWithKakao(
                                        referrerInput: referrerInput.isEmpty
                                            ? null
                                            : referrerInput,
                                        referrerId: resolvedReferrerId,
                                      );
                                  if (res != null) {
                                    created = UserModelLite(uid: res.uid);
                                  }
                                },
                              );
                              // #771 — 핸들 reservation (가입 성공 후).
                              if (created != null && handleInput.isNotEmpty) {
                                await _tryReserveHandle(
                                  validator: handleValidator,
                                  uid: created!.uid,
                                  handle: handleInput,
                                  messenger: messenger,
                                  isKorean: isKorean,
                                );
                              }
                              nav.pop();
                              showSavedSnackBar(
                                messenger,
                                message: isKorean
                                    ? '카카오 회원가입이 완료됐어요.'
                                    : 'Kakao signup complete.',
                              );
                            } catch (e) {
                              // #760 — 취소 시 익명 사용자 잔재가 남지 않도록 정리.
                              await _signOutIfAnonymous(ref);
                              if (!ctx.mounted) return;
                              // #759 — 인라인 영문 에러 대신 한글 알림팝업.
                              await _showSignupNotCompletedDialog(ctx, e, isKorean);
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                ],
                // #753 — 구글 회원가입 (모바일·웹 공통)
                SocialLoginButton(
                  color: Colors.white,
                  textColor: const Color(0xFF1F1F1F),
                  label: isKorean ? '구글로 회원가입' : 'Sign up with Google',
                  leading: const _GoogleSignUpIcon(),
                  onTap: sheetLoading
                      ? null
                      : () async {
                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(ctx);
                          final referrerInput = referrerCtrl.text.trim();
                          // #771 — 핸들 검증 통과해야 가입 진행 (빈 핸들 허용).
                          final handleInput =
                              HandleValidator.normalize(handleCtrl.text);
                          if (handleInput.isNotEmpty &&
                              handleStatus != _HandleStatus.available) {
                            setSheetState(() {
                              sheetError = isKorean
                                  ? '핸들을 확인해 주세요. (형식 또는 중복)'
                                  : 'Please check the handle (format or duplicate).';
                            });
                            return;
                          }
                          String? resolvedReferrerId;
                          if (referrerInput.isNotEmpty) {
                            resolvedReferrerId =
                                await _resolveReferrerId(referrerInput);
                          }
                          if (!ctx.mounted) return;
                          try {
                            UserModelLite? created;
                            await runWithMoriLoadingDialog<void>(
                              ctx,
                              message: isKorean
                                  ? '구글로 회원가입 중입니다.'
                                  : 'Signing up with Google...',
                              subtitle: isKorean
                                  ? '잠시만 기다려 주세요.'
                                  : 'Please wait.',
                              task: () async {
                                final res = await ref
                                    .read(authRepositoryProvider)
                                    .signUpWithGoogle(
                                      referrerInput: referrerInput.isEmpty
                                          ? null
                                          : referrerInput,
                                      referrerId: resolvedReferrerId,
                                    );
                                if (res != null) {
                                  created = UserModelLite(uid: res.uid);
                                }
                              },
                            );
                            // #771 — 핸들 reservation (가입 성공 후).
                            if (created != null && handleInput.isNotEmpty) {
                              await _tryReserveHandle(
                                validator: handleValidator,
                                uid: created!.uid,
                                handle: handleInput,
                                messenger: messenger,
                                isKorean: isKorean,
                              );
                            }
                            nav.pop();
                            showSavedSnackBar(
                              messenger,
                              message: isKorean
                                  ? '구글 회원가입이 완료됐어요.'
                                  : 'Google signup complete.',
                            );
                          } catch (e) {
                            // #760 — 취소 시 익명 사용자 잔재가 남지 않도록 정리.
                            await _signOutIfAnonymous(ref);
                            if (!ctx.mounted) return;
                            // #759 — 인라인 영문 에러 대신 한글 알림팝업.
                            await _showSignupNotCompletedDialog(ctx, e, isKorean);
                          }
                        },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Divider(color: C.bd2)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        isKorean ? '또는 이메일로 가입' : 'or sign up with email',
                        style: T.caption.copyWith(color: C.mu),
                      ),
                    ),
                    Expanded(child: Divider(color: C.bd2)),
                  ],
                ),
                const SizedBox(height: 12),
                // #771 — 핸들(@아이디) 입력 (이메일 위에 노출)
                TextField(
                  controller: handleCtrl,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    hintText: isKorean ? '핸들 (@아이디)' : 'Handle (@id)',
                    helperText: isKorean
                        ? '소문자/숫자/_ 3~20자. 가입 후에도 마이페이지에서 변경 가능해요.'
                        : 'Lowercase/digits/_ 3-20. Editable later in My Page.',
                    helperMaxLines: 2,
                    prefixText: '@',
                    suffixIcon: _buildHandleSuffix(handleStatus),
                  ),
                  onChanged: (raw) {
                    handleDebounce?.cancel();
                    final normalized = HandleValidator.normalize(raw);
                    if (normalized.isEmpty) {
                      setSheetState(() {
                        handleStatus = _HandleStatus.idle;
                      });
                      return;
                    }
                    if (!HandleValidator.isValidHandleFormat(normalized)) {
                      setSheetState(() {
                        handleStatus = _HandleStatus.invalidFormat;
                      });
                      return;
                    }
                    setSheetState(() {
                      handleStatus = _HandleStatus.checking;
                    });
                    handleDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () async {
                        try {
                          final ok = await handleValidator
                              .isHandleAvailable(normalized);
                          if (!ctx.mounted) return;
                          setSheetState(() {
                            handleStatus = ok
                                ? _HandleStatus.available
                                : _HandleStatus.taken;
                          });
                        } catch (_) {
                          if (!ctx.mounted) return;
                          setSheetState(() {
                            handleStatus = _HandleStatus.error;
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(hintText: t.email),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pwCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: t.passwordHint),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pw2Ctrl,
                  obscureText: true,
                  decoration: InputDecoration(hintText: t.confirmPassword),
                ),
                const SizedBox(height: 10),
                // #737 — 추천인 아이디 (선택)
                TextField(
                  controller: referrerCtrl,
                  decoration: InputDecoration(
                    hintText: isKorean
                        ? '추천인 아이디 (선택)'
                        : 'Referrer ID (optional)',
                    helperText: isKorean
                        ? '추천인의 이메일 또는 displayName을 입력해 주세요.'
                        : "Enter the referrer's email or displayName.",
                    helperMaxLines: 2,
                  ),
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: 8),
                  Text(sheetError!, style: T.caption.copyWith(color: const Color(0xFFDC2626))),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: sheetLoading
                      ? null
                      : () async {
                          final pw = pwCtrl.text;
                          if (!RegExp(r'^\d{6,}$').hasMatch(pw)) {
                            setSheetState(() {
                              sheetError = isKorean
                                  ? '비밀번호는 숫자 6자리 이상이어야 합니다.'
                                  : 'Password must be 6 or more digits.';
                            });
                            return;
                          }
                          if (pw != pw2Ctrl.text) {
                            setSheetState(() {
                              sheetError = t.passwordsDoNotMatch;
                            });
                            return;
                          }
                          // #771 — 핸들 입력 시 검증 통과해야 가입 진행 (빈 핸들 허용).
                          final handleInput =
                              HandleValidator.normalize(handleCtrl.text);
                          if (handleInput.isNotEmpty &&
                              handleStatus != _HandleStatus.available) {
                            setSheetState(() {
                              sheetError = isKorean
                                  ? '핸들을 확인해 주세요. (형식 또는 중복)'
                                  : 'Please check the handle (format or duplicate).';
                            });
                            return;
                          }
                          setSheetState(() {
                            sheetLoading = true;
                            sheetError = null;
                          });
                          try {
                            final repo = ref.read(authRepositoryProvider);
                            final nav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(ctx);
                            final referrerInput = referrerCtrl.text.trim();
                            // 추천인 검증 (입력값이 있을 때만) — 실재 사용자 확인.
                            // 검증 실패해도 가입은 막지 않고 referrerId 만 비움 (UX 보호).
                            String? resolvedReferrerId;
                            if (referrerInput.isNotEmpty) {
                              resolvedReferrerId =
                                  await _resolveReferrerId(referrerInput);
                            }
                            final created = await repo.signUpWithEmail(
                              email: emailCtrl.text.trim(),
                              password: pwCtrl.text,
                              displayName: emailCtrl.text.split('@').first,
                            );
                            // referrerId / referrerInput 을 users/{uid}에 별도 기록.
                            // 가입 후 즉시 머지 → 가입 데이터 보존.
                            if (created != null && referrerInput.isNotEmpty) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(created.uid)
                                    .set({
                                  'referrerInput': referrerInput,
                                  'referrerId': ?resolvedReferrerId,
                                }, SetOptions(merge: true));
                              } catch (_) {
                                // 추천인 기록 실패는 가입 자체를 막지 않음
                              }
                            }
                            // #771 — 핸들 reservation (가입 성공 후).
                            // 실패해도 가입 자체는 진행 — 사용자에게 마이페이지 안내.
                            if (created != null && handleInput.isNotEmpty) {
                              await _tryReserveHandle(
                                validator: handleValidator,
                                uid: created.uid,
                                handle: handleInput,
                                messenger: messenger,
                                isKorean: isKorean,
                              );
                            }
                            nav.pop();
                          } catch (e) {
                            setSheetState(() {
                              sheetError = e.toString();
                              sheetLoading = false;
                            });
                          }
                        },
                  child: sheetLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(t.createAccount),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// #771 — 카카오/구글 가입 결과에서 uid만 캡쳐하기 위한 경량 보관용 객체.
class UserModelLite {
  final String uid;
  const UserModelLite({required this.uid});
}

/// #771 — 핸들 reservation 헬퍼.
/// 실패해도 가입 자체는 진행되며, 사용자에게 마이페이지 안내만 노출.
Future<void> _tryReserveHandle({
  required HandleValidator validator,
  required String uid,
  required String handle,
  required ScaffoldMessengerState messenger,
  required bool isKorean,
}) async {
  try {
    await validator.reserveHandle(uid: uid, handle: handle);
  } catch (e) {
    debugPrint('[SignUp] 핸들 reservation 실패: $e');
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isKorean
              ? '핸들은 마이페이지에서 다시 설정할 수 있어요.'
              : 'You can set the handle again from My Page.',
        ),
      ),
    );
  }
}

/// #771 — 핸들 입력란 suffix 아이콘 (검증 상태별).
Widget? _buildHandleSuffix(_HandleStatus status) {
  switch (status) {
    case _HandleStatus.idle:
      return null;
    case _HandleStatus.checking:
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    case _HandleStatus.available:
      return Icon(Icons.check_circle_rounded, color: C.lmD, size: 20);
    case _HandleStatus.invalidFormat:
    case _HandleStatus.taken:
    case _HandleStatus.error:
      return Icon(Icons.cancel_rounded, color: C.og, size: 20);
  }
}

/// #760 — 회원가입 취소 시 익명(게스트) 사용자가 남아 있으면 정리.
/// 가입 도중 어떤 흐름이든 익명으로 자동 전환되는 잔재를 차단.
Future<void> _signOutIfAnonymous(WidgetRef ref) async {
  try {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null && user.isAnonymous) {
      await ref.read(authRepositoryProvider).signOut();
    }
  } catch (e) {
    debugPrint('[SignUp] 익명 정리 실패: $e');
  }
}

/// 추천인 아이디 검증 — 이메일 또는 displayName으로 매칭되는 사용자 uid 반환.
/// 매칭 실패 시 null (가입 자체는 진행).
Future<String?> _resolveReferrerId(String input) async {
  final db = FirebaseFirestore.instance;
  try {
    // 이메일 우선 매칭
    if (input.contains('@')) {
      final snap = await db
          .collection('users')
          .where('email', isEqualTo: input)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first.id;
    }
    // displayName 매칭
    final snap = await db
        .collection('users')
        .where('displayName', isEqualTo: input)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
  } catch (_) {
    // 검증 실패 (네트워크/권한) 시 null
  }
  return null;
}

/// 카카오톡 회원가입 버튼 아이콘 (login_screen 의 _KakaoIcon 과 동일한 외형).
class _KakaoSignUpIcon extends StatelessWidget {
  const _KakaoSignUpIcon();

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

/// #753 — 구글 회원가입 버튼 아이콘 (Google G 모노).
class _GoogleSignUpIcon extends StatelessWidget {
  const _GoogleSignUpIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDADCE0)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
