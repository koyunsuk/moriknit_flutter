import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../auth/domain/user_model.dart';
import 'bug_report_sheet.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: userAsync.when(
        data: (user) {
          final resolvedUser = user ?? UserModel(uid: authUser?.uid ?? '', email: authUser?.email ?? '', displayName: authUser?.displayName ?? '', photoURL: authUser?.photoURL ?? '');
          return _MyPageBody(user: resolvedUser);
        },
        loading: () => Center(child: CircularProgressIndicator(color: C.lv)),
        error: (e, _) => Center(child: Text('Failed to load profile: $e', style: T.body)),
      ),
    );
  }
}

class _MyPageBody extends ConsumerStatefulWidget {
  final UserModel user;
  const _MyPageBody({required this.user});

  @override
  ConsumerState<_MyPageBody> createState() => _MyPageBodyState();
}

class _MyPageBodyState extends ConsumerState<_MyPageBody> {
  bool _profileExpanded = false;
  bool _uploadingPhoto = false;

  UserModel get user => widget.user;

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await repo.uploadProfilePhotoBytes(user.uid, bytes);
      } else {
        await repo.uploadProfilePhoto(user.uid, File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(appLanguageProvider).isKorean ? '사진 업로드 실패: $e' : 'Photo upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editDisplayName(BuildContext context, AppStrings t) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: user.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.displayName, style: T.h3),
        content: TextField(
          controller: controller,
          style: T.body,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.84),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.bd)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.bd)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == user.displayName) return;
    if (!mounted) return;
    try {
      // ignore: use_build_context_synchronously
      await runWithMoriLoadingDialog<void>(
        this.context,
        message: '저장하는 중입니다.',
        subtitle: '잠시만 기다려 주세요.',
        task: () => ref.read(authRepositoryProvider).updateDisplayName(user.uid, result),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('별명 변경 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final currentTheme = ref.watch(appThemeProvider);
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final counterCount = ref.watch(counterCountProvider);
    final purchasesAsync = ref.watch(myPurchasesProvider);
    final marketItemsAsync = ref.watch(myMarketItemsProvider);
    final salesAsync = ref.watch(myMarketSalesProvider);
    final name = user.displayName.isNotEmpty ? user.displayName : (user.email.isNotEmpty ? user.email.split('@').first : 'Maker');
    final photo = user.photoURL;
    final firstLetter = name.isNotEmpty ? name.characters.first.toUpperCase() : 'M';
    final joinedDate = user.createdAt ?? user.lastActiveAt;

    return Stack(
      children: [
        const BgOrbs(),
        SafeArea(
          child: Column(
            children: [
              MoriPageHeaderShell(
                maxWidth: 920,
                padding: EdgeInsets.zero,
                child: MoriBrandHeader(subtitle: t.yourKnittingIdentity),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      // ── 1. 기본정보 ─────────────────────────────────
                      SectionTitle(title: isKorean ? '기본정보' : 'Basic Info'),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _profileExpanded = !_profileExpanded),
                        child: GlassCard(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // 프로필 사진 + 편집 버튼
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                radius: 38,
                                backgroundColor: C.lvL,
                                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                child: photo.isEmpty
                                    ? Text(firstLetter, style: TextStyle(fontSize: 24, color: C.lvD, fontWeight: FontWeight.w700))
                                    : null,
                              ),
                              if (_uploadingPhoto)
                                Positioned.fill(
                                  child: CircleAvatar(
                                    radius: 38,
                                    backgroundColor: Colors.black.withValues(alpha: 0.42),
                                    child: const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: C.lvD,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.settings_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 별명 + 편집 아이콘
                                Row(
                                  children: [
                                    Expanded(child: Text(name, style: T.h2)),
                                    TextButton(
                                      onPressed: () => _editDisplayName(context, t),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(isKorean ? '닉네임 변경' : 'Edit name', style: T.caption.copyWith(color: C.lvD)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(user.email.isEmpty ? t.noEmailConnected : user.email, style: T.body.copyWith(color: C.mu)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    MoriChip(label: _planLabel(t, user.subscription.planId), type: ChipType.lavender),
                                    MoriChip(label: photo.isEmpty ? t.defaultAvatar : t.socialPhoto, type: ChipType.pink),
                                    MoriChip(label: language.label, type: ChipType.white),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _profileExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: C.mu,
                          ),
                        ],
                      ),
                      if (user.bio.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(14)),
                          child: Text(user.bio, style: T.body.copyWith(color: C.tx2)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                      if (_profileExpanded) ...[
                        const SizedBox(height: 16),
                        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.profileOverview, style: T.bodyBold), const SizedBox(height: 12), _InfoRow(label: t.displayName, value: name), _InfoRow(label: t.userId, value: user.uid.isEmpty ? t.notAvailable : user.uid), _InfoRow(label: t.email, value: user.email.isEmpty ? t.notConnected : user.email), _InfoRow(label: t.joined, value: joinedDate == null ? t.unknown : _formatDate(joinedDate)), _InfoRow(label: t.lastActive, value: user.lastActiveAt == null ? t.unknown : _formatDate(user.lastActiveAt!))])),
                        const SizedBox(height: 16),
                        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.accountConnections, style: T.bodyBold), const SizedBox(height: 12), _InfoRow(label: t.plan, value: _planLabel(t, user.subscription.planId)), _InfoRow(label: t.status, value: user.subscription.status), _InfoRow(label: t.profilePhoto, value: photo.isEmpty ? t.usingDefaultAvatar : t.importedFromSocial), _InfoRow(label: t.signInSync, value: _socialSyncLabel(t, photo: photo, displayName: user.displayName, email: user.email))])),
                      ],
                      const SizedBox(height: 20),

                      // ── 2. 필수정보 ───────────────────────────────
                      SectionTitle(title: isKorean ? '필수정보' : 'Essential Info'),
                      const SizedBox(height: 10),
                      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.usageSnapshot, style: T.bodyBold), const SizedBox(height: 12), _UsageRow(label: t.swatchLibrary, caption: t.liveSaved(swatchCount, user.usage.swatchCount), current: swatchCount, stored: user.usage.swatchCount, color: C.lv), const SizedBox(height: 10), _UsageRow(label: t.projectBoard, caption: t.liveSaved(projectCount, user.usage.projectCount), current: projectCount, stored: user.usage.projectCount, color: C.pk), const SizedBox(height: 10), _UsageRow(label: isKorean ? '카운터 기록' : 'Counter records', caption: t.liveSaved(counterCount, user.usage.counterCount), current: counterCount, stored: user.usage.counterCount, color: C.lmD)])),
                      const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(child: _ProfileStat(label: t.swatches, value: '$swatchCount', accent: C.lvD, onTap: () => context.push('/swatch'))),
                    Expanded(child: _ProfileStat(label: t.projects, value: '$projectCount', accent: C.pkD, onTap: () => context.push('/project'))),
                    Expanded(child: _ProfileStat(label: isKorean ? '카운터' : 'Counters', value: '$counterCount', accent: C.lmD, onTap: () => context.push('/counters'))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: purchasesAsync.when(
                      data: (items) => _SummaryCard(
                        title: isKorean ? '구매 요약' : 'Purchase summary',
                        countLabel: isKorean ? '구매 수' : 'Orders',
                        countValue: '${items.length}',
                        amountLabel: isKorean ? '구매 합계' : 'Spent',
                        amountValue: _formatWon(items.fold<int>(0, (sum, item) => sum + item.price), isKorean),
                        accent: C.pkD,
                      ),
                      loading: () => _LoadingSummaryCard(color: C.pkD),
                      error: (e, _) => _ErrorCard(message: '$e'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: salesAsync.when(
                      data: (items) => _SummaryCard(
                        title: isKorean ? '마켓 수익' : 'Market earnings',
                        countLabel: isKorean ? '판매 수' : 'Sales',
                        countValue: '${items.length}',
                        amountLabel: isKorean ? '누적 수익' : 'Revenue',
                        amountValue: _formatWon(items.fold<int>(0, (sum, item) => sum + item.price), isKorean),
                        accent: C.lmD,
                      ),
                      loading: () => _LoadingSummaryCard(color: C.lmD),
                      error: (e, _) => _ErrorCard(message: '$e'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isKorean ? '내 구매' : 'My purchases', style: T.bodyBold),
                            const SizedBox(height: 6),
                            Text(isKorean ? '최근 구입한 상품을 확인해요.' : 'See your latest purchases.', style: T.caption.copyWith(color: C.mu)),
                            const SizedBox(height: 12),
                            purchasesAsync.when(
                              data: (items) => items.isEmpty
                                  ? Text(isKorean ? '아직 구매한 상품이 없어요.' : 'No purchases yet.', style: T.caption.copyWith(color: C.mu))
                                  : Column(children: items.take(4).map((item) => _LedgerRow(title: item.title, subtitle: _formatWon(item.price, isKorean), accent: C.pkD)).toList()),
                              loading: () => CircularProgressIndicator(color: C.lv),
                              error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isKorean ? '내 마켓' : 'My market', style: T.bodyBold),
                            const SizedBox(height: 6),
                            Text(isKorean ? '등록한 상품을 관리해요.' : 'Manage your listings.', style: T.caption.copyWith(color: C.mu)),
                            const SizedBox(height: 12),
                            marketItemsAsync.when(
                              data: (items) => items.isEmpty
                                  ? Text(isKorean ? '등록한 상품이 아직 없어요.' : 'No listed items yet.', style: T.caption.copyWith(color: C.mu))
                                  : Column(
                                      children: items.take(4).map((item) => _LedgerRow(title: item.title, subtitle: _formatWon(item.price, isKorean), accent: C.lmD)).toList(),
                                    ),
                              loading: () => CircularProgressIndicator(color: C.lv),
                              error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 3. 개인설정 ───────────────────────────────────────
              Text(isKorean ? '개인설정' : 'Personal settings', style: T.bodyBold.copyWith(color: C.tx2)),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.languageLabel, style: T.bodyBold),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: C.gx,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.bd),
                      ),
                      child: DropdownButton<AppLanguage>(
                        value: language,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: T.caption.copyWith(color: C.tx),
                        dropdownColor: C.bg,
                        items: AppLanguage.values
                            .map((l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l.label, style: T.caption.copyWith(color: C.tx)),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) ref.read(appLanguageProvider.notifier).setLanguage(value);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(isKorean ? '테마 컬러' : 'Theme color', style: T.bodyBold),
                    const SizedBox(height: 8),
                    // 테마 리스트
                    Column(
                      children: AppThemeMode.values.map((mode) {
                        final tc = AppThemeColors.of(mode);
                        final isSelected = mode == currentTheme;
                        return GestureDetector(
                          onTap: () => ref.read(appThemeProvider.notifier).setTheme(mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? C.lvL : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? C.lv : C.bd,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // 컬러 점 3개
                                Container(width: 14, height: 14, decoration: BoxDecoration(color: tc.pk, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Container(width: 14, height: 14, decoration: BoxDecoration(color: tc.lv, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Container(width: 14, height: 14, decoration: BoxDecoration(color: tc.lmD, shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isKorean ? mode.label : mode.labelEn,
                                    style: T.body.copyWith(
                                      color: isSelected ? C.lvD : C.tx,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_rounded, size: 18, color: C.lvD),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 4. 회사정보 ───────────────────────────────────────
              SectionTitle(title: isKorean ? '회사정보' : 'Company Info'),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.language_rounded, color: C.lvD),
                      title: Text(isKorean ? '공식 웹사이트' : 'Official website'),
                      subtitle: const Text('www.moriknit.com'),
                      onTap: () => launchUrl(Uri.parse('https://www.moriknit.com'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.camera_alt_outlined, color: C.pkD),
                      title: const Text('Instagram'),
                      subtitle: const Text('@moriknit_official'),
                      onTap: () => launchUrl(Uri.parse('https://instagram.com/moriknit'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.play_circle_fill_rounded, color: C.og),
                      title: const Text('YouTube'),
                      subtitle: Text(isKorean ? '모리니트 채널' : 'MoriKnit Channel'),
                      onTap: () => launchUrl(Uri.parse('https://youtube.com/@moriknit_official'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.description_outlined, color: C.mu),
                      title: Text(isKorean ? '이용약관' : 'Terms of service'),
                      onTap: () => launchUrl(Uri.parse('https://www.moriknit.com/terms'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.privacy_tip_outlined, color: C.mu),
                      title: Text(isKorean ? '개인정보처리방침' : 'Privacy policy'),
                      onTap: () => launchUrl(Uri.parse('https://www.moriknit.com/privacy'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.info_outline, color: C.mu),
                      title: Text(isKorean ? '버전 정보' : 'Version info'),
                      subtitle: const Text('1.0.0+1'),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.bug_report_outlined, color: C.og),
                      title: Text(isKorean ? '버그 / 의견 제출' : 'Report a bug'),
                      subtitle: Text(isKorean ? '불편한 점이나 개선 의견을 알려주세요' : 'Let us know what to fix or improve'),
                      onTap: () => showBugReportSheet(context, ref, user),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                child: Column(children: [
                  ListTile(
                    leading: Icon(Icons.logout, color: C.og),
                    title: Text(t.logout),
                    subtitle: Text(t.logoutDescription),
                    onTap: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ]),
              ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _planLabel(AppStrings t, String planId) {
    switch (planId.toLowerCase()) {
      case 'starter':
        return t.starterPlan;
      case 'pro':
        return t.proPlan;
      case 'business':
        return t.businessPlan;
      default:
        return t.freePlan;
    }
  }

  String _socialSyncLabel(AppStrings t, {required String photo, required String displayName, required String email}) {
    if (photo.isNotEmpty || displayName.isNotEmpty) return t.importedProfile;
    if (email.isNotEmpty) return t.emailOnlyProfile;
    return t.noProviderProfile;
  }

  String _formatDate(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  String _formatWon(int amount, bool isKorean) => isKorean ? '$amount원' : '$amount KRW';
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final VoidCallback? onTap;
  const _ProfileStat({required this.label, required this.value, required this.accent, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [Text(value, style: T.numLG.copyWith(color: accent)), const SizedBox(height: 4), Text(label, style: T.caption)]),
  );
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String countLabel;
  final String countValue;
  final String amountLabel;
  final String amountValue;
  final Color accent;
  const _SummaryCard({required this.title, required this.countLabel, required this.countValue, required this.amountLabel, required this.amountValue, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: T.bodyBold),
          const SizedBox(height: 12),
          _SummaryMetric(label: countLabel, value: countValue, accent: accent),
          const SizedBox(height: 10),
          _SummaryMetric(label: amountLabel, value: amountValue, accent: accent),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _SummaryMetric({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: accent.withValues(alpha: 0.16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(label, style: T.caption.copyWith(color: C.mu)), const SizedBox(height: 4), Text(value, style: T.bodyBold.copyWith(color: accent))]),
    );
  }
}

class _LoadingSummaryCard extends StatelessWidget {
  final Color color;
  const _LoadingSummaryCard({required this.color});
  @override
  Widget build(BuildContext context) => GlassCard(child: SizedBox(height: 116, child: Center(child: CircularProgressIndicator(color: color))));
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => GlassCard(child: Text(message, style: T.caption.copyWith(color: C.og)));
}

class _LedgerRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  const _LedgerRow({required this.title, required this.subtitle, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bd)),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: T.body)),
          Text(subtitle, style: T.captionBold.copyWith(color: accent)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(label, style: T.captionBold.copyWith(color: C.mu))), Expanded(child: Text(value, style: T.body))]));
}

class _UsageRow extends StatelessWidget {
  final String label;
  final String caption;
  final int current;
  final int stored;
  final Color color;
  const _UsageRow({required this.label, required this.caption, required this.current, required this.stored, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: T.captionBold.copyWith(color: C.mu)), Text(caption, style: T.caption.copyWith(color: color))]), const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: current == 0 ? 0 : (stored == 0 ? 0.15 : (current / (stored > current ? stored : current)).clamp(0.0, 1.0)), minHeight: 6, backgroundColor: color.withValues(alpha: 0.14), valueColor: AlwaysStoppedAnimation(color)))]);
  }
}
