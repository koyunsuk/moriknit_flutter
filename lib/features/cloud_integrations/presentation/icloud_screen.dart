// lib/features/cloud_integrations/presentation/icloud_screen.dart
//
// 이슈 #703 — 외부 클라우드 확장 (기본 코드)
// iCloud Drive 진입 화면. 드롭박스 (`dropbox_screen.dart`) 패턴 모방.
// iCloud는 iOS 전용 — Android/웹에서는 비활성 안내.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../data/icloud_auth_provider.dart';

const Color _kAppleGray = Color(0xFF1D1D1F);

bool get _isIOS {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS;
  } catch (_) {
    return false;
  }
}

class ICloudScreen extends ConsumerWidget {
  const ICloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(iCloudAuthProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return AppShellScaffold(
      title: 'iCloud Drive',
      subtitle: auth.isLoggedIn
          ? (isKorean
              ? '${auth.email ?? ''} 연결됨'
              : 'Connected as ${auth.email ?? ''}')
          : (isKorean
              ? 'iCloud 계정을 연결하세요'
              : 'Connect your iCloud account'),
      trailing: auth.isLoggedIn
          ? [
              TextButton(
                onPressed: () => ref
                    .read(iCloudAuthProvider.notifier)
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
              child: CircularProgressIndicator(color: _kAppleGray))
          : !_isIOS
              ? _PlatformGuard(isKorean: isKorean)
              : auth.isLoggedIn
                  ? _FileListPlaceholder(isKorean: isKorean)
                  : _ConnectPrompt(isKorean: isKorean),
    );
  }
}

// ── 비-iOS 플랫폼 안내 ─────────────────────────────────────────────────────────
class _PlatformGuard extends StatelessWidget {
  const _PlatformGuard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
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
                color: _kAppleGray.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.phone_iphone_rounded,
                  color: _kAppleGray, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              isKorean ? 'iOS에서만 사용할 수 있어요' : 'iOS only',
              style: T.h3,
            ),
            const SizedBox(height: 10),
            Text(
              isKorean
                  ? 'iCloud Drive 연결은 iPhone·iPad의 모리니트 앱에서만 사용할 수 있어요.\n다른 클라우드(Dropbox, Google Drive, OneDrive)를 이용해 주세요.'
                  : 'iCloud Drive is available only on the iOS app.\nPlease use Dropbox, Google Drive, or OneDrive on other platforms.',
              style: T.body.copyWith(color: C.mu),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 연결 전 화면 ─────────────────────────────────────────────────────────────
class _ConnectPrompt extends ConsumerWidget {
  const _ConnectPrompt({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(iCloudAuthProvider);

    Future<void> handleLogin() async {
      try {
        await ref.read(iCloudAuthProvider.notifier).login();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean
                  ? 'iCloud Drive 연동은 준비 중이에요. 곧 만나요!'
                  : 'iCloud Drive integration is coming soon!',
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
                color: _kAppleGray.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.cloud_rounded,
                  color: _kAppleGray, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              isKorean ? 'iCloud Drive를 연결하세요' : 'Connect iCloud Drive',
              style: T.h3,
            ),
            const SizedBox(height: 10),
            Text(
              isKorean
                  ? 'iCloud에 저장된 도안 파일을 앱에서 바로 탐색할 수 있어요.'
                  : 'Browse pattern files stored in your iCloud Drive.',
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
                label: Text(
                    isKorean ? 'iCloud Drive 연결하기' : 'Connect iCloud Drive'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAppleGray,
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
