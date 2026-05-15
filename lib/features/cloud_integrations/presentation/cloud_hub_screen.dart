// lib/features/cloud_integrations/presentation/cloud_hub_screen.dart
//
// 외부 연결 UI 단계 정리 — 클라우드 통합 허브
// 도구함 → "클라우드" 카드 클릭 시 진입.
// Dropbox / Google Drive / iCloud / OneDrive 4개 하위 카드로 분기.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../dropbox/data/dropbox_auth_provider.dart';
import '../data/google_drive_auth_provider.dart';
import '../data/icloud_auth_provider.dart';
import '../data/onedrive_auth_provider.dart';

class CloudHubScreen extends ConsumerWidget {
  const CloudHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '클라우드 연결' : 'Cloud Connections',
                    subtitle: isKorean
                        ? '클라우드 저장소를 연결해 도안 파일을 앱에서 바로 탐색하세요.'
                        : 'Connect cloud storage to browse pattern files directly.',
                    trailing: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
                        onPressed: () => Navigator.pop(context),
                        tooltip: isKorean ? '뒤로' : 'Back',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DropboxCard(isKorean: isKorean),
                        const SizedBox(height: 10),
                        _GoogleDriveCard(isKorean: isKorean),
                        const SizedBox(height: 10),
                        _ICloudCard(isKorean: isKorean),
                        const SizedBox(height: 10),
                        _OneDriveCard(isKorean: isKorean),
                      ],
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

class _DropboxCard extends ConsumerWidget {
  const _DropboxCard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(dropboxAuthProvider);
    const color = Color(0xFF0061FF);
    return GlassCard(
      onTap: () => context.push(Routes.dropbox),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Image.asset(
                'assets/cloud_icons/dropbox.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(Icons.cloud_rounded, color: color),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dropbox', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (isKorean ? '${auth.email ?? ''} 연결됨' : 'Connected as ${auth.email ?? ''}')
                      : (isKorean ? '드롭박스 도안 파일을 앱에서 탐색해요' : 'Browse your Dropbox pattern files'),
                  style: T.caption.copyWith(color: auth.isLoggedIn ? color : C.mu),
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn)
            const Icon(Icons.check_circle_rounded, color: color, size: 18)
          else
            Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

class _GoogleDriveCard extends ConsumerWidget {
  const _GoogleDriveCard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(googleDriveAuthProvider);
    const color = Color(0xFF1A73E8);
    return GlassCard(
      onTap: () => context.push(Routes.googleDrive),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Image.asset(
                'assets/cloud_icons/google_drive.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(Icons.cloud_rounded, color: color),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Google Drive', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (isKorean ? '${auth.email ?? ''} 연결됨' : 'Connected as ${auth.email ?? ''}')
                      : (isKorean ? 'Google 드라이브 도안 파일을 앱에서 탐색해요' : 'Browse your Google Drive pattern files'),
                  style: T.caption.copyWith(color: auth.isLoggedIn ? color : C.mu),
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn)
            const Icon(Icons.check_circle_rounded, color: color, size: 18)
          else
            Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

class _ICloudCard extends ConsumerWidget {
  const _ICloudCard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(iCloudAuthProvider);
    const color = Color(0xFF1D1D1F);
    return GlassCard(
      onTap: () => context.push(Routes.iCloud),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Image.asset(
                'assets/cloud_icons/icloud.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(Icons.cloud_rounded, color: color),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('iCloud Drive', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (isKorean ? '${auth.email ?? ''} 연결됨' : 'Connected as ${auth.email ?? ''}')
                      : (isKorean ? 'iCloud 도안 파일을 앱에서 탐색해요 (iOS 전용)' : 'Browse iCloud pattern files (iOS only)'),
                  style: T.caption.copyWith(color: auth.isLoggedIn ? color : C.mu),
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn)
            const Icon(Icons.check_circle_rounded, color: color, size: 18)
          else
            Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}

class _OneDriveCard extends ConsumerWidget {
  const _OneDriveCard({required this.isKorean});
  final bool isKorean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(oneDriveAuthProvider);
    const color = Color(0xFF0078D4);
    return GlassCard(
      onTap: () => context.push(Routes.oneDrive),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Image.asset(
                'assets/cloud_icons/onedrive.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(Icons.cloud_rounded, color: color),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OneDrive', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (isKorean ? '${auth.email ?? ''} 연결됨' : 'Connected as ${auth.email ?? ''}')
                      : (isKorean ? 'OneDrive 도안 파일을 앱에서 탐색해요' : 'Browse your OneDrive pattern files'),
                  style: T.caption.copyWith(color: auth.isLoggedIn ? color : C.mu),
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn)
            const Icon(Icons.check_circle_rounded, color: color, size: 18)
          else
            Icon(Icons.chevron_right_rounded, color: C.mu),
        ],
      ),
    );
  }
}
