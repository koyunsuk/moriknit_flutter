// lib/features/cloud_integrations/presentation/google_drive_screen.dart
//
// 이슈 #703 — 외부 클라우드 확장 (기본 코드)
// Google Drive 진입 화면. 드롭박스 (`dropbox_screen.dart`) 패턴 모방.
// 인증 stub — "연결하기" 버튼 누르면 UnimplementedError → 친화 메시지 SnackBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../data/google_drive_auth_provider.dart';

const Color _kGoogleBlue = Color(0xFF1A73E8);

class GoogleDriveScreen extends ConsumerWidget {
  const GoogleDriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(googleDriveAuthProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return AppShellScaffold(
      title: 'Google Drive',
      subtitle: auth.isLoggedIn
          ? (isKorean
              ? '${auth.email ?? ''} 연결됨'
              : 'Connected as ${auth.email ?? ''}')
          : (isKorean
              ? 'Google 드라이브 계정을 연결하세요'
              : 'Connect your Google Drive account'),
      trailing: auth.isLoggedIn
          ? [
              TextButton(
                onPressed: () => ref
                    .read(googleDriveAuthProvider.notifier)
                    .logout(),
                child: Text(
                  isKorean ? '연결 해제' : 'Disconnect',
                  style: T.caption.copyWith(color: C.og),
                ),
              ),
            ]
          : null,
      body: auth.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _kGoogleBlue))
          : auth.isLoggedIn
              ? _FileListPlaceholder(isKorean: isKorean)
              : _ConnectPrompt(isKorean: isKorean),
    );
  }
}

// ── 연결 전 화면 ─────────────────────────────────────────────────────────────
class _ConnectPrompt extends ConsumerWidget {
  const _ConnectPrompt({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(googleDriveAuthProvider);

    Future<void> handleLogin() async {
      try {
        await ref.read(googleDriveAuthProvider.notifier).login();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean
                  ? 'Google Drive 연동은 준비 중이에요. 곧 만나요!'
                  : 'Google Drive integration is coming soon!',
            ),
          ),
        );
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kGoogleBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.cloud_rounded,
                  color: _kGoogleBlue, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              isKorean ? 'Google Drive를 연결하세요' : 'Connect Google Drive',
              style: T.h3,
            ),
            const SizedBox(height: 10),
            Text(
              isKorean
                  ? 'Google 드라이브에 저장된 도안 파일을 앱에서 바로 탐색할 수 있어요.'
                  : 'Browse pattern files stored in your Google Drive.',
              style: T.body.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (auth.error != null) ...[
              Text(auth.error!,
                  style: T.caption.copyWith(color: C.og),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: auth.isLoading ? null : handleLogin,
                icon: const Icon(Icons.cloud_rounded, size: 20),
                label:
                    Text(isKorean ? 'Google Drive 연결하기' : 'Connect Google Drive'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGoogleBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: T.bodyBold.copyWith(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 파일 목록 placeholder ────────────────────────────────────────────────────
class _FileListPlaceholder extends StatelessWidget {
  const _FileListPlaceholder({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: C.mu),
            const SizedBox(height: 12),
            Text(
              isKorean ? '파일 목록을 불러오는 중...' : 'Loading file list...',
              style: T.body.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
