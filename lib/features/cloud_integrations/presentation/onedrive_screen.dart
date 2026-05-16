// lib/features/cloud_integrations/presentation/onedrive_screen.dart
//
// 이슈 #703 — 외부 클라우드 확장 (기본 코드)
// Microsoft OneDrive 진입 화면. 드롭박스 (`dropbox_screen.dart`) 패턴 모방.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../data/onedrive_auth_provider.dart';

const Color _kOneDriveBlue = Color(0xFF0078D4);

class OneDriveScreen extends ConsumerWidget {
  const OneDriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(oneDriveAuthProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return AppShellScaffold(
      title: 'OneDrive',
      subtitle: auth.isLoggedIn
          ? (isKorean
              ? '${auth.email ?? ''} 연결됨'
              : 'Connected as ${auth.email ?? ''}')
          : (isKorean
              ? 'Microsoft 계정을 연결하세요'
              : 'Connect your Microsoft account'),
      trailing: auth.isLoggedIn
          ? [
              TextButton(
                onPressed: () => ref
                    .read(oneDriveAuthProvider.notifier)
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
              child:
                  CircularProgressIndicator(color: _kOneDriveBlue))
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
    final auth = ref.watch(oneDriveAuthProvider);

    Future<void> handleLogin() async {
      try {
        await ref.read(oneDriveAuthProvider.notifier).login();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean
                  ? 'OneDrive 연동은 준비 중이에요. 곧 만나요!'
                  : 'OneDrive integration is coming soon!',
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
                color: _kOneDriveBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.cloud_rounded,
                  color: _kOneDriveBlue, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              isKorean ? 'OneDrive를 연결하세요' : 'Connect OneDrive',
              style: T.h3,
            ),
            const SizedBox(height: 10),
            Text(
              isKorean
                  ? 'OneDrive에 저장된 도안 파일을 앱에서 바로 탐색할 수 있어요.'
                  : 'Browse pattern files stored in your OneDrive.',
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
                label: Text(isKorean ? 'OneDrive 연결하기' : 'Connect OneDrive'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOneDriveBlue,
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
