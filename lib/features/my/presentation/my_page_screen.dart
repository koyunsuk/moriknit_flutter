import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/subscription_constants.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/widgets/account_upgrade_dialog.dart';
import '../../../core/widgets/async_data_view.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/app_config_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counter_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../providers/memo_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/swatch_provider.dart';
import '../../../providers/fab_settings_provider.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/blueprint_provider.dart';
import '../../auth/data/handle_validator.dart';
import '../../auth/domain/user_model.dart';
import '../../dropbox/data/dropbox_auth_provider.dart';
import '../../blueprint/domain/step_blueprint.dart';
import '../../blueprint/presentation/tester_group_screen.dart';
import '../../board/presentation/app_board_detail_screen.dart';
import '../../board/presentation/app_board_list_screen.dart';
import '../../home/presentation/home_screen.dart' show MyKnitAlongMyPageBlock;
import '../../pattern/data/pattern_offline_repository.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../seller/presentation/screens/seller_sales_dashboard_screen.dart';
import '../data/my_activity_providers.dart';
import '../data/my_bug_reports_provider.dart';
import '../domain/bug_report.dart';
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
  UserModel get user => widget.user;

  @override
  void initState() {
    super.initState();
    // 익명 사용자에게 데이터 양 기반 회원가입 권유 (주 1회 제한 — 다이얼로그 내부 조건 검사)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final patternCount = user.usage.editorSaveCount;
      final counterTaps = user.usage.counterCount * 20; // 누적 추정치
      maybeShowAccountUpgradeDialog(
        context,
        ref,
        patternCount: patternCount,
        counterTotalTaps: counterTaps,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 이슈 #778 — _MyPageBodyState는 4그룹 ConsumerWidget으로 분리하여 top-level rebuild를 차단.
    // 각 그룹 위젯이 자기 provider만 watch → 카드 데이터 변경 시 해당 그룹만 rebuild.
    final t = ref.watch(appStringsProvider);
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
                      // 이슈 #830 — AdminAlertCard / SellerSummaryCard 마이페이지에서 제거.
                      //   · 어드민 정보: 어드민 전용 화면(어드민 앱/대시보드)으로 분리.
                      //   · 셀러 요약: 아래 "내 마켓" 카드에서 매출 정보 + 셀러 대시보드 진입으로 통합.
                      // ── 4그룹 ConsumerWidget (#778) ────────────────────
                      _BasicInfoSection(user: user),
                      _UsageInfoSection(user: user),
                      const _PersonalSettingsSection(),
                      _MoriKnitSection(user: user),
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
}

class _BasicInfoSection extends ConsumerStatefulWidget {
  final UserModel user;
  const _BasicInfoSection({required this.user});

  @override
  ConsumerState<_BasicInfoSection> createState() => _BasicInfoSectionState();
}

class _BasicInfoSectionState extends ConsumerState<_BasicInfoSection> {
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

  /// #771 — 핸들(@아이디) 설정/변경 다이얼로그.
  /// - 신규 설정: handleUpdatedAt 없으면 바로 가능
  /// - 변경: 마지막 변경 후 30일 경과해야 허용
  Future<void> _editHandle(BuildContext context, bool isKorean) async {
    final messenger = ScaffoldMessenger.of(context);
    // 30일 제한 검사
    final lastUpdated = user.handleUpdatedAt;
    if (user.handle.isNotEmpty && lastUpdated != null) {
      final daysSince = DateTime.now().difference(lastUpdated).inDays;
      if (daysSince < 30) {
        final remaining = 30 - daysSince;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isKorean
                  ? '핸들은 30일에 한 번만 변경할 수 있어요. ($remaining일 남음)'
                  : 'Handle can be changed once every 30 days. ($remaining days left)',
            ),
          ),
        );
        return;
      }
    }
    final controller = TextEditingController(text: user.handle);
    final validator = HandleValidator();
    _HandleEditStatus status = _HandleEditStatus.idle;
    String? statusMessage;
    Timer? debounce;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget? suffix;
          switch (status) {
            case _HandleEditStatus.idle:
              suffix = null;
              break;
            case _HandleEditStatus.checking:
              suffix = const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              );
              break;
            case _HandleEditStatus.available:
              suffix = Icon(Icons.check_circle_rounded, color: C.lmD, size: 20);
              break;
            case _HandleEditStatus.invalidFormat:
            case _HandleEditStatus.taken:
            case _HandleEditStatus.error:
              suffix = Icon(Icons.cancel_rounded, color: C.og, size: 20);
              break;
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(isKorean ? '핸들 (@아이디)' : 'Handle (@id)', style: T.h3),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  autofocus: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.84),
                    prefixText: '@',
                    suffixIcon: suffix,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: C.bd)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: C.bd)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (raw) {
                    debounce?.cancel();
                    final normalized = HandleValidator.normalize(raw);
                    if (normalized.isEmpty) {
                      setLocal(() {
                        status = _HandleEditStatus.idle;
                        statusMessage = null;
                      });
                      return;
                    }
                    if (!HandleValidator.isValidHandleFormat(normalized)) {
                      setLocal(() {
                        status = _HandleEditStatus.invalidFormat;
                        statusMessage = isKorean
                            ? '소문자/숫자/_ 3~20자만 가능해요.'
                            : 'Lowercase/digits/_ 3-20 only.';
                      });
                      return;
                    }
                    if (normalized == user.handle) {
                      setLocal(() {
                        status = _HandleEditStatus.idle;
                        statusMessage = null;
                      });
                      return;
                    }
                    setLocal(() {
                      status = _HandleEditStatus.checking;
                      statusMessage = null;
                    });
                    debounce = Timer(const Duration(milliseconds: 300), () async {
                      try {
                        final ok = await validator.isHandleAvailable(normalized);
                        setLocal(() {
                          status = ok
                              ? _HandleEditStatus.available
                              : _HandleEditStatus.taken;
                          statusMessage = ok
                              ? (isKorean ? '사용 가능해요.' : 'Available.')
                              : (isKorean ? '이미 사용 중인 핸들이에요.' : 'Already taken.');
                        });
                      } catch (_) {
                        setLocal(() {
                          status = _HandleEditStatus.error;
                          statusMessage = isKorean ? '확인 실패' : 'Check failed';
                        });
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  statusMessage ??
                      (isKorean
                          ? '소문자/숫자/_ 3~20자. 변경은 30일에 한 번 가능해요.'
                          : 'Lowercase/digits/_ 3-20. Change limited to once every 30 days.'),
                  style: T.caption.copyWith(
                    color: status == _HandleEditStatus.available
                        ? C.lmD
                        : (status == _HandleEditStatus.invalidFormat ||
                                status == _HandleEditStatus.taken ||
                                status == _HandleEditStatus.error
                            ? C.og
                            : C.mu),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isKorean ? '취소' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: status == _HandleEditStatus.available
                    ? () => Navigator.pop(ctx, HandleValidator.normalize(controller.text))
                    : null,
                child: Text(isKorean ? '저장' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
    debounce?.cancel();
    if (result == null || result.isEmpty || result == user.handle) return;
    if (!mounted) return;
    try {
      // ignore: use_build_context_synchronously
      await runWithMoriLoadingDialog<void>(
        this.context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => validator.changeHandle(
          uid: user.uid,
          oldHandle: user.handle,
          newHandle: result,
        ),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(isKorean ? '핸들이 저장됐어요.' : 'Handle saved.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이슈 #778 — 그룹1(기본정보) 전용. ref.watch는 이 그룹이 필요로 하는 provider만.
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final isAnonymous = ref.watch(isAnonymousUserProvider);
    final isBusiness = ref.watch(featureGatesProvider).isBusiness;
    final isPro = ref.watch(isProProvider);
    final name = user.displayName.isNotEmpty ? user.displayName : (user.email.isNotEmpty ? user.email.split('@').first : 'Maker');
    final photo = user.photoURL;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                      // ═══════════════════════════════════════════════════
                      // 📌 1. 기본정보 (정체성) — 프로필 / 구독 / 추가정보 / 휴대폰
                      // ═══════════════════════════════════════════════════
                      _MyPageSectionHeader(
                        title: isKorean ? '기본정보' : 'Basic Info',
                        subtitle: isKorean
                            ? '내 프로필과 구독 정보'
                            : 'Your profile and subscription',
                      ),

                      // ── 0. 게스트 프로필 히어로 (익명 사용자만 — 큰 프로필) ─────────
                      if (isAnonymous) ...[
                        _GuestProfileHero(isKorean: isKorean),
                        const SizedBox(height: 16),
                        _GuestModeBanner(isKorean: isKorean),
                        const SizedBox(height: 16),
                      ],

                      // ── 1. 기본정보 ─────────────────────────────────
                      // #770 (재재수정) — 뱃지를 MoriBlockShell trailing 슬롯으로 이동 (블록 우측 헤더, 중앙 정렬)
                      MoriBlockShell(
                            label: isKorean ? '기본정보' : 'Basic Info',
                            icon: Icons.person_rounded,
                            accent: C.lv,
                            trailing: _PlanBadgeTrailing(
                              isBusiness: isBusiness,
                              isPro: isPro,
                            ),
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
                                                    ? CachedNetworkImage(
                                                        imageUrl: photo,
                                                        width: 80,
                                                        height: 80,
                                                        fit: BoxFit.cover,
                                                        errorWidget: (_, _, _) => const MoriDefaultAvatar(size: 80, borderRadius: 999),
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
                                          height: 24,
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
                                        // 1-b단: @핸들 (#771) — 미설정 시 "핸들 설정하기" 버튼
                                        SizedBox(
                                          height: 22,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _editHandle(context, isKorean),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                if (user.handle.isNotEmpty) ...[
                                                  Text(
                                                    '@${user.handle}',
                                                    style: T.caption.copyWith(
                                                      color: C.lvD,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.edit_rounded, size: 11, color: C.lv),
                                                ] else ...[
                                                  Icon(Icons.add_circle_outline_rounded,
                                                      size: 13, color: C.lv),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isKorean ? '핸들 설정하기' : 'Set handle',
                                                    style: T.caption.copyWith(
                                                        color: C.lv, fontWeight: FontWeight.w700),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // 2단: 이메일
                                        SizedBox(
                                          height: 24,
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
                                        // #770 (재수정) — 카드 안의 플랜 칩 삭제. 뱃지는 블록 우측 헤더로 이동.
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 16),

                      // ── 1-b. 구독 정보 ─────────────────────────────
                      MoriBlockShell(
                        label: isKorean ? '구독 정보' : 'Subscription',
                        icon: Icons.workspace_premium_rounded,
                        accent: C.og,
                        child: _SubscriptionCard(user: user, isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-c. 내 프로필 추가 정보 (#750) ─────────────
                      MoriBlockShell(
                        label: isKorean ? '내 프로필 추가 정보' : 'Profile Extras',
                        icon: Icons.badge_rounded,
                        accent: C.lv,
                        child: _ProfileExtrasBlock(user: user, isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-d. 휴대폰 인증 (#750) ────────────────────
                      MoriBlockShell(
                        label: isKorean ? '휴대폰 인증' : 'Phone Verification',
                        icon: Icons.phone_android_rounded,
                        accent: C.lmD,
                        child: _PhoneVerifyBlock(user: user, isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-e. 내가 쓴 글 (#783 후속) ─────────────────
                      MoriBlockShell(
                        label: isKorean ? '내가 쓴 글' : 'My Posts',
                        icon: Icons.article_rounded,
                        accent: C.pk,
                        moreLabel: isKorean ? '전체 보기' : 'View all',
                        onMoreTap: () => context.go(Routes.community),
                        child: _MyPostsBlock(isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-e2. 내가 만든 도안 (#792 — 테스터 그룹 대시보드) ──
                      MoriBlockShell(
                        label: isKorean ? '내가 만든 도안' : 'My Authored Patterns',
                        icon: Icons.menu_book_rounded,
                        accent: C.lvD,
                        child: _MyAuthoredPatternsBlock(isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-e3. 내 함께뜨기 (#798 — 홈에서 마이페이지로 이전) ──
                      // 내가 fork 한 도안(=함께 뜨기 참여 중) 목록 + 진행률.
                      MoriBlockShell(
                        label: isKorean ? '내 함께뜨기' : 'My Knit-Alongs',
                        icon: Icons.call_split_rounded,
                        accent: C.lvD,
                        moreLabel: isKorean ? '커뮤니티' : 'Community',
                        onMoreTap: () => context.go(Routes.community),
                        child: MyKnitAlongMyPageBlock(isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-f. 내가 쓴 댓글 (#783 후속) ────────────────
                      MoriBlockShell(
                        label: isKorean ? '내가 쓴 댓글' : 'My Comments',
                        icon: Icons.mode_comment_rounded,
                        accent: C.lvD,
                        moreLabel: isKorean ? '전체 보기' : 'View all',
                        onMoreTap: () => context.go(Routes.community),
                        child: _MyCommentsBlock(isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-g. 나의 질문 (#783 후속) ───────────────────
                      MoriBlockShell(
                        label: isKorean ? '나의 질문' : 'My Questions',
                        icon: Icons.help_outline_rounded,
                        accent: C.lmD,
                        moreLabel: isKorean ? '더보기' : 'More',
                        onMoreTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AppBoardListScreen(boardType: 'qa'),
                          ),
                        ),
                        child: _MyQnaBlock(isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-h. 내 인입 이메일 (#831 Phase 3) ───────────
                      //   - 외부에서 이 주소로 도안을 보내면 라이브러리에 자동 등록.
                      //   - 핸들 미설정 시 안내만 표시, 발급 후 복사 + 재발급 가능.
                      MoriBlockShell(
                        label: isKorean ? '내 인입 이메일' : 'My Inbound Email',
                        icon: Icons.alternate_email_rounded,
                        accent: C.og,
                        child: _InboundEmailBlock(user: user, isKorean: isKorean),
                      ),
                      const SizedBox(height: 16),

                      // ── 1-i. 인입 이메일 → Dropbox 백업 폴더 (#870) ─────
                      //   - 사용자가 본인 Dropbox 의 백업 폴더 경로를 직접 지정.
                      //   - 폴더 미지정 또는 Dropbox 미연결 시 Cloud Function 은
                      //     Firebase Storage 만 저장하고 Dropbox 업로드는 건너뜀.
                      MoriBlockShell(
                        label: isKorean
                            ? '인입 이메일 → Dropbox 백업 폴더'
                            : 'Inbound Email → Dropbox Backup Folder',
                        icon: Icons.folder_special_rounded,
                        accent: C.lvD,
                        child: _InboundDropboxFolderBlock(isKorean: isKorean),
                      ),
                      const SizedBox(height: 24),
      ],
    );
  }
}

/// 이슈 #778 — 그룹2 (사용정보). 자체 ref.watch로 분리.
class _UsageInfoSection extends ConsumerWidget {
  final UserModel user;
  const _UsageInfoSection({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
              // ═══════════════════════════════════════════════════
              // 📊 2. 사용정보 (수치/통계) — 저장공간/AI/사용현황/구매/마켓
              // ═══════════════════════════════════════════════════
              _MyPageSectionHeader(
                title: isKorean ? '사용정보' : 'Usage Info',
                subtitle: isKorean
                    ? '저장공간, AI, 사용 현황 및 구매·마켓'
                    : 'Storage, AI, activity and market',
              ),

              // #783 — '오프라인 저장' 명칭 변경 (이전: 저장 공간 사용량)
              MoriBlockShell(
                label: isKorean ? '오프라인 저장' : 'Offline Storage',
                icon: Icons.cloud_download_rounded,
                accent: C.lvD,
                child: _StorageUsageBlock(
                  user: user,
                  isKorean: isKorean,
                ),
              ),
              const SizedBox(height: 16),

              // ── 2-b. AI 사용량 (#739) ──────────────────────
              MoriBlockShell(
                label: isKorean ? 'AI 사용량' : 'AI Usage',
                icon: Icons.auto_awesome_rounded,
                accent: C.pkD,
                child: _AiUsageBlock(user: user, isKorean: isKorean),
              ),
              const SizedBox(height: 16),

              // ── 2-c. 사용 현황 (스와치/프로젝트/카운터) ───────
              // 이슈 #778 — _UsageSnapshotBlock으로 추출하여 카운트 provider 3종을 자체 watch.
              _UsageSnapshotBlock(
                title: t.usageSnapshot,
                labelSwatch: t.swatchLibrary,
                labelProject: t.projectBoard,
                labelCounter: isKorean ? '카운터' : 'Counters',
                storedSwatch: user.usage.swatchCount,
                storedProject: user.usage.projectCount,
                storedCounter: user.usage.counterCount,
              ),
              const SizedBox(height: 16),
              // 이슈 #778 — _PurchaseSalesSummaryRow로 추출하여 purchases/sales를 자체 watch.
              _PurchaseSalesSummaryRow(isKorean: isKorean),
              const SizedBox(height: 16),
              // 이슈 #778 — _PurchaseMarketLedgerRow로 추출하여 purchases/marketItems를 자체 watch.
              _PurchaseMarketLedgerRow(isKorean: isKorean),
              const SizedBox(height: 24),
      ],
    );
  }
}

/// 이슈 #778 — 그룹3 (개인설정). 자체 ref.watch로 분리.
class _PersonalSettingsSection extends ConsumerWidget {
  const _PersonalSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final currentTheme = ref.watch(appThemeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
              // ═══════════════════════════════════════════════════
              // ⚙️ 3. 개인설정 (커스터마이즈) — 언어 / 테마 / 폰트 / 퀵버튼 / 스노우
              // ═══════════════════════════════════════════════════
              _MyPageSectionHeader(
                title: isKorean ? '개인설정' : 'Personal Settings',
                subtitle: isKorean
                    ? '테마, 언어, 폰트 등 개인 환경 설정'
                    : 'Theme, language, font and more',
              ),

              // ── 설정 1. 언어 (별도 블록) ─────────────────────
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
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 설정 2. 테마 (컬러 + 폰트 + 퀵버튼 + 스노우 통합 블록) ─────
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '테마 컬러' : 'Theme color', style: T.bodyBold),
                    const SizedBox(height: 8),
                    // #756 — 드롭다운으로 변경. 선택 즉시 실시간 적용.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: C.gx,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.bd),
                      ),
                      child: DropdownButton<AppThemeMode>(
                        value: currentTheme,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        menuMaxHeight: 360,
                        dropdownColor: C.bg,
                        style: T.bodyBold.copyWith(color: C.tx),
                        items: AppThemeMode.values.map((mode) {
                          final tc = AppThemeColors.of(mode);
                          final headerPreview = mode == AppThemeMode.moriMono
                              ? tc.bd
                              : mode == AppThemeMode.moriCream
                                  ? tc.bg
                                  : mode == AppThemeMode.jwiChuni
                                      ? Color.alphaBlend(tc.pk.withValues(alpha: 0.28), tc.bg)
                                      : Color.alphaBlend(tc.pk.withValues(alpha: 0.22), tc.bg);
                          return DropdownMenuItem<AppThemeMode>(
                            value: mode,
                            child: Row(
                              children: [
                                // 신호등 도트 (헤더색, 포인트색, lv색) — 컴팩트 프리뷰
                                Container(
                                  width: 12, height: 12,
                                  decoration: BoxDecoration(
                                    color: headerPreview,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: C.bd, width: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: tc.pk, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: tc.lv, shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isKorean ? mode.label : mode.labelEn,
                                    style: T.bodyBold.copyWith(color: C.tx),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(appThemeProvider.notifier).setTheme(value);
                          }
                        },
                      ),
                    ),
                    // 폰트 · 퀵버튼 · 스노우 (테마 블록 통합)
                    if (!kIsWeb) ...[
                      const SizedBox(height: 18),
                      Divider(height: 1, color: C.bd.withValues(alpha: 0.4)),
                      const SizedBox(height: 14),
                      _ThemeExtrasInline(isKorean: isKorean),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 4),
      ],
    );
  }
}

/// 이슈 #778 — 그룹4 (모리니트). 자체 ref.watch로 분리.
class _MoriKnitSection extends ConsumerWidget {
  final UserModel user;
  const _MoriKnitSection({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final isAnonymous = ref.watch(isAnonymousUserProvider);
    final social = ref.watch(socialIntegrationsProvider).valueOrNull;
    final youtubeUrl = social?.youtubeUrl ?? 'https://www.youtube.com/@moriknit';
    final instagramUrl = social?.instagramUrl ?? 'https://instagram.com/moriknit_official';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
              // ═══════════════════════════════════════════════════
              // 🏢 4. 모리니트 (회사/계정) — 회사정보 / 약관 / 버전 / QnA / 로그아웃
              // ═══════════════════════════════════════════════════
              _MyPageSectionHeader(
                title: isKorean ? '모리니트' : 'MoriKnit',
                subtitle: isKorean
                    ? '회사 정보, 약관, 도움말, 계정 관리'
                    : 'Company, terms, help and account',
              ),

              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.language_rounded, color: C.lvD),
                      title: Text(isKorean ? '공식 웹사이트' : 'Official website'),
                      subtitle: const Text('moriknit.com'),
                      onTap: () => launchUrl(Uri.parse('https://moriknit.com'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.camera_alt_outlined, color: C.pkD),
                      title: const Text('Instagram'),
                      subtitle: const Text('@moriknit_official'),
                      onTap: () => launchUrl(Uri.parse(instagramUrl), mode: LaunchMode.externalApplication),
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
                      onTap: () => launchUrl(Uri.parse('https://moriknit.com/terms'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.privacy_tip_outlined, color: C.mu),
                      title: Text(isKorean ? '개인정보처리방침' : 'Privacy policy'),
                      onTap: () => launchUrl(Uri.parse('https://moriknit.com/privacy'), mode: LaunchMode.externalApplication),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    // #783 — 앱 내 네이티브 게시판으로 이동 (launchUrl 제거)
                    ListTile(
                      leading: Icon(Icons.info_outline, color: C.mu),
                      title: Text(isKorean ? '릴리즈 노트' : 'Release notes'),
                      subtitle: const Text('1.0.0+1'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppBoardListScreen(boardType: 'release'),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.help_outline_rounded, color: C.lv),
                      title: Text(isKorean ? '자주 묻는 질문 (FAQ)' : 'FAQ'),
                      subtitle: Text(isKorean ? '궁금한 점을 확인해보세요' : 'Find answers to common questions'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppBoardListScreen(boardType: 'faq'),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(Icons.support_agent_rounded, color: C.lmD),
                      title: Text(isKorean ? '문의하기 (Q&A)' : 'Contact (Q&A)'),
                      subtitle: Text(isKorean ? '문의 사항을 남겨주세요' : 'Leave us a message'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppBoardListScreen(boardType: 'qa'),
                        ),
                      ),
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
              const SizedBox(height: 12),
              // ── 모리니트 1-b. 나의 버그/의견 제출 (#855) ──────
              _MyBugReportsBlock(isKorean: isKorean),
              const SizedBox(height: 20),
              // ── 모리니트 2. 계정 관리 (로그아웃 · 회원탈퇴) ─────
              SectionTitle(title: isKorean ? '계정 관리' : 'Account'),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(children: [
                  // 익명(게스트)은 '게스트 모드 나가기', 정식 회원은 '로그아웃'으로 노출 (#738)
                  ListTile(
                    leading: Icon(Icons.logout, color: C.og),
                    title: Text(isAnonymous
                        ? (isKorean ? '게스트 모드 나가기' : 'Exit Guest Mode')
                        : t.logout),
                    subtitle: Text(isAnonymous
                        ? (isKorean
                            ? '저장하지 않은 게스트 데이터는 사라집니다.'
                            : 'Unsaved guest data will be discarded.')
                        : t.logoutDescription),
                    onTap: () async {
                      if (isAnonymous) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text(isKorean ? '게스트 모드 나가기' : 'Exit Guest Mode', style: T.h3),
                            content: Text(
                              isKorean
                                  ? '게스트 모드를 나가면 저장하지 않은 데이터는 모두 사라집니다.\n계속할까요?'
                                  : 'Leaving guest mode will discard all unsaved data.\nContinue?',
                              style: T.body,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(isKorean ? '취소' : 'Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: C.og, foregroundColor: Colors.white),
                                child: Text(isKorean ? '나가기' : 'Exit'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                      }
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
    );
  }
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
/// #755 — 테마 블록 통합용 인라인 위젯 (테마 GlassCard 안에서 폰트/퀵버튼/스노우 표시).
/// 기존 `_FabSettingsCard` 의 본문을 GlassCard 래퍼 없이 반환.
class _ThemeExtrasInline extends ConsumerWidget {
  final bool isKorean;
  const _ThemeExtrasInline({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(fabSettingsProvider);
    final currentFont = ref.watch(fontProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // 폰트 선택
          Text(isKorean ? '폰트' : 'Font', style: T.bodyBold),
          const SizedBox(height: 4),
          Text(
            isKorean ? '앱 전체에 적용되는 글꼴을 선택하세요' : 'Choose a font applied across the app',
            style: T.caption.copyWith(color: C.tx2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in AppFont.values)
                GestureDetector(
                  onTap: () => ref.read(fontProvider.notifier).setFont(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentFont == f ? C.lv : C.lvL,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: currentFont == f ? C.lv : C.lv.withValues(alpha: 0.20),
                      ),
                    ),
                    // #756 — 각 칩에 실제 해당 폰트로 라벨 렌더링.
                    child: Text(
                      isKorean ? f.labelKo : f.labelEn,
                      style: GoogleFonts.getFont(
                        f.googleFontFamily,
                        textStyle: T.caption.copyWith(
                          color: currentFont == f ? Colors.white : C.lvD,
                          fontWeight: currentFont == f ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: C.bd.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          // 퀵버튼 숨기기 토글
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isKorean ? '퀵버튼 숨기기' : 'Hide Quick Button', style: T.bodyBold),
                    Text(isKorean ? '우측 퀵버튼을 화면에서 숨깁니다' : 'Hide the quick button from the screen',
                        style: T.caption.copyWith(color: C.tx2)),
                  ],
                ),
              ),
              Switch(
                value: settings.hideQuickButton,
                onChanged: (v) => ref.read(fabSettingsProvider.notifier).setHideQuickButton(v),
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
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // 헤더
          Row(
            children: [
              Text(isKorean ? '현재 플랜' : 'Current plan', style: T.bodyBold),
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
              onPressed: () {
                // 익명(게스트) 사용자는 Pro 결제 차단 — 회원가입 권유 다이얼로그로 유도
                if (ref.read(isAnonymousUserProvider)) {
                  showProUpgradeBlockedDialog(context, ref);
                  return;
                }
                // 이슈 #750 — Pro 업그레이드(Free → Pro)는 휴대폰 인증 필수.
                // 이미 Pro/Business 인 사용자는 관리 화면 진입 허용.
                if (!isPro && !user.phoneVerified) {
                  _showPhoneRequiredDialog(context, isKorean);
                  return;
                }
                _showManageDialog(context, ref);
              },
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
      );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  /// 이슈 #750 — Pro 업그레이드 전 휴대폰 인증 안내 다이얼로그.
  /// "지금 인증하기" 버튼은 마이페이지의 휴대폰 인증 블록을 노출하기 위해 단순히 닫기만 함.
  /// (해당 블록은 같은 화면 위쪽에 이미 표시되어 있음)
  void _showPhoneRequiredDialog(BuildContext context, bool isKorean) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isKorean ? '휴대폰 인증 필요' : 'Phone Verification Required',
          style: T.h3,
        ),
        content: Text(
          isKorean
              ? 'Pro 가입은 휴대폰 인증이 필요합니다.\n위쪽 "휴대폰 인증" 블록에서 인증해 주세요.'
              : 'Pro upgrade requires phone verification.\nPlease verify via the "Phone Verification" block above.',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isKorean ? '확인' : 'OK',
              style: TextStyle(color: C.lv, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

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

/// #770 (재재수정) — 기본정보 블록 우측 헤더 트레일링 뱃지.
/// 현재 요금제 따라 자동 변경: Business → 👑 Business / Pro → PRO 뱃지 / Free → 없음.
class _PlanBadgeTrailing extends StatelessWidget {
  final bool isBusiness;
  final bool isPro;
  const _PlanBadgeTrailing({required this.isBusiness, required this.isPro});

  @override
  Widget build(BuildContext context) {
    if (isBusiness) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: C.lmD.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.lmD.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              'Business',
              style: TextStyle(
                color: C.lmD,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }
    if (isPro) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: C.og.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.og.withValues(alpha: 0.4)),
        ),
        child: Text(
          'PRO',
          style: TextStyle(
            color: C.og,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ignore: unused_element
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

// ── 게스트 프로필 히어로 (익명 사용자 — 큰 프로필 + 모리니트 아이콘) ──
class _GuestProfileHero extends StatelessWidget {
  final bool isKorean;
  const _GuestProfileHero({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final size = (width * 0.7).clamp(180.0, 320.0);
    return Center(
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [C.lvL, C.pkL],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: C.lv.withValues(alpha: 0.25), width: 2),
            ),
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.all(size * 0.12),
                child: Image.asset(
                  'assets/login_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isKorean ? '게스트 모드' : 'Guest Mode',
            style: T.h3.copyWith(color: C.tx2),
          ),
        ],
      ),
    );
  }
}

// ── 게스트 모드 배너 (익명 사용자) ─────────────────────────────────
class _GuestModeBanner extends StatelessWidget {
  final bool isKorean;
  const _GuestModeBanner({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 20,
      borderColor: C.og.withValues(alpha: 0.22),
      color: Color.alphaBlend(
          C.og.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.92)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.og.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: C.og, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKorean ? '지금은 게스트 모드예요' : 'You are in guest mode',
                  style: T.bodyBold,
                ),
                const SizedBox(height: 2),
                Text(
                  isKorean
                      ? '계정을 만들면 기기 변경 시에도 데이터가 안전하게 보존돼요.'
                      : 'Create an account to keep your data safe across devices.',
                  style: T.caption.copyWith(color: C.tx2, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.og,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isKorean ? '계정 만들기' : 'Sign up',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
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

// ── 저장 공간 사용량 블록 (#739, #754) ─────────────────────────────
// 정확한 Firestore/Storage 사용량 측정은 서버 집계 필요 → 클라이언트 추정치 표시.
// 문서 수: 실시간 Provider 카운트 합산 (스와치/프로젝트/카운터/도안/메모) + 사용량 필드.
// 스토리지(bytes): user.usage.storageBytesUsed (변환 시 업로드 누적) + 문서 수 × 평균(3KB) 추정.
class _StorageUsageBlock extends ConsumerWidget {
  final UserModel user;
  final bool isKorean;

  const _StorageUsageBlock({
    required this.user,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 이슈 #778 — 카운트는 자체 watch (top-level rebuild 감소).
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final counterCount = ref.watch(counterCountProvider);
    // 누락 항목 보완: 도안(pattern_charts) + 메모 컬렉션 실시간 길이.
    final patternCount =
        ref.watch(patternListProvider).valueOrNull?.length ?? 0;
    final memoCount = ref.watch(memoListProvider).valueOrNull?.length ?? 0;

    // 클라이언트 측 추정 — 문서 수 합산.
    final docCount = swatchCount +
        projectCount +
        counterCount +
        patternCount +
        memoCount +
        user.usage.editorSaveCount +
        user.usage.postsThisMonth;

    // 스토리지 MB 추정 — 방식 B (문서 수 × 평균 + 누적 업로드 바이트).
    // 평균 문서 사이즈 3KB 가정. 업로드된 이미지/파일은 별도 누적 트래킹 사용.
    const avgDocBytes = 3 * 1024;
    final estDocBytes = docCount * avgDocBytes;
    final uploadedBytes = user.usage.storageBytesUsed;
    // #783 — 영구 캐시(다운로드한 도안)의 실제 바이트 합산.
    final offlineBytes =
        ref.watch(offlinePatternsTotalBytesProvider).valueOrNull ?? 0;
    final int totalBytes = (estDocBytes + uploadedBytes + offlineBytes).toInt();
    final storageLimit = SubscriptionConstants.maxFreeStorageBytes;
    final ratio = storageLimit > 0 ? totalBytes / storageLimit : 0.0;

    final storageAccent = _accentForRatio(context, ratio, base: C.lvD);
    final isOverLimit = ratio >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isKorean
              ? '클라우드에 저장된 데이터 양을 추정해 보여드려요.'
              : 'Estimated cloud data usage.',
          style: T.caption.copyWith(color: C.tx2),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _UsageMetric(
                label: isKorean ? '문서 수' : 'Documents',
                value: '$docCount',
                hint: isKorean ? '저장된 항목' : 'saved items',
                accent: C.lvD,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _UsageMetric(
                label: isKorean ? '스토리지' : 'Storage',
                value: _formatBytes(totalBytes, isKorean: isKorean),
                hint:
                    '${_formatBytes(totalBytes, isKorean: isKorean, compact: true)} / ${_formatBytes(storageLimit, isKorean: isKorean, compact: true)}',
                accent: storageAccent,
              ),
            ),
          ],
        ),
        if (isOverLimit) ...[
          const SizedBox(height: 10),
          _UsageUpgradeCta(isKorean: isKorean),
        ],
      ],
    );
  }
}

// 80% 초과 시 주황(경고), 100% 초과 시 ColorScheme.error 빨강.
Color _accentForRatio(BuildContext context, double ratio, {required Color base}) {
  if (ratio >= 1.0) return Theme.of(context).colorScheme.error;
  if (ratio >= 0.8) return C.og;
  return base;
}

// 바이트 → 사람이 읽기 좋은 단위 (KB/MB/GB).
String _formatBytes(int bytes, {required bool isKorean, bool compact = false}) {
  if (bytes < 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(compact ? 0 : 1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(compact ? 0 : 1)} MB';
  }
  final gb = bytes / (1024 * 1024 * 1024);
  return '${gb.toStringAsFixed(compact ? 1 : 2)} GB';
}

// 한도 초과 시 Pro 업그레이드 안내 미니 CTA.
// 마이페이지 상단의 구독 정보 카드에 결제 흐름이 있으므로 안내만 표시.
class _UsageUpgradeCta extends StatelessWidget {
  final bool isKorean;
  const _UsageUpgradeCta({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.og.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.og.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: C.og),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isKorean
                  ? '무료 한도를 초과했어요. 위쪽 구독 정보에서 Pro로 업그레이드해 보세요.'
                  : 'Free quota exceeded. Upgrade to Pro via the Subscription card above.',
              style: T.caption.copyWith(color: C.og, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI 사용량 블록 (#739, #754) ─────────────────────────────────
// 월별 AI 변환 횟수 — user.usage.aiConversionThisMonth + aiConversionMonthKey 기반.
// 월이 바뀌면 클라이언트에서 0으로 인식 (다음 변환 시 서버에서 리셋되며 +1).
class _AiUsageBlock extends StatelessWidget {
  final UserModel user;
  final bool isKorean;

  const _AiUsageBlock({required this.user, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final freeMonthlyLimit =
        SubscriptionConstants.maxFreeAiConversionPerMonth;

    // 월 키 비교: 현재 월과 저장된 월이 다르면 0으로 표시 (아직 이번 달 사용 없음).
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final isSameMonth = user.usage.aiConversionMonthKey == currentMonthKey;
    final usedThisMonth =
        isSameMonth ? user.usage.aiConversionThisMonth : 0;

    final ratio =
        freeMonthlyLimit > 0 ? usedThisMonth / freeMonthlyLimit : 0.0;
    final usedAccent = _accentForRatio(context, ratio, base: C.pkD);
    final isOverLimit = usedThisMonth >= freeMonthlyLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isKorean
              ? '이번 달 사용한 AI 변환 횟수입니다.'
              : 'AI conversions used this month.',
          style: T.caption.copyWith(color: C.tx2),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _UsageMetric(
                label: isKorean ? '사용' : 'Used',
                value: '$usedThisMonth',
                hint: '$usedThisMonth / $freeMonthlyLimit',
                accent: usedAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _UsageMetric(
                label: isKorean ? '무료 한도' : 'Free quota',
                value: '$freeMonthlyLimit',
                hint: isKorean ? '월간' : 'per month',
                accent: C.lv,
              ),
            ),
          ],
        ),
        if (isOverLimit) ...[
          const SizedBox(height: 10),
          _UsageUpgradeCta(isKorean: isKorean),
        ],
      ],
    );
  }
}

class _UsageMetric extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color accent;
  final bool isPlaceholder;

  const _UsageMetric({
    required this.label,
    required this.value,
    required this.hint,
    required this.accent,
    // ignore: unused_element_parameter
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.caption.copyWith(color: C.tx2)),
          const SizedBox(height: 4),
          Text(
            value,
            style: T.bodyBold.copyWith(
              color: accent,
              fontSize: isPlaceholder ? 14 : 20,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(hint, style: T.caption.copyWith(color: C.mu, fontSize: 11)),
        ],
      ),
    );
  }
}

/// 마이페이지 큰 카테고리 헤더 (기본 / 설정 / 모리니트).
/// SingleChildScrollView 안에서 단일 스크롤 구조의 카테고리 구분점 역할.
class _MyPageSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _MyPageSectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 22,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: C.lv,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: T.h2.copyWith(color: C.tx, letterSpacing: -0.3),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: T.caption.copyWith(color: C.tx2)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 이슈 #750 — 마이페이지 프로필 추가정보 (자기소개 + SNS) 블록
// ═══════════════════════════════════════════════════════════════════
class _ProfileExtrasBlock extends ConsumerStatefulWidget {
  final UserModel user;
  final bool isKorean;
  const _ProfileExtrasBlock({required this.user, required this.isKorean});

  @override
  ConsumerState<_ProfileExtrasBlock> createState() => _ProfileExtrasBlockState();
}

class _ProfileExtrasBlockState extends ConsumerState<_ProfileExtrasBlock> {
  late TextEditingController _bioCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _youtubeCtrl;
  late TextEditingController _blogCtrl;
  late TextEditingController _kakaoCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _emailCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final links = widget.user.socialLinks;
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _instagramCtrl = TextEditingController(text: links['instagram'] ?? '');
    _youtubeCtrl = TextEditingController(text: links['youtube'] ?? '');
    _blogCtrl = TextEditingController(text: links['blog'] ?? '');
    _kakaoCtrl = TextEditingController(text: links['kakaoId'] ?? '');
    _whatsappCtrl = TextEditingController(text: links['whatsapp'] ?? '');
    _emailCtrl = TextEditingController(text: links['email'] ?? '');

    for (final c in [
      _bioCtrl,
      _instagramCtrl,
      _youtubeCtrl,
      _blogCtrl,
      _kakaoCtrl,
      _whatsappCtrl,
      _emailCtrl,
    ]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _instagramCtrl.dispose();
    _youtubeCtrl.dispose();
    _blogCtrl.dispose();
    _kakaoCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// URL 정규화 — https:// 없으면 자동 prepend (빈 값은 그대로).
  String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final isKorean = widget.isKorean;

    final social = <String, String>{
      'instagram': _normalizeUrl(_instagramCtrl.text),
      'youtube': _normalizeUrl(_youtubeCtrl.text),
      'blog': _normalizeUrl(_blogCtrl.text),
      // kakaoId / whatsapp 은 URL이 아닌 ID/번호 — 패턴 검증만 (공백 제거).
      'kakaoId': _kakaoCtrl.text.trim(),
      'whatsapp': _whatsappCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
    };

    // 간단 패턴 검증: 이메일은 @ 포함, 카카오 ID는 영문/숫자/_, 왓츠앱은 숫자/+/-.
    final emailVal = social['email']!;
    if (emailVal.isNotEmpty && !emailVal.contains('@')) {
      messenger.showSnackBar(SnackBar(
        content: Text(isKorean
            ? '이메일 형식이 올바르지 않습니다.'
            : 'Email format is invalid.'),
      ));
      return;
    }
    final kakaoVal = social['kakaoId']!;
    if (kakaoVal.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_.\-]{2,40}$').hasMatch(kakaoVal)) {
      messenger.showSnackBar(SnackBar(
        content: Text(isKorean
            ? '카카오 ID는 영문/숫자/_/-/. 만 사용할 수 있습니다.'
            : 'Kakao ID may contain only letters/numbers/_/-/. .'),
      ));
      return;
    }
    final whatsappVal = social['whatsapp']!;
    if (whatsappVal.isNotEmpty &&
        !RegExp(r'^[\d\+\-\s]{6,20}$').hasMatch(whatsappVal)) {
      messenger.showSnackBar(SnackBar(
        content: Text(isKorean
            ? 'WhatsApp 번호 형식이 올바르지 않습니다.'
            : 'WhatsApp number format is invalid.'),
      ));
      return;
    }

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref.read(authRepositoryProvider).updateProfileExtras(
                uid: widget.user.uid,
                bio: _bioCtrl.text.trim(),
                socialLinks: social,
              );
        },
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      messenger.showSnackBar(SnackBar(
        content: Text(isKorean ? '저장됐어요.' : 'Saved.'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(isKorean ? '저장 실패: $e' : 'Save failed: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isKorean
              ? '자기소개와 SNS를 등록해두면 Pro 회원으로 글 작성 시 자동으로 노출돼요.'
              : 'Add a bio and your social links. Pro members can expose them on community posts.',
          style: T.caption.copyWith(color: C.tx2),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _bioCtrl,
          minLines: 2,
          maxLines: 5,
          maxLength: 200,
          style: T.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: C.gx,
            labelText: isKorean ? '자기소개' : 'Bio',
            hintText: isKorean
                ? '나를 소개해 보세요 (최대 200자)'
                : 'Tell us about yourself (max 200 chars)',
          ),
        ),
        const SizedBox(height: 8),
        _SocialField(
          controller: _instagramCtrl,
          icon: Icons.camera_alt_outlined,
          label: 'Instagram',
          hint: 'instagram.com/yourname',
        ),
        const SizedBox(height: 8),
        _SocialField(
          controller: _youtubeCtrl,
          icon: Icons.play_circle_fill_rounded,
          label: 'YouTube',
          hint: 'youtube.com/@channel',
        ),
        const SizedBox(height: 8),
        _SocialField(
          controller: _blogCtrl,
          icon: Icons.web_rounded,
          label: isKorean ? '블로그' : 'Blog',
          hint: 'blog.example.com',
        ),
        const SizedBox(height: 8),
        _SocialField(
          controller: _kakaoCtrl,
          icon: Icons.chat_bubble_rounded,
          label: isKorean ? '카카오 ID' : 'Kakao ID',
          hint: 'yourkakaoid',
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 8),
        _SocialField(
          controller: _whatsappCtrl,
          icon: Icons.message_rounded,
          label: 'WhatsApp',
          hint: '+82 10 1234 5678',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 8),
        _SocialField(
          controller: _emailCtrl,
          icon: Icons.email_outlined,
          label: isKorean ? '공개 이메일' : 'Public Email',
          hint: 'contact@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _dirty ? _save : null,
            icon: const Icon(Icons.save_rounded, size: 16),
            label: Text(
              isKorean ? '저장' : 'Save',
              style: T.captionBold.copyWith(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  const _SocialField({
    required this.controller,
    required this.icon,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: T.body,
      keyboardType: keyboardType ?? TextInputType.url,
      decoration: InputDecoration(
        filled: true,
        fillColor: C.gx,
        prefixIcon: Icon(icon, size: 18, color: C.lv),
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 이슈 #750 — 휴대폰 인증 블록 (Firebase Phone Auth)
// ═══════════════════════════════════════════════════════════════════
class _PhoneVerifyBlock extends ConsumerWidget {
  final UserModel user;
  final bool isKorean;
  const _PhoneVerifyBlock({required this.user, required this.isKorean});

  /// 인증된 번호 마스킹 — 끝 4자리만 노출 (예: 010-****-1234).
  String _maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return raw;
    final last4 = digits.substring(digits.length - 4);
    // 한국 번호 가정 (010 시작) — 그 외는 일반 마스킹.
    if (digits.startsWith('82') && digits.length >= 12) {
      // +82 10 xxxx 1234 → 010-****-1234
      return '010-****-$last4';
    }
    if (digits.startsWith('010') && digits.length >= 11) {
      return '010-****-$last4';
    }
    return '****-$last4';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = user.phoneVerified;
    final phone = user.phoneNumber ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: verified
                ? C.lmD.withValues(alpha: 0.07)
                : C.og.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: verified
                  ? C.lmD.withValues(alpha: 0.20)
                  : C.og.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
                size: 22,
                color: verified ? C.lmD : C.og,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verified
                          ? (isKorean ? '인증 완료' : 'Verified')
                          : (isKorean ? '인증되지 않음' : 'Not verified'),
                      style: T.captionBold.copyWith(
                        color: verified ? C.lmD : C.og,
                      ),
                    ),
                    if (verified && phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _maskPhone(phone),
                        style: T.caption.copyWith(color: C.tx2),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        isKorean
                            ? 'Pro 결제 전 휴대폰 인증이 필요합니다.'
                            : 'Phone verification is required before Pro upgrade.',
                        style: T.caption.copyWith(color: C.tx2, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: verified
                ? null
                : () => _showPhoneVerifyDialog(context, ref),
            icon: Icon(
              verified ? Icons.check_rounded : Icons.verified_user_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              verified
                  ? (isKorean ? '인증됨' : 'Verified')
                  : (isKorean ? '인증하기' : 'Verify'),
              style: T.captionBold.copyWith(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: verified ? C.mu : C.lmD,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  /// 휴대폰 인증 다이얼로그 — 2단계 (번호입력 → 코드입력).
  void _showPhoneVerifyDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PhoneVerifyDialog(uid: user.uid, isKorean: isKorean),
    );
  }
}

/// 2단계 휴대폰 인증 다이얼로그.
class _PhoneVerifyDialog extends ConsumerStatefulWidget {
  final String uid;
  final bool isKorean;
  const _PhoneVerifyDialog({required this.uid, required this.isKorean});

  @override
  ConsumerState<_PhoneVerifyDialog> createState() => _PhoneVerifyDialogState();
}

class _PhoneVerifyDialogState extends ConsumerState<_PhoneVerifyDialog> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  int _step = 1; // 1: 번호 입력 / 2: 코드 입력
  String? _verificationId;
  bool _sending = false;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// 한국 번호 정규화 — '01012345678' → '+821012345678'.
  String _toE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.trim().startsWith('+')) return '+$digits';
    if (digits.startsWith('010')) return '+82${digits.substring(1)}';
    if (digits.startsWith('82')) return '+$digits';
    return '+$digits';
  }

  Future<void> _sendCode() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = widget.isKorean ? '번호를 입력해 주세요.' : 'Enter a phone number.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final phone = _toE164(raw);
    try {
      await ref.read(authRepositoryProvider).sendPhoneVerificationCode(
            phoneNumber: phone,
            codeSent: (verificationId, _) {
              if (!mounted) return;
              setState(() {
                _verificationId = verificationId;
                _step = 2;
                _sending = false;
              });
            },
            verificationCompleted: (credential) async {
              // Android 자동 검증 성공 — 코드 입력 단계 스킵.
              if (!mounted) return;
              try {
                await ref.read(authRepositoryProvider).verifyPhoneCode(
                      verificationId: credential.verificationId ?? '',
                      smsCode: credential.smsCode ?? '',
                    );
                if (!mounted) return;
                Navigator.pop(context);
              } catch (_) {
                // 자동 검증 폴백 — 수동 코드 입력 단계로 진입.
              }
            },
            verificationFailed: (e) {
              if (!mounted) return;
              setState(() {
                _error = widget.isKorean
                    ? '인증 요청 실패: ${e.message ?? e.code}'
                    : 'Verification failed: ${e.message ?? e.code}';
                _sending = false;
              });
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = widget.isKorean
            ? '인증 요청 실패: $e'
            : 'Verification failed: $e';
        _sending = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6 || _verificationId == null) {
      setState(() => _error = widget.isKorean
          ? '6자리 인증 코드를 입력해 주세요.'
          : 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: widget.isKorean ? '인증 중입니다.' : 'Verifying...',
        subtitle: widget.isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () => ref.read(authRepositoryProvider).verifyPhoneCode(
              verificationId: _verificationId!,
              smsCode: code,
            ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text(widget.isKorean ? '휴대폰 인증이 완료되었습니다.' : 'Phone verified.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = widget.isKorean ? '코드 검증 실패: $e' : 'Code verification failed: $e';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isKorean ? '휴대폰 인증' : 'Phone Verification',
        style: T.h3,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == 1) ...[
              Text(
                isKorean
                    ? '휴대폰 번호를 입력하면 SMS로 6자리 인증 코드를 보냅니다.'
                    : 'Enter your phone number to receive a 6-digit SMS code.',
                style: T.caption.copyWith(color: C.tx2),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                style: T.body,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: C.gx,
                  prefixIcon: Icon(Icons.phone_android_rounded, size: 18, color: C.lv),
                  labelText: isKorean ? '휴대폰 번호' : 'Phone number',
                  hintText: '010-1234-5678',
                ),
              ),
            ] else ...[
              Text(
                isKorean
                    ? '문자로 받은 6자리 인증 코드를 입력해 주세요.'
                    : 'Enter the 6-digit code you received via SMS.',
                style: T.caption.copyWith(color: C.tx2),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                style: T.body,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: C.gx,
                  prefixIcon: Icon(Icons.sms_rounded, size: 18, color: C.lv),
                  labelText: isKorean ? '인증 코드' : 'Verification code',
                  hintText: '123456',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: T.caption.copyWith(color: C.og)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_sending || _verifying)
              ? null
              : () => Navigator.pop(context),
          child: Text(
            isKorean ? '취소' : 'Cancel',
            style: TextStyle(color: C.mu),
          ),
        ),
        if (_step == 1)
          ElevatedButton(
            onPressed: _sending ? null : _sendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _sending
                  ? (isKorean ? '전송 중...' : 'Sending...')
                  : (isKorean ? '코드 전송' : 'Send code'),
            ),
          )
        else
          ElevatedButton(
            onPressed: _verifying ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _verifying
                  ? (isKorean ? '확인 중...' : 'Verifying...')
                  : (isKorean ? '확인' : 'Verify'),
            ),
          ),
      ],
    );
  }
}

/// #771 — 마이페이지 핸들 변경 다이얼로그용 상태 enum.
enum _HandleEditStatus { idle, checking, available, invalidFormat, taken, error }

// ── #783 후속 — 마이페이지 활동 블록 ────────────────────────────────────────

/// 내가 쓴 글 (커뮤니티 posts where uid == currentUid) 미리보기 블록.
class _MyPostsBlock extends ConsumerWidget {
  final bool isKorean;
  const _MyPostsBlock({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(myPostsProvider);
    return postsAsync.when(
      loading: () => const _MyActivityLoading(),
      error: (e, _) => _MyActivityError(message: '$e'),
      data: (posts) {
        if (posts.isEmpty) {
          return _MyActivityEmpty(
            label: isKorean ? '아직 작성한 글이 없어요.' : 'No posts yet.',
          );
        }
        final preview = posts.take(3).toList();
        return Column(
          children: [
            for (final p in preview)
              InkWell(
                onTap: () => context.go(Routes.community),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.article_outlined,
                          size: 16, color: C.pk),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title.isEmpty
                                  ? (isKorean ? '(제목 없음)' : '(No title)')
                                  : p.title,
                              style: T.bodyBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.timeAgo,
                              style: T.caption.copyWith(color: C.mu),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: C.mu),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 내가 쓴 댓글 (collectionGroup posts/.../comments where uid == currentUid) 미리보기.
class _MyCommentsBlock extends ConsumerWidget {
  final bool isKorean;
  const _MyCommentsBlock({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(myCommentsProvider);
    return commentsAsync.when(
      loading: () => const _MyActivityLoading(),
      error: (e, _) => _MyActivityError(message: '$e'),
      data: (comments) {
        if (comments.isEmpty) {
          return _MyActivityEmpty(
            label: isKorean ? '아직 작성한 댓글이 없어요.' : 'No comments yet.',
          );
        }
        final preview = comments.take(3).toList();
        return Column(
          children: [
            for (final c in preview)
              InkWell(
                onTap: () => context.go(Routes.community),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.mode_comment_outlined,
                          size: 16, color: C.lvD),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.content.isEmpty
                                  ? (isKorean ? '(내용 없음)' : '(No content)')
                                  : c.content,
                              style: T.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.timeAgo,
                              style: T.caption.copyWith(color: C.mu),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: C.mu),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 나의 질문 (landing_boards/qa/posts where authorUid == currentUid) 미리보기.
class _MyQnaBlock extends ConsumerWidget {
  final bool isKorean;
  const _MyQnaBlock({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qnaAsync = ref.watch(myQnaProvider);
    return qnaAsync.when(
      loading: () => const _MyActivityLoading(),
      error: (e, _) => _MyActivityError(message: '$e'),
      data: (posts) {
        if (posts.isEmpty) {
          return _MyActivityEmpty(
            label: isKorean
                ? '아직 등록한 문의가 없어요.'
                : 'No questions yet.',
          );
        }
        final preview = posts.take(3).toList();
        return Column(
          children: [
            for (final p in preview)
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppBoardDetailScreen(
                      boardType: 'qa',
                      postId: p.id,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.help_outline_rounded,
                          size: 16, color: C.lmD),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title.isEmpty
                                  ? (isKorean ? '(제목 없음)' : '(No title)')
                                  : p.title,
                              style: T.bodyBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${p.createdAt.year}.${p.createdAt.month}.${p.createdAt.day}',
                                  style: T.caption.copyWith(color: C.mu),
                                ),
                                if (p.commentCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.chat_bubble_outline,
                                      size: 12, color: C.mu),
                                  const SizedBox(width: 3),
                                  Text('${p.commentCount}',
                                      style:
                                          T.caption.copyWith(color: C.mu)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: C.mu),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 이슈 #831 — 인입 이메일 카드.
/// - 핸들 미설정: 안내 + "핸들 설정하기" 진입 안내
/// - 키 미발급: "이메일 발급하기" 버튼 (regenerateInboundEmailKey 호출)
/// - 발급 완료: 주소 표시 + 복사 + 재발급
class _InboundEmailBlock extends ConsumerStatefulWidget {
  final UserModel user;
  final bool isKorean;
  const _InboundEmailBlock({required this.user, required this.isKorean});

  @override
  ConsumerState<_InboundEmailBlock> createState() => _InboundEmailBlockState();
}

class _InboundEmailBlockState extends ConsumerState<_InboundEmailBlock> {
  // #831 — 인입 이메일 도메인. 후이즈 MX 레코드 `in.moriknit.com` → SendGrid 라우팅.
  static const String _domain = 'in.moriknit.com';
  bool _busy = false;

  // 이슈 #872 — 별명(customKey) 변경 UI.
  bool _aliasExpanded = false;
  final TextEditingController _aliasController = TextEditingController();
  String? _aliasError; // 실시간 형식 검증 메시지
  static final RegExp _aliasPattern = RegExp(r'^[a-z0-9]{3,12}$');

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  String? _composedAddress() {
    final handle = widget.user.handle;
    final key = widget.user.inboundEmailKey;
    if (handle.isEmpty || key.isEmpty) return null;
    return '${handle}_$key@$_domain';
  }

  String? _validateAlias(String value, {required bool isKorean}) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) {
      return isKorean ? '별명을 입력해 주세요.' : 'Please enter an alias.';
    }
    if (!_aliasPattern.hasMatch(v)) {
      return isKorean
          ? '3~12자의 영문 소문자/숫자만 사용할 수 있어요.'
          : 'Use 3-12 lowercase letters or digits only.';
    }
    if (v == widget.user.inboundEmailKey.toLowerCase()) {
      return isKorean ? '현재 별명과 동일해요.' : 'Same as the current alias.';
    }
    return null;
  }

  Future<void> _generateKey({String? customKey}) async {
    final messenger = ScaffoldMessenger.of(context);
    final isKorean = widget.isKorean;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('regenerateInboundEmailKey');
          await callable.call(
            customKey != null && customKey.isNotEmpty
                ? {'customKey': customKey}
                : <String, dynamic>{},
          );
        },
      );
      if (!mounted) return;
      if (customKey != null && customKey.isNotEmpty) {
        final handle = widget.user.handle;
        final newAddr = '${handle}_$customKey@$_domain';
        showSavedSnackBar(
          messenger,
          message: isKorean
              ? '별명이 변경됐어요. 새 주소: $newAddr'
              : 'Alias changed. New address: $newAddr',
        );
        setState(() {
          _aliasExpanded = false;
          _aliasController.clear();
          _aliasError = null;
        });
      } else {
        showSavedSnackBar(messenger,
            message: isKorean ? '이메일이 발급됐어요.' : 'Email issued.');
      }
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitAlias() async {
    final isKorean = widget.isKorean;
    final value = _aliasController.text.trim().toLowerCase();
    final err = _validateAlias(value, isKorean: isKorean);
    if (err != null) {
      setState(() => _aliasError = err);
      return;
    }
    await _generateKey(customKey: value);
  }

  Future<void> _copyAddress(String addr) async {
    await Clipboard.setData(ClipboardData(text: addr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isKorean ? '주소를 복사했어요.' : 'Address copied.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    final handle = widget.user.handle;
    final address = _composedAddress();

    // 1) 핸들 미설정 — 안내만.
    if (handle.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: C.mu),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isKorean
                    ? '@핸들을 먼저 설정하면 인입 이메일이 발급돼요.'
                    : 'Set your @handle first to enable inbound email.',
                style: T.caption.copyWith(color: C.mu),
              ),
            ),
          ],
        ),
      );
    }

    // 2) 키 미발급 — 발급 버튼.
    if (address == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isKorean
                ? '나만의 도안 인입 주소를 발급하고, 다른 곳에서 받은 PDF/이미지를 이 주소로 보내 보관하세요.'
                : 'Issue your private inbound address and forward PDFs or images from anywhere.',
            style: T.caption.copyWith(color: C.tx2),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _generateKey,
              icon: const Icon(Icons.alternate_email_rounded, size: 18),
              label: Text(isKorean ? '이메일 발급하기' : 'Issue email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.og,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    // 3) 발급 완료 — 주소 표시 + 복사/재발급.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: C.gx,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.bd),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  address,
                  style: T.bodyBold.copyWith(color: C.tx),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: isKorean ? '복사' : 'Copy',
                onPressed: () => _copyAddress(address),
                icon: Icon(Icons.copy_rounded, size: 18, color: C.lvD),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isKorean
              ? '이 주소로 PDF/이미지를 보내면 라이브러리에 자동으로 들어와요. 발신자 검증 단계는 다음 업데이트로 추가됩니다.'
              : 'Send PDFs or images here and they will appear in your library. Sender approvals coming in a later update.',
          style: T.caption.copyWith(color: C.mu),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 이슈 #872 — 별명(customKey) 변경 토글.
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _aliasExpanded = !_aliasExpanded;
                        if (!_aliasExpanded) {
                          _aliasController.clear();
                          _aliasError = null;
                        }
                      });
                    },
              icon: Icon(
                _aliasExpanded
                    ? Icons.expand_less_rounded
                    : Icons.edit_rounded,
                size: 16,
                color: C.lvD,
              ),
              label: Text(
                isKorean ? '별명 변경' : 'Change alias',
                style: T.caption.copyWith(
                  color: C.lvD,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: _busy ? null : () => _generateKey(),
              icon: Icon(Icons.refresh_rounded, size: 16, color: C.og),
              label: Text(
                isKorean ? '주소 재발급' : 'Regenerate',
                style: T.caption.copyWith(
                  color: C.og,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        if (_aliasExpanded) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _aliasController,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: isKorean
                  ? '별명 (3~12자 영숫자, 외우기 쉬운 단어)'
                  : 'Alias (3-12 alphanumerics, easy to remember)',
              hintText: isKorean
                  ? '예: book, 2024, patterns'
                  : 'e.g. book, 2024, patterns',
              helperText: _aliasError ??
                  (isKorean
                      ? '영문 소문자/숫자만, 3~12자.'
                      : 'Lowercase letters or digits only, 3-12 chars.'),
              helperStyle: T.caption.copyWith(
                color: _aliasError != null ? C.og : C.mu,
              ),
              filled: true,
              fillColor: C.gx,
            ),
            onChanged: (v) {
              final err = _validateAlias(v, isKorean: isKorean);
              if (err != _aliasError) {
                setState(() => _aliasError = err);
              }
            },
            onSubmitted: (_) => _submitAlias(),
          ),
          const SizedBox(height: 8),
          Text(
            isKorean
                ? '옛 주소(현재 주소)로 들어온 메일은 이후 받지 못합니다. 노출됐을 때 변경하세요.'
                : 'Mail sent to the old (current) address will no longer be received. Change it if the address has been exposed.',
            style: T.caption.copyWith(color: C.mu),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _submitAlias,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(isKorean ? '별명 저장' : 'Save alias'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        // 이슈 #873 — 자동 AI 분석 토글 (Pro 전용).
        const SizedBox(height: 14),
        Divider(height: 1, color: C.bd.withValues(alpha: 0.5)),
        const SizedBox(height: 10),
        _AutoAiAnalysisToggleRow(isKorean: isKorean),
      ],
    );
  }
}

/// 이슈 #873 — 인입 메일 자동 AI 분석 토글 (Pro 전용).
///   - Pro 사용자: 활성, ON 시 인입 PDF/이미지가 도착 즉시 자동 AI 분석 → 라이브러리 완전 등록
///   - 무료 사용자: 비활성 + "Pro 업그레이드" 안내
///   값 저장: users/{uid}/private/dropbox.autoAiAnalysisEnabled
class _AutoAiAnalysisToggleRow extends ConsumerStatefulWidget {
  final bool isKorean;
  const _AutoAiAnalysisToggleRow({required this.isKorean});

  @override
  ConsumerState<_AutoAiAnalysisToggleRow> createState() =>
      _AutoAiAnalysisToggleRowState();
}

class _AutoAiAnalysisToggleRowState
    extends ConsumerState<_AutoAiAnalysisToggleRow> {
  bool _loaded = false;
  bool _busy = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await ref
        .read(dropboxAuthProvider.notifier)
        .readAutoAiAnalysisEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = v;
      _loaded = true;
    });
  }

  Future<void> _onChanged(bool next) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final isKorean = widget.isKorean;
    setState(() {
      _busy = true;
      _enabled = next;
    });
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref
              .read(dropboxAuthProvider.notifier)
              .writeAutoAiAnalysisEnabled(next);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger,
          message: isKorean ? '저장됐어요.' : 'Saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enabled = !next);
      showSaveErrorSnackBar(messenger, message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    final isPro = ref.watch(isProProvider);
    final fg = isPro ? C.tx : C.mu;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isKorean
                        ? '자동 AI 분석 (Pro 전용)'
                        : 'Auto AI analysis (Pro)',
                    style: T.bodyBold.copyWith(color: fg),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isKorean
                    ? '켜면 인입 메일 PDF/이미지가 도착 즉시 자동으로 AI 분석되어 도안 라이브러리에 등록됩니다.'
                    : 'When on, inbound PDFs/images are auto-analyzed by AI and added to your library.',
                style: T.caption.copyWith(color: C.mu),
              ),
              if (!isPro) ...[
                const SizedBox(height: 4),
                Text(
                  isKorean
                      ? 'Pro 플랜에서만 사용할 수 있어요.'
                      : 'Available on the Pro plan only.',
                  style: T.caption.copyWith(color: C.og),
                ),
              ],
            ],
          ),
        ),
        Switch.adaptive(
          value: isPro && _loaded && _enabled,
          onChanged: (isPro && _loaded && !_busy) ? _onChanged : null,
          activeThumbColor: C.lvD,
        ),
      ],
    );
  }
}

/// 이슈 #870 — 인입 이메일 첨부의 Dropbox 백업 폴더 입력 블록.
/// - Dropbox 미연결: 연결 안내 (안내만, 강제 차단 아님)
/// - 폴더 미지정: TextField + 저장 버튼 (예시 placeholder)
/// - 저장 시 users/{uid}/private/dropbox.uploadFolder 에 보관
/// - Cloud Function 이 이 값을 사용해 사용자 Dropbox 폴더로 추가 백업
class _InboundDropboxFolderBlock extends ConsumerStatefulWidget {
  final bool isKorean;
  const _InboundDropboxFolderBlock({required this.isKorean});

  @override
  ConsumerState<_InboundDropboxFolderBlock> createState() =>
      _InboundDropboxFolderBlockState();
}

class _InboundDropboxFolderBlockState
    extends ConsumerState<_InboundDropboxFolderBlock> {
  final TextEditingController _controller = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  // 이슈 #871 — 본인 Dropbox 폴더에 직접 추가한 도안 앱 진입 시 자동 등록 여부.
  bool _autoImport = false;
  bool _autoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final folder =
        await ref.read(dropboxAuthProvider.notifier).readUploadFolder();
    final auto =
        await ref.read(dropboxAuthProvider.notifier).readAutoImportEnabled();
    if (!mounted) return;
    setState(() {
      _controller.text = folder ?? '';
      _autoImport = auto;
      _loaded = true;
    });
  }

  Future<void> _toggleAutoImport(bool next) async {
    if (_autoBusy) return;
    setState(() {
      _autoBusy = true;
      _autoImport = next;
    });
    try {
      await ref
          .read(dropboxAuthProvider.notifier)
          .writeAutoImportEnabled(next);
    } catch (_) {
      if (mounted) setState(() => _autoImport = !next);
    } finally {
      if (mounted) setState(() => _autoBusy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final isKorean = widget.isKorean;
    setState(() => _busy = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref
              .read(dropboxAuthProvider.notifier)
              .writeUploadFolder(_controller.text);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger,
          message: isKorean ? '저장됐어요.' : 'Saved.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;
    final dropboxState = ref.watch(dropboxAuthProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 연결 상태 안내 (연결 안 됐어도 폴더 입력은 가능 — 추후 연결 시 사용).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              dropboxState.isLoggedIn
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              size: 16,
              color: dropboxState.isLoggedIn ? C.lmD : C.mu,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dropboxState.isLoggedIn
                    ? (isKorean
                        ? 'Dropbox 연결됨 — 본인 Dropbox 백업 폴더 경로를 입력해 주세요.'
                        : 'Dropbox connected — enter your backup folder path.')
                    : (isKorean
                        ? 'Dropbox 미연결 — 마이페이지 Dropbox 연결 후 적용돼요.'
                        : 'Dropbox not connected — link Dropbox to enable backup.'),
                style: T.caption.copyWith(color: C.mu),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          enabled: _loaded && !_busy,
          decoration: InputDecoration(
            labelText: isKorean ? 'Dropbox 폴더 경로' : 'Dropbox folder path',
            hintText: '/모리니트/도안/',
            helperText: isKorean
                ? '예: /모리니트/도안/ — 본인 Dropbox 에 미리 만들어둔 폴더 경로'
                : 'e.g. /MoriKnit/Patterns/ — pre-created folder in your Dropbox',
            helperMaxLines: 2,
            filled: true,
            fillColor: C.gx,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isKorean
              ? '폴더 미지정 시 Dropbox 업로드는 건너뜁니다 (모리니트 라이브러리에는 항상 저장됩니다).'
              : 'If left blank, Dropbox upload is skipped (always saved to your MoriKnit library).',
          style: T.caption.copyWith(color: C.mu),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: (_loaded && !_busy) ? _save : null,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(isKorean ? '폴더 저장' : 'Save folder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lvD,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        // 이슈 #871 — 본인 Dropbox 폴더에 직접 추가한 도안 자동 등록 토글.
        //   - ON  : 앱 진입 시 새 도안 즉시 자동 등록 + Snackbar
        //   - OFF : 앱 진입 시 다이얼로그로 등록 여부 확인
        //   폴더 미지정 또는 Dropbox 미연결 시 비활성화 (회색).
        const SizedBox(height: 14),
        Divider(height: 1, color: C.bd.withValues(alpha: 0.5)),
        const SizedBox(height: 10),
        _AutoImportToggleRow(
          isKorean: isKorean,
          enabled: _loaded &&
              !_autoBusy &&
              dropboxState.isLoggedIn &&
              _controller.text.trim().isNotEmpty,
          value: _autoImport,
          onChanged: _toggleAutoImport,
        ),
      ],
    );
  }
}

/// 이슈 #871 — Dropbox 새 도안 자동 등록 스위치 행.
/// SegmentedButton/RadioListTile/Switch 금지 규칙 적용 대상이 아닌 정식 토글(설정 항목).
/// 칩이 아니라 설정값이므로 Switch + 라벨 + 설명문 한 묶음 패턴 사용.
class _AutoImportToggleRow extends StatelessWidget {
  final bool isKorean;
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AutoImportToggleRow({
    required this.isKorean,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? C.tx : C.mu;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKorean
                    ? 'Dropbox 새 도안 자동 등록'
                    : 'Auto-import new Dropbox patterns',
                style: T.bodyBold.copyWith(color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                isKorean
                    ? '켜면 폴더에 새 도안이 추가됐을 때 앱 진입 시 즉시 라이브러리에 등록, 끄면 등록 여부를 묻습니다.'
                    : 'When on, new files in your folder are imported on app start; when off, you are asked first.',
                style: T.caption.copyWith(color: C.mu),
              ),
              if (!enabled) ...[
                const SizedBox(height: 4),
                Text(
                  isKorean
                      ? 'Dropbox 연결 + 폴더 지정 후 사용할 수 있어요.'
                      : 'Available after linking Dropbox and setting a folder.',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ],
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: C.lvD,
        ),
      ],
    );
  }
}

/// 활동 블록 공용 — 로딩 상태 플레이스홀더.
class _MyActivityLoading extends StatelessWidget {
  const _MyActivityLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 44,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.bd.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}

/// 활동 블록 공용 — 빈 상태 안내 + 빈 행 플레이스홀더.
class _MyActivityEmpty extends StatelessWidget {
  final String label;
  const _MyActivityEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.bd.withValues(alpha: 0.5)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: T.caption.copyWith(color: C.mu),
          ),
        ),
      ],
    );
  }
}

/// 활동 블록 공용 — 에러 상태.
class _MyActivityError extends StatelessWidget {
  final String message;
  const _MyActivityError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: T.caption.copyWith(color: C.og),
      ),
    );
  }
}

// 이슈 #778 — 사용 현황 블록 (스와치/프로젝트/카운터 3종 카운트 자체 watch).
class _UsageSnapshotBlock extends ConsumerWidget {
  final String title;
  final String labelSwatch;
  final String labelProject;
  final String labelCounter;
  final int storedSwatch;
  final int storedProject;
  final int storedCounter;
  const _UsageSnapshotBlock({
    required this.title,
    required this.labelSwatch,
    required this.labelProject,
    required this.labelCounter,
    required this.storedSwatch,
    required this.storedProject,
    required this.storedCounter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swatchCount = ref.watch(swatchCountProvider);
    final projectCount = ref.watch(projectCountProvider);
    final counterCount = ref.watch(counterCountProvider);
    return MoriBlockShell(
      label: title,
      icon: Icons.bar_chart_rounded,
      accent: C.lv,
      child: Row(
        children: [
          Expanded(child: _snapshotItem(context, labelSwatch, swatchCount, storedSwatch, C.lv, () => context.push('/swatch'))),
          Container(width: 1, height: 72, color: C.bd),
          Expanded(child: _snapshotItem(context, labelProject, projectCount, storedProject, C.pk, () => context.push('/project'))),
          Container(width: 1, height: 72, color: C.bd),
          Expanded(child: _snapshotItem(context, labelCounter, counterCount, storedCounter, C.lmD, () => context.push('/counters'))),
        ],
      ),
    );
  }

  Widget _snapshotItem(BuildContext context, String label, int count, int stored, Color color, VoidCallback onTap) {
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
}

// 이슈 #778 — 구매/마켓 요약 카드 Row (purchases/sales 자체 watch).
class _PurchaseSalesSummaryRow extends ConsumerWidget {
  final bool isKorean;
  const _PurchaseSalesSummaryRow({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(myPurchasesProvider);
    final salesAsync = ref.watch(myMarketSalesProvider);
    return Row(
      children: [
        Expanded(
          child: purchasesAsync.when(
            data: (items) => _SummaryCard(
              title: isKorean ? '구매 요약' : 'Purchase summary',
              countLabel: isKorean ? '구매 수' : 'Orders',
              countValue: '${items.length}',
              amountLabel: isKorean ? '구매 합계' : 'Spent',
              amountValue: _formatWonExt(items.fold<int>(0, (sum, item) => sum + item.price), isKorean),
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
              amountValue: _formatWonExt(items.fold<int>(0, (sum, item) => sum + item.price), isKorean),
              accent: C.lmD,
            ),
            loading: () => _LoadingSummaryCard(color: C.lmD),
            error: (e, _) => _ErrorCard(message: '$e'),
          ),
        ),
      ],
    );
  }
}

// 이슈 #778 — 내 구매/마켓 ledger Row (purchases/marketItems 자체 watch).
class _PurchaseMarketLedgerRow extends ConsumerWidget {
  final bool isKorean;
  const _PurchaseMarketLedgerRow({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(myPurchasesProvider);
    final marketItemsAsync = ref.watch(myMarketItemsProvider);
    // 이슈 #830 — '내 마켓' 카드에 셀러 실매출(market_sales) 연결.
    final salesAsync = ref.watch(myMarketSalesProvider);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MoriBlockShell(
              label: isKorean ? '내 구매' : 'My purchases',
              icon: Icons.receipt_long_rounded,
              accent: C.pkD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isKorean ? '최근 구입한 상품을 확인해요.' : 'See your latest purchases.', style: T.caption.copyWith(color: C.tx2)),
                  const SizedBox(height: 12),
                  purchasesAsync.when(
                    data: (items) => items.isEmpty
                        ? Column(children: List.generate(3, (_) => Container(height: 50, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bd.withValues(alpha: 0.5))))))
                        : Column(children: items.take(4).map((item) => _LedgerRow(title: item.title, subtitle: _formatWonExt(item.price, isKorean), accent: C.pkD)).toList()),
                    loading: () => CircularProgressIndicator(color: C.lv),
                    error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            // 이슈 #830 — '내 마켓' 카드 탭 → SellerSalesDashboardScreen 으로 이동.
            //   rootNavigator 사용해서 MainShell 바깥 풀스크린으로 push.
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SellerSalesDashboardScreen(),
                  ),
                );
              },
              child: MoriBlockShell(
                label: isKorean ? '내 마켓' : 'My market',
                icon: Icons.storefront_rounded,
                accent: C.lmD,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isKorean ? '등록한 상품과 매출을 확인해요.' : 'See your listings and sales.',
                            style: T.caption.copyWith(color: C.tx2),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: C.mu, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 이슈 #830 — 매출 요약(누적 판매 건수/매출액) — myMarketSalesProvider 연결.
                    salesAsync.when(
                      data: (sales) {
                        final totalSales = sales.fold<int>(0, (a, b) => a + b.price);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: C.lm.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: C.lmD.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.payments_rounded,
                                  size: 14, color: C.lmD),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isKorean
                                      ? '누적 판매 ${sales.length}건 · ${_formatWonExt(totalSales, isKorean)}'
                                      : '${sales.length} sales · ${_formatWonExt(totalSales, isKorean)}',
                                  style: T.caption.copyWith(
                                      color: C.lmD,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: C.bd.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 10),
                    marketItemsAsync.when(
                      data: (items) => items.isEmpty
                          ? Column(children: List.generate(3, (_) => Container(height: 50, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bd.withValues(alpha: 0.5))))))
                          : Column(
                              children: items.take(4).map((item) => _LedgerRow(title: item.title, subtitle: _formatWonExt(item.price, isKorean), accent: C.lmD)).toList(),
                            ),
                      loading: () => CircularProgressIndicator(color: C.lv),
                      error: (e, _) => Text('$e', style: T.caption.copyWith(color: C.og)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 이슈 #778 — 추출된 위젯에서 사용하는 통화 포맷 함수 (기존 _formatWon과 동일).
String _formatWonExt(int amount, bool isKorean) => isKorean ? '$amount원' : '$amount KRW';

/// #792 — 마이페이지 "내가 만든 도안" 블록.
/// 내가 작성한 도안마다 테스터 수 + 평균 진행률(추정) + 진입점 표시.
class _MyAuthoredPatternsBlock extends ConsumerWidget {
  final bool isKorean;
  const _MyAuthoredPatternsBlock({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authoredAsync = ref.watch(myAuthoredBlueprintsProvider);
    return authoredAsync.when(
      loading: () => _MyAuthoredPlaceholder(isKorean: isKorean),
      error: (_, _) => _MyAuthoredPlaceholder(isKorean: isKorean),
      data: (list) {
        if (list.isEmpty) return _MyAuthoredPlaceholder(isKorean: isKorean);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < list.length && i < 5; i++) ...[
              _MyAuthoredRow(blueprint: list[i], isKorean: isKorean),
              if (i < list.length - 1 && i < 4)
                const Divider(height: 12, thickness: 0.5),
            ],
            if (list.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isKorean
                      ? '외 ${list.length - 5}건의 도안'
                      : 'and ${list.length - 5} more',
                  style: T.caption.copyWith(color: C.mu),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MyAuthoredRow extends StatelessWidget {
  final StepBlueprint blueprint;
  final bool isKorean;

  const _MyAuthoredRow({required this.blueprint, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final testerCount = blueprint.members.length;
    final forkCount = blueprint.forkCount;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TesterGroupScreen(blueprintId: blueprint.id),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: C.lvL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.menu_book_rounded, color: C.lvD, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blueprint.localizedTitle(isKorean),
                    style: T.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_rounded, size: 12, color: C.lmD),
                      const SizedBox(width: 3),
                      Text(
                        isKorean ? '테스터 $testerCount명' : '$testerCount testers',
                        style: T.caption.copyWith(color: C.lmD),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.call_split_rounded, size: 12, color: C.lvD),
                      const SizedBox(width: 3),
                      Text(
                        isKorean ? '함께뜨기 $forkCount' : '$forkCount fork',
                        style: T.caption.copyWith(color: C.lvD),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.mu, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MyAuthoredPlaceholder extends StatelessWidget {
  final bool isKorean;
  const _MyAuthoredPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: C.bd.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 110,
                        decoration: BoxDecoration(
                          color: C.bd,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 7,
                        width: 70,
                        decoration: BoxDecoration(
                          color: C.bd.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          isKorean
              ? '도안에디터에서 첫 도안을 만들고\n테스터를 초대해 보세요.'
              : 'Create your first pattern and\ninvite testers from the editor.',
          textAlign: TextAlign.center,
          style: T.caption.copyWith(color: C.mu, height: 1.4),
        ),
      ],
    );
  }
}

/// 이슈 #855 — 나의 버그/의견 제출 이력 블록.
/// - `bug_reports.where(uid).orderBy(createdAt desc).limit(20)` 스트림 노출
/// - 항목: 제목, 카테고리, 상태(GitHub 연결됨/대기), 제출 시각
/// - GitHub 이슈 URL 있는 항목은 외부 브라우저로 열기
/// - 비어있을 땐 EmptyBlockPlaceholder (#722 표준)
class _MyBugReportsBlock extends ConsumerWidget {
  final bool isKorean;
  const _MyBugReportsBlock({required this.isKorean});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(myBugReportsProvider);
    return MoriBlockShell(
      label: isKorean ? '나의 버그/의견 제출' : 'My Reports',
      icon: Icons.assignment_outlined,
      accent: C.og,
      child: AsyncDataView<List<BugReport>>(
        async: reportsAsync,
        isEmpty: (data) => data.isEmpty,
        placeholderRows: 2,
        rowHeight: 56,
        emptyBuilder: () => EmptyBlockPlaceholder(
          message: isKorean
              ? '아직 제출한 버그/의견이 없어요.'
              : 'No reports submitted yet.',
          rows: 2,
          rowHeight: 56,
        ),
        builder: (reports) {
          final preview = reports.take(5).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                _MyBugReportRow(report: preview[i], isKorean: isKorean),
                if (i < preview.length - 1)
                  Divider(height: 1, color: C.bd.withValues(alpha: 0.4)),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 단일 버그리포트 행. GitHub 이슈 연결 시 외부 브라우저로 진입.
class _MyBugReportRow extends StatelessWidget {
  final BugReport report;
  final bool isKorean;
  const _MyBugReportRow({required this.report, required this.isKorean});

  String get _categoryLabel {
    switch (report.category) {
      case 'ui':
        return isKorean ? 'UI 버그' : 'UI Bug';
      case 'crash':
        return isKorean ? '크래시' : 'Crash';
      case 'feature':
        return isKorean ? '기능 요청' : 'Feature';
      case 'other':
        return isKorean ? '기타' : 'Other';
      default:
        return report.category;
    }
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(report.createdAt);
    if (diff.inMinutes < 1) return isKorean ? '방금 전' : 'just now';
    if (diff.inHours < 1) {
      return isKorean ? '${diff.inMinutes}분 전' : '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return isKorean ? '${diff.inHours}시간 전' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return isKorean ? '${diff.inDays}일 전' : '${diff.inDays}d ago';
    }
    return '${report.createdAt.month}/${report.createdAt.day}';
  }

  Future<void> _open(BuildContext context) async {
    final url = report.githubIssueUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final url = report.githubIssueUrl;
    final hasIssue = url != null && url.isNotEmpty;
    final issueNumber = report.githubIssueNumber;
    final statusLabel = hasIssue
        ? (issueNumber != null
            ? (isKorean ? '이슈 #$issueNumber' : 'Issue #$issueNumber')
            : (isKorean ? '연결됨' : 'Linked'))
        : (isKorean ? '대기 중' : 'Pending');
    final statusColor = hasIssue ? C.lvD : C.mu;
    final statusBg = hasIssue
        ? C.lv.withValues(alpha: 0.14)
        : C.bd.withValues(alpha: 0.30);

    return InkWell(
      onTap: hasIssue ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasIssue ? Icons.bug_report_rounded : Icons.bug_report_outlined,
              size: 16,
              color: hasIssue ? C.og : C.mu,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title.isEmpty
                        ? (isKorean ? '(제목 없음)' : '(No title)')
                        : report.title,
                    style: T.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: C.bd.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _categoryLabel,
                          style: T.caption.copyWith(color: C.tx2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: T.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _timeAgo,
                          style: T.caption.copyWith(color: C.mu),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasIssue) ...[
              const SizedBox(width: 4),
              Icon(Icons.open_in_new_rounded, size: 16, color: C.mu),
            ],
          ],
        ),
      ),
    );
  }
}
