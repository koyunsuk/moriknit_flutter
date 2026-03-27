import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

void showSignUpSheet(BuildContext context, WidgetRef ref, bool isMounted) {
  final emailCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  final pw2Ctrl = TextEditingController();
  String? sheetError;
  bool sheetLoading = false;

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
                Text('Create account', style: T.h2),
                const SizedBox(height: 20),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Password (6+ chars)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pw2Ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Confirm password'),
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
                          if (pwCtrl.text != pw2Ctrl.text) {
                            setSheetState(() {
                              sheetError = 'Passwords do not match.';
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
                            await repo.signUpWithEmail(
                              email: emailCtrl.text.trim(),
                              password: pwCtrl.text,
                              displayName: emailCtrl.text.split('@').first,
                            );
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
                      : const Text('Create account'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

