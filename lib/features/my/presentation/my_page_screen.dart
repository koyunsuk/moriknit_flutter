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
import '../../../providers/app_config_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/fab_settings_provider.dart';
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

  Widget _buildSnapshotItem(String label, int count, int stored, Color color, VoidCallback onTap) {
    final progress = count == 0 ? 0.0 : (stored == 0 ? 0.15 : (count / (stored > count ? stored : count)).clamp(0.0, 1.0));
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: T.caption.copyWith(color: C.tx2), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('$count', style: T.bodyBold.copyWith(color: color, fontSize: 22, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: color.withValues(alpha: 0.14), valueColor: AlwaysStoppedAnimation(color)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final social = ref.watch(socialIntegrationsProvider).valueOrNull;
    final youtubeUrl = social?.youtubeUrl ?? 'https://www.youtube.com/@moriknit';
    final currentTheme = ref.watch(appThemeProvider);
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final counterCount = ref.watch(counterCountProvider);
    final purchasesAsync = ref.watch(myPurchasesProvider);
    final marketItemsAsync = ref.watch(myMarketItemsProvider);
    final salesAsync = ref.watch(myMarketSalesProvider);
    final name = user.displayName.isNotEmpty ? user.displayName : (user.email.isNotEmpty ? user.email.split('@').first : 'Maker');
    final photo = user.photoURL;

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
                      SectionTitle(title: isKorean ? '👤 기본정보' : '👤 Basic Info'),
                      const SizedBox(height: 10),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            radius: 24,
                            borderColor: C.lv.withValues(alpha: 0.16),
                            color: Color.alphaBlend(C.lv.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.88)),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // LEFT: 아바타 (고정 너비)
                                  SizedBox(
                                    width: 96,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Stack(
                                          children: [
                                            ClipOval(
                                              child: SizedBox(
                                                width: 80,
                                                height: 80,
                                                child: photo.isNotEmpty
                                                    ? Image.network(
                                                        photo,
                                                        width: 80,
                                                        height: 80,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, _, _) => const MoriDefaultAvatar(size: 80, borderRadius: 999),
                                                      )
                                                    : const MoriDefaultAvatar(size: 80, borderRadius: 999),
                                              ),
                                            ),
                                            if (_uploadingPhoto)
                                              Positioned.fill(
                                                child: CircleAvatar(
                                                  radius: 32,
                                                  backgroundColor: Colors.black.withValues(alpha: 0.42),
                                                  child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                                                ),
                                              ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: GestureDetector(
                                                onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: C.lvD,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                  child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 구분선
                                  Container(width: 1, color: C.bd.withValues(alpha: 0.5), margin: const EdgeInsets.symmetric(vertical: 4)),
                                  const SizedBox(width: 14),
                                  // RIGHT: 3단 정보 (고정 높이 셀)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // 1단: 이름 + 수정버튼
                                        SizedBox(
                                          height: 28,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: T.bodyBold,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => _editDisplayName(context, t),
                                                child: Icon(Icons.edit_rounded, size: 15, color: C.lv),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // 2단: 이메일
                                        SizedBox(
                                          height: 28,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Icon(Icons.mail_outline_rounded, size: 13, color: C.mu),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  user.email.isEmpty ? t.noEmailConnected : user.email,
                                                  style: T.bodyBold.copyWith(color: C.tx2),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // 3단: 특이사항 (플랜)
                                        SizedBox(
                                          height: 28,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: MoriChip(label: _planLabel(t, user.subscription.planId), type: ChipType.lavender),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (ref.watch(isProProvider))
                            Positioned(
                              top: -2,
                              left: 14,
                              child: CustomPaint(
                                size: const Size(18, 24),
                                painter: _ProBookmarkPainter(),
                                child: const SizedBox(
                                  width: 18,
                                  height: 24,
                                  child: Center(
                                    child: Text('PRO', style: TextStyle(color: Colors.white, fontSize: 5, fontWeight: FontWeight.w800, letterSpacing: 0.3, height: 1)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── 1-b. 구독 상태 ─────────────────────────────
                      SectionTitle(title: isKorean ? '💳 구독 정보' : '💳 Subscription'),
                      const SizedBox(height: 10),
                      _SubscriptionCard(user: user, isKorean: isKorean),
                      const SizedBox(height: 20),

                      // ── 2. 필수정보 ───────────────────────────────
                      SectionTitle(title: isKorean ? '📊 필수정보' : '📊 Essential Info'),
                      const SizedBox(height: 10),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📈 ${t.usageSnapshot}', style: T.bodyBold),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildSnapshotItem(t.swatchLibrary, swatchCount, user.usage.swatchCount, C.lv, () => context.push('/swatch'))),
                                Container(width: 1, height: 72, color: C.bd),
                                Expanded(child: _buildSnapshotItem(t.projectBoard, projectCount, user.usage.projectCount, C.pk, () => context.push('/project'))),
                                Container(width: 1, height: 72, color: C.bd),
                                Expanded(child: _buildSnapshotItem(isKorean ? '카운터' : 'Counters', counterCount, user.usage.counterCount, C.lmD, () => context.push('/counters'))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: purchasesAsync.when(
                      data: (items) => _SummaryCard(
                        title: isKorean ? '🛍️ 구매 요약' : '🛍️ Purchase summary',
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
                        title: isKorean ? '💰 마켓 수익' : '💰 Market earnings',
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
                            Text(isKorean ? '🧾 내 구매' : '🧾 My purchases', style: T.bodyBold),
                            const SizedBox(height: 6),
                            Text(isKorean ? '최근 구입한 상품을 확인해요.' : 'See your latest purchases.', style: T.caption.copyWith(color: C.tx2)),
                            const SizedBox(height: 12),
                            purchasesAsync.when(
                              data: (items) => items.isEmpty
                                  ? Column(children: List.generate(3, (_) => Container(height: 50, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bd.withValues(alpha: 0.5))))))
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
                            Text(isKorean ? '🏪 내 마켓' : '🏪 My market', style: T.bodyBold),
                            const SizedBox(height: 6),
                            Text(isKorean ? '등록한 상품을 관리해요.' : 'Manage your listings.', style: T.caption.copyWith(color: C.tx2)),
                            const SizedBox(height: 12),
                            marketItemsAsync.when(
                              data: (items) => items.isEmpty
                                  ? Column(children: List.generate(3, (_) => Container(height: 50, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bd.withValues(alpha: 0.5))))))
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
              SectionTitle(title: isKorean ? '⚙️ 개인설정' : '⚙️ Personal settings'),
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
                        menuMaxHeight: 280,
                        dropdownColor: C.bg,
                        style: T.bodyBold.copyWith(color: C.tx),
                        items: AppLanguage.values
                            .map((l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l.label, style: T.bodyBold.copyWith(color: C.tx)),
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
                        // 헤더 미리보기 색 계산 (C.headerBg 로직과 동기화)
                        final headerPreview = mode == AppThemeMode.moriMono
                            ? tc.bd
                            : mode == AppThemeMode.moriCream
                                ? tc.bg
                                : mode == AppThemeMode.jwiChuni
                                ? Color.alphaBlend(tc.pk.withValues(alpha: 0.28), tc.bg)
                                : Color.alphaBlend(tc.pk.withValues(alpha: 0.22), tc.bg);
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
                                // 미니 테마 프리뷰 (헤더 + 바디 + 포인트)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 48,
                                    height: 32,
                                    child: Column(
                                      children: [
                                        // 헤더 색
                                        Container(height: 10, color: headerPreview),
                                        // 바디 영역
                                        Expanded(
                                          child: Container(
                                            color: tc.bg,
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Row(
                                              children: [
                                                // 포인트(버튼) 색
                                                Container(
                                                  width: 16, height: 8,
                                                  decoration: BoxDecoration(
                                                    color: tc.pk,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                // 폰트 색 미리보기
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Container(height: 2, color: tc.tx),
                                                      const SizedBox(height: 2),
                                                      Container(height: 2, width: 14, color: tc.tx2),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 신호등 도트 (헤더색, 포인트색, lv색)
                                const SizedBox(width: 10),
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: headerPreview, shape: BoxShape.circle, border: Border.all(color: C.bd, width: 0.5))),
                                const SizedBox(width: 4),
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: tc.pk, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: tc.lv, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
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

              // ── 4. 퀵다이얼 설정 ─────────────────────────────────
              if (!kIsWeb) ...[
                SectionTitle(title: isKorean ? '⚡ 퀵다이얼 설정' : '⚡ Quick Dial Settings'),
                const SizedBox(height: 10),
                _FabSettingsCard(isKorean: isKorean),
                const SizedBox(height: 20),
              ],

              // ── 6. 회사정보 ───────────────────────────────────────
              SectionTitle(title: isKorean ? '🏢 회사정보' : '🏢 Company Info'),
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
                      subtitle: const Text('@moriknit'),
                      onTap: () => launchUrl(Uri.parse('https://instagram.com/moriknit'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.play_circle_fill_rounded, color: C.og),
                      title: const Text('YouTube'),
                      subtitle: Text(isKorean ? '모리니트 채널' : 'MoriKnit Channel'),
                      onTap: () => launchUrl(Uri.parse(youtubeUrl), mode: LaunchMode.externalApplication),
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
                  Divider(height: 1, color: Colors.grey.shade100),
                  ListTile(
                    leading: Icon(Icons.person_remove_outlined, color: C.mu),
                    title: Text(
                      isKorean ? '회원 탈퇴' : 'Delete Account',
                      style: T.body.copyWith(color: C.mu),
                    ),
                    subtitle: Text(
                      isKorean ? '모든 데이터가 영구 삭제됩니다' : 'All data will be permanently deleted',
                      style: T.caption.copyWith(color: C.mu),
                    ),
                    onTap: () => context.push('/my/delete-account'),
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

  String _formatWon(int amount, bool isKorean) => isKorean ? '$amount원' : '$amount KRW';
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
      padding: const EdgeInsets.all(18),
      radius: 22,
      borderColor: accent.withValues(alpha: 0.12),
      color: Color.alphaBlend(accent.withValues(alpha: 0.028), Colors.white.withValues(alpha: 0.86)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CardHeading(
            eyebrow: 'SUMMARY',
            title: title,
            subtitle: '',
          ),
          const SizedBox(height: 14),
          _SummaryMetric(label: countLabel, value: countValue, accent: accent),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: T.caption.copyWith(color: C.tx2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: T.bodyBold.copyWith(
              color: accent,
              fontSize: 20,
              letterSpacing: -0.25,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.bd.withValues(alpha: 0.92)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: T.body.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            subtitle,
            style: T.captionBold.copyWith(
              color: accent,
              fontSize: 12,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _CardHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: T.captionBold.copyWith(
            color: C.lvD.withValues(alpha: 0.92),
            letterSpacing: 1.15,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: T.bodyBold.copyWith(
            fontSize: 17.5,
            height: 1.22,
            letterSpacing: -0.15,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: T.caption.copyWith(
              color: C.tx2.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

// ── 퀵다이얼 설정 카드 ────────────────────────────────────────────────────────
class _FabSettingsCard extends ConsumerWidget {
  final bool isKorean;
  const _FabSettingsCard({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(fabSettingsProvider);

    final presets = [
      ('bottom', isKorean ? '하단' : 'Bottom'),
      ('middle', isKorean ? '중간' : 'Middle'),
      ('top', isKorean ? '상단' : 'Top'),
    ];

    String currentPreset = 'bottom';
    if (settings.bottomOffset > 350) {
      currentPreset = 'top';
    } else if (settings.bottomOffset > 100) {
      currentPreset = 'middle';
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 투명도 토글
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '반투명 모드' : 'Transparent Mode', style: T.bodyBold),
                    Text(isKorean ? '퀵다이얼 버튼을 반투명하게 표시' : 'Show quick dial buttons as semi-transparent',
                        style: T.caption.copyWith(color: C.tx2)),
                  ],
                ),
              ),
              Switch(
                value: settings.transparent,
                onChanged: (v) => ref.read(fabSettingsProvider.notifier).setTransparent(v),
                activeThumbColor: C.lv,
                activeTrackColor: C.lvL,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 스노우 효과 토글
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '스노우 효과' : 'Snow Effect', style: T.bodyBold),
                    Text(
                      isKorean ? '상단 스노우 효과를 켜거나 끌 수 있어요' : 'Toggle the snow effect at the top',
                      style: T.caption.copyWith(color: C.tx2),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.particleEnabled,
                onChanged: (v) => ref.read(fabSettingsProvider.notifier).setParticleEnabled(v),
                activeThumbColor: C.lv,
                activeTrackColor: C.lvL,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 파티클 종류 선택
          Opacity(
            opacity: settings.particleEnabled ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !settings.particleEnabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isKorean ? '효과 종류' : 'Effect Type', style: T.bodyBold),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final entry in const [
                        ('mori', '✨ 모리'),
                        ('heart', '💕 하트'),
                        ('cat', '🐾 동물'),
                        ('star', '⭐ 별'),
                        ('rainbow', '🌈 레인보우'),
                      ])
                        GestureDetector(
                          onTap: () => ref.read(fabSettingsProvider.notifier).setParticleType(entry.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: settings.particleType == entry.$1 ? C.lv : C.lvL,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: settings.particleType == entry.$1 ? C.lv : C.lv.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Text(
                              entry.$2,
                              style: T.caption.copyWith(
                                color: settings.particleType == entry.$1 ? Colors.white : C.lvD,
                                fontWeight: settings.particleType == entry.$1 ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 위치 프리셋
          Text(isKorean ? '기본 위치' : 'Default Position', style: T.bodyBold),
          const SizedBox(height: 8),
          Text(isKorean ? '버튼을 길게 드래그해서 자유롭게 이동할 수 있어요' : 'Long drag the buttons to move them freely',
              style: T.caption.copyWith(color: C.tx2)),
          const SizedBox(height: 10),
          Row(
            children: presets.map((e) {
              final (key, label) = e;
              final selected = currentPreset == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => ref.read(fabSettingsProvider.notifier).setPreset(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? C.lv : C.lvL,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? C.lv : C.lv.withValues(alpha: 0.20)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : C.lvD,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: T.captionBold.copyWith(
                  color: C.mu,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: T.body.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
}

// ── 구독 상태 카드 ──────────────────────────────────────────────────────────
class _SubscriptionCard extends ConsumerWidget {
  final UserModel user;
  final bool isKorean;
  const _SubscriptionCard({required this.user, required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gates = ref.watch(featureGatesProvider);
    final isPro = ref.watch(isProProvider);
    final isBusiness = gates.isBusiness;
    final remainingDays = ref.watch(proRemainingDaysProvider);
    final sub = user.subscription;
    final isTrial = sub.status == 'trial';

    final planLabel = isBusiness ? 'Business' : (isPro ? 'Pro' : 'Free');
    final planColor = isBusiness ? C.lmD : (isPro ? C.og : C.mu);

    final statusText = isTrial
        ? (isKorean ? '$planLabel — 무료 체험 중' : '$planLabel — Free trial')
        : isBusiness
            ? (isKorean ? 'Business — 활성' : 'Business — Active')
            : isPro
                ? (isKorean ? 'Pro — 활성' : 'Pro — Active')
                : (isKorean ? '무료 플랜' : 'Free plan');

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(isKorean ? '💎 현재 플랜' : '💎 Current plan', style: T.bodyBold),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: planColor.withValues(alpha: 0.3)),
                ),
                child: Text(planLabel, style: T.captionBold.copyWith(color: planColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // D-day 배너 (trial)
          if (isPro && isTrial && remainingDays != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: C.og.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.og.withValues(alpha: 0.20)),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(remainingDays == 0 ? 'D-Day' : 'D-$remainingDays',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: C.og, height: 1)),
                      const SizedBox(height: 2),
                      Text(isKorean ? '남음' : 'left', style: T.caption.copyWith(color: C.og)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Container(width: 1, height: 38, color: C.og.withValues(alpha: 0.20)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isKorean ? 'Pro 플랜 무료 체험 중' : 'Pro plan free trial',
                            style: T.captionBold.copyWith(color: C.og)),
                        if (sub.trialEndAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            isKorean ? '${_fmtDate(sub.trialEndAt!)} 만료' : 'Expires ${_fmtDate(sub.trialEndAt!)}',
                            style: T.caption.copyWith(color: C.og.withValues(alpha: 0.75)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 상태 + 주요 혜택 그리드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isPro ? C.lv.withValues(alpha: 0.07) : C.bd.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isPro ? C.lv.withValues(alpha: 0.15) : C.bd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: isPro ? C.lv : C.mu),
                    const SizedBox(width: 6),
                    Text(isKorean ? '상태' : 'Status', style: T.caption.copyWith(color: C.tx2)),
                    const Spacer(),
                    Text(statusText, style: T.captionBold.copyWith(color: isPro ? C.lv : C.tx)),
                  ],
                ),
                if (sub.currentPeriodEnd != null && isPro) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 11, color: C.mu),
                      const SizedBox(width: 6),
                      Text(isKorean ? '다음 결제일' : 'Next billing', style: T.caption.copyWith(color: C.tx2)),
                      const Spacer(),
                      Text(_fmtDate(sub.currentPeriodEnd!), style: T.captionBold.copyWith(color: C.tx)),
                    ],
                  ),
                ],
                if (sub.cancelAtPeriodEnd) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 11, color: C.og),
                      const SizedBox(width: 6),
                      Text(isKorean ? '해지 예약됨' : 'Cancellation scheduled',
                          style: T.caption.copyWith(color: C.og)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 플랜 혜택 요약
          const SizedBox(height: 10),
          if (isBusiness) ...[
            // 비즈니스 전용 혜택 2행
            _PlanBadgeRow(badges: [
              (isKorean ? '무제한' : 'Unlimited', true),
              ('PDF판매', true),
              ('AI게이지', true),
              (isKorean ? '광고없음' : 'Ad-free', true),
            ], activeColor: C.lmD),
            const SizedBox(height: 6),
            _PlanBadgeRow(badges: [
              (isKorean ? '에디터도안판매' : 'Chart sell', true),
              (isKorean ? 'PDF도안판매' : 'PDF sell', true),
              (isKorean ? '단계로그 상품구성' : 'Step template', true),
            ], activeColor: C.lmD),
          ] else ...[
            _PlanBadgeRow(badges: [
              (isKorean ? '무제한' : 'Unlimited', isPro),
              ('PDF', isPro),
              ('AI게이지', isPro),
              (isKorean ? '광고없음' : 'Ad-free', isPro),
            ], activeColor: C.lv),
          ],
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showManageDialog(context, ref),
              icon: const Icon(Icons.settings_outlined, size: 16, color: Colors.white),
              label: Text(isKorean ? '구독 관리하기' : 'Manage subscription',
                  style: T.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  void _showManageDialog(BuildContext context, WidgetRef ref) {
    final sub = user.subscription;
    final isTrial = sub.status == 'trial';
    final trialEnd = sub.trialEndAt ??
        (user.createdAt?.add(const Duration(days: 90)));
    final dday = trialEnd?.difference(DateTime.now()).inDays;

    // 플랜 비교 데이터
    final planFeatures = [
      (isKorean ? '스와치 저장' : 'Swatches', isKorean ? '20개' : '20', isKorean ? '무제한' : 'Unlimited'),
      (isKorean ? '프로젝트' : 'Projects', isKorean ? '10개' : '10', isKorean ? '무제한' : 'Unlimited'),
      (isKorean ? '카운터' : 'Counters', isKorean ? '3개' : '3', isKorean ? '무제한' : 'Unlimited'),
      (isKorean ? '도안 저장' : 'Patterns', isKorean ? '5개' : '5', isKorean ? '무제한' : 'Unlimited'),
      (isKorean ? 'PDF 내보내기' : 'PDF export', '✗', '✓'),
      (isKorean ? '게이지 AI 판독' : 'AI gauge reader', '✗', '✓'),
      (isKorean ? '광고 없음' : 'Ad-free', '✗', '✓'),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isCancelled = sub.cancelAtPeriodEnd;
          return StatefulBuilder(
            builder: (ctx2, setInner) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isKorean ? '구독 관리' : 'Manage Subscription', style: T.h3),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 현재 플랜 요약
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.lvL,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.lv.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 16, color: C.lvD),
                              const SizedBox(width: 6),
                              Text(
                                isTrial ? (isKorean ? 'Pro 무료 체험 중' : 'Pro Free Trial')
                                    : (isKorean ? 'Pro 플랜' : 'Pro Plan'),
                                style: T.captionBold.copyWith(color: C.lvD),
                              ),
                              if (dday != null) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: C.og.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(dday > 0 ? 'D-$dday' : 'D-Day',
                                      style: T.captionBold.copyWith(color: C.og)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (user.createdAt != null)
                            _InfoRow(label: isKorean ? '가입일' : 'Joined', value: _fmtDate(user.createdAt!)),
                          if (trialEnd != null) ...[
                            _InfoRow(label: isKorean ? '체험 만료일' : 'Trial ends', value: _fmtDate(trialEnd)),
                            _InfoRow(label: isKorean ? '유료 전환 예정' : 'Paid from', value: _fmtDate(trialEnd)),
                          ],
                          _InfoRow(label: isKorean ? '현재 요금' : 'Fee', value: isKorean ? '무료 (베타)' : 'Free (Beta)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 플랜 비교 (드롭다운)
                    Theme(
                      data: Theme.of(ctx2).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(isKorean ? '플랜별 기능 비교' : 'Plan comparison',
                            style: T.captionBold.copyWith(color: C.mu)),
                        iconColor: C.mu,
                        collapsedIconColor: C.mu,
                        children: [
                          const SizedBox(height: 4),
                          // 헤더 행
                          Row(
                            children: [
                              Expanded(flex: 3, child: Text(isKorean ? '기능' : 'Feature',
                                  style: T.caption.copyWith(color: C.mu))),
                              Expanded(child: Center(child: Text('Free', style: T.captionBold.copyWith(color: C.mu)))),
                              Expanded(child: Center(child: Text('Pro', style: T.captionBold.copyWith(color: C.og)))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Divider(height: 1, color: C.bd),
                          const SizedBox(height: 4),
                          ...planFeatures.map((f) {
                            final (feat, free, pro) = f;
                            final isFreeCheck = free == '✓';
                            final isProCheck = pro == '✓';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text(feat, style: T.caption)),
                                  Expanded(child: Center(child: Text(free,
                                      style: T.captionBold.copyWith(
                                          color: isFreeCheck ? Colors.green : (free == '✗' ? C.mu : C.tx))))),
                                  Expanded(child: Center(child: Text(pro,
                                      style: T.captionBold.copyWith(
                                          color: isProCheck ? C.og : (pro == '✗' ? C.mu : C.og))))),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    // 해지 예약 상태 배너
                    if (isCancelled) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: C.og.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.og.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: C.og),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isKorean
                                    ? '해지가 예약되어 있어요. 체험 기간 종료 후 무료 전환됩니다.'
                                    : 'Cancellation scheduled. Downgrades to free after trial.',
                                style: T.caption.copyWith(color: C.og, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isTrial) ...[
                      const SizedBox(height: 8),
                      Text(
                        isKorean
                            ? '해지 신청 후에도 체험 기간 종료일까지 이용 가능합니다.'
                            : 'After cancellation, service continues until trial ends.',
                        style: T.caption.copyWith(color: C.mu, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                if (isCancelled)
                  TextButton(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).setCancelAtPeriodEnd(user.uid, false);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isKorean ? '해지 예약이 취소되었습니다.' : 'Cancellation revoked.'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    child: Text(isKorean ? '해지 취소하기' : 'Revoke',
                        style: TextStyle(color: C.lv, fontWeight: FontWeight.w600)),
                  )
                else
                  TextButton(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).setCancelAtPeriodEnd(user.uid, true);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isKorean
                              ? '해지 신청이 접수되었습니다. 체험 기간 종료까지 이용 가능합니다.'
                              : 'Cancellation requested. Service continues until trial ends.'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    child: Text(isKorean ? '해지·변경' : 'Cancel / Change',
                        style: TextStyle(color: C.mu)),
                  ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.lv,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isKorean ? '유지하기' : 'Keep plan',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProBookmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF6B2B); // C.og
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 8)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlanBadgeRow extends StatelessWidget {
  final List<(String, bool)> badges;
  final Color activeColor;

  const _PlanBadgeRow({required this.badges, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in badges) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: entry.$2 ? activeColor.withValues(alpha: 0.10) : const Color(0xFFF3F0FA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: activeColor.withValues(alpha: 0.20)),
              ),
              child: Text(
                '✓ ${entry.$1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: entry.$2 ? activeColor : activeColor.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}
