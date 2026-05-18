// lib/features/market/presentation/pattern_publish_screen.dart
//
// 이슈 #629 — 도안 마켓 등록 화면 (0원 무료 도안 우선 지원).
//
// 도안 상세에서 진입. 도안 메타(제목/이미지/PDF/설명)를 자동 채우고
// 가격(0원=무료)·라이선스·카테고리·태그를 입력해 MarketItem 으로 발행한다.
//
// - status: 'approved' (도안 마켓은 즉시 게시. 어드민 승인 흐름은 후속)
// - price 0 → 무료 라벨. 마켓 화면의 '🎁 무료' 정렬과 카드 라벨 자동 매칭.
// - draft 상태 도안은 경고 배너 표시 (등록 자체는 허용 — 사용자 의사 존중).
//
// 표준 패턴:
//   AppBar(arrow_back_ios) + body Stack[BgOrbs, SingleChildScrollView] + bottomNavigationBar 저장 버튼
//   runWithMoriLoadingDialog / showSavedSnackBar / showSaveErrorSnackBar
//   C / T 토큰만 사용. 인라인 색상/타이포 금지.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_provider.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../../pattern/presentation/pattern_detail_screen.dart'
    show marketLicenseHelpUrl, openLicenseHelp;
import '../domain/market_item.dart';

/// 도안 → 마켓 등록 화면.
///
/// [chart] : 등록 대상 도안. 제목·설명·이미지·PDF URL 자동 채움.
class PatternPublishScreen extends ConsumerStatefulWidget {
  final PatternChart chart;
  const PatternPublishScreen({super.key, required this.chart});

  @override
  ConsumerState<PatternPublishScreen> createState() =>
      _PatternPublishScreenState();
}

class _PatternPublishScreenState extends ConsumerState<PatternPublishScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  final TextEditingController _tagsCtrl = TextEditingController();
  final List<String> _tags = [];

  /// 0 = 무료, 1+ = 유료 (Mori 단위).
  bool _isFree = true;

  /// 라이선스 (3종 단순화).
  ///   - personal_use : 개인 사용만
  ///   - commercial   : 상업적 사용 허용
  ///   - fork_only    : Fork만 허용 (재배포 금지)
  String _license = 'personal_use';

  /// 공개 범위.
  ///   - public  : 누구나
  ///   - friends_only : 친구 (후속 — 현재 UI는 노출, 동작은 public 과 동일)
  String _visibility = 'public';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.chart.title);
    _descCtrl =
        TextEditingController(text: widget.chart.narrativeText);
    _priceCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ── 액션 ──────────────────────────────────────────────────────────────────

  Future<void> _publish() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '로그인이 필요해요.' : 'Login required.');
      return;
    }

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '제목을 입력해 주세요.' : 'Title is required.');
      return;
    }

    final priceText = _priceCtrl.text.trim();
    final price = _isFree ? 0 : (int.tryParse(priceText) ?? 0);
    if (!_isFree && price <= 0) {
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: isKorean ? '가격을 0 이상으로 입력해 주세요.' : 'Enter a valid price.');
      return;
    }

    // 이슈 #939 — 마켓 publish 시점 라이선스 필수 검증 (등록 흐름의 라이선스는 제거되었으므로
    // 이 시점에 명시적으로 한 번 더 확인). UI 라디오 기본값 'personal_use'.
    if (_license.trim().isEmpty) {
      showSaveErrorSnackBar(ScaffoldMessenger.of(context),
          message: isKorean
              ? '라이선스를 선택해 주세요.'
              : 'Please select a license.');
      return;
    }

    final accentPalette = [
      '#FA5BB4',
      '#B47EEB',
      '#A3E635',
      '#F472B6',
      '#60A5FA',
      '#34D399',
      '#FB923C',
      '#F9A8D4',
    ];
    final accent = accentPalette[Random().nextInt(accentPalette.length)];

    final sellerName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? '');

    final item = MarketItem(
      id: '',
      sellerUid: user.uid,
      sellerName: sellerName,
      title: title,
      description: _descCtrl.text.trim(),
      price: price,
      category: 'pattern',
      accentHex: accent,
      imageType: 'pattern',
      isSoldOut: false,
      isOfficial: false,
      imageUrl: widget.chart.imageUrl,
      pdfUrl: widget.chart.pdfUrl,
      status: 'approved',
      tags: List<String>.from(_tags),
    );

    setState(() => _saving = true);
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref.read(marketRepositoryProvider).createItem(
                item,
                extraData: {
                  // #629 — 라이선스/공개범위 메타 (Firestore 에 직접 저장).
                  'license': _license,
                  'visibility': _visibility,
                  'sourcePatternId': widget.chart.id,
                },
              );
        },
      );
      if (!mounted) return;
      showSavedSnackBar(ScaffoldMessenger.of(context),
          message: _isFree
              ? (isKorean ? '무료 도안으로 등록됐어요.' : 'Published as free pattern.')
              : (isKorean ? '마켓에 등록됐어요.' : 'Published to market.'));
      // 등록 후 마켓 화면으로 이동 (이번 등록 결과를 바로 볼 수 있도록).
      Future.microtask(() {
        if (mounted) context.go(Routes.market);
      });
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;
    final isDraft = !widget.chart.isComplete;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.market),
        ),
        title: Text(
          isKorean ? '마켓에 등록' : 'Publish to Market',
          style: T.h3,
        ),
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDraft) ...[
                  _DraftBanner(isKorean: isKorean),
                  const SizedBox(height: 16),
                ],
                SectionTitle(title: isKorean ? '제목' : 'Title'),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: isKorean ? '제목' : 'Title',
                    hintText: widget.chart.title,
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '설명' : 'Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: isKorean ? '설명' : 'Description',
                    hintText: isKorean
                        ? '도안에 대한 간단한 소개를 적어 주세요.'
                        : 'Briefly describe this pattern.',
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '가격' : 'Price'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PriceChip(
                      label: isKorean ? '무료' : 'Free',
                      selected: _isFree,
                      onTap: _saving
                          ? null
                          : () => setState(() {
                                _isFree = true;
                                _priceCtrl.text = '0';
                              }),
                    ),
                    const SizedBox(width: 8),
                    _PriceChip(
                      label: isKorean ? '유료' : 'Paid',
                      selected: !_isFree,
                      onTap: _saving
                          ? null
                          : () => setState(() {
                                _isFree = false;
                                if (_priceCtrl.text == '0') {
                                  _priceCtrl.text = '';
                                }
                              }),
                    ),
                  ],
                ),
                if (!_isFree) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isKorean ? '가격 (모리)' : 'Price (Mori)',
                      hintText: '0',
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    isKorean
                        ? '0원으로 등록하면 누구나 자유롭게 받아갈 수 있어요.'
                        : 'Free patterns can be claimed by anyone at no cost.',
                    style: T.caption.copyWith(color: C.mu),
                  ),
                ],
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '라이선스' : 'License'),
                const SizedBox(height: 8),
                _LicenseSelector(
                  value: _license,
                  isKorean: isKorean,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _license = v),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '공개 범위' : 'Visibility'),
                const SizedBox(height: 8),
                _VisibilitySelector(
                  value: _visibility,
                  isKorean: isKorean,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _visibility = v),
                ),
                const SizedBox(height: 20),
                SectionTitle(title: isKorean ? '태그 (선택)' : 'Tags (optional)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagsCtrl,
                        decoration: InputDecoration(
                          labelText:
                              isKorean ? '태그 (쉼표로 구분)' : 'Tags (comma)',
                          hintText: isKorean
                              ? '예: 코바늘, 초보, 인형'
                              : 'e.g. crochet, beginner',
                        ),
                        onSubmitted: (_) => _addTags(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_rounded, color: C.lv),
                      onPressed: _saving ? null : _addTags,
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags
                        .map((t) => _RemovableTagChip(
                              label: t,
                              onRemove: _saving
                                  ? null
                                  : () => setState(() => _tags.remove(t)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: C.lv,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isFree
                    ? (isKorean ? '무료로 등록하기' : 'Publish for Free')
                    : (isKorean ? '마켓에 등록' : 'Publish to Market'),
                style: T.bodyBold.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addTags() {
    final newTags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (newTags.isEmpty) return;
    setState(() {
      final merged = {..._tags, ...newTags}.take(10).toList();
      _tags
        ..clear()
        ..addAll(merged);
      _tagsCtrl.clear();
    });
  }
}

// ── 보조 위젯 ──────────────────────────────────────────────────────────────

class _DraftBanner extends StatelessWidget {
  final bool isKorean;
  const _DraftBanner({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: C.og.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.og.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: C.og, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isKorean
                  ? '아직 섹션이 없는 초안 상태예요. 받는 사람이 단계로그·Fork 흐름을 이용하려면 섹션을 완성한 후 등록을 권장해요.'
                  : 'This pattern is a draft. For full project-step and fork features, complete the sections first.',
              style: T.caption.copyWith(color: C.og, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _PriceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? C.lv : C.lv.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : C.lvD,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LicenseSelector extends StatelessWidget {
  final String value;
  final bool isKorean;
  final ValueChanged<String>? onChanged;
  const _LicenseSelector({
    required this.value,
    required this.isKorean,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <(String, String, String)>[
      (
        'personal_use',
        isKorean ? '개인 사용' : 'Personal use',
        isKorean ? '받는 사람의 개인 작업에만 사용' : 'For personal use only',
      ),
      (
        'fork_only',
        isKorean ? 'Fork만 허용' : 'Fork only',
        isKorean ? '내 라이브러리에 사본을 만들 수 있음' : 'Forking allowed, no redistribution',
      ),
      (
        'commercial',
        isKorean ? '상업적 사용 허용' : 'Commercial use',
        isKorean ? '판매 작품에도 사용 가능' : 'Allowed in items for sale',
      ),
    ];

    return Column(
      children: options.map((o) {
        final selected = value == o.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onChanged == null ? null : () => onChanged!(o.$1),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: selected ? C.lvL : C.gx,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? C.lv
                      : C.lv.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? C.lv : C.mu,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                o.$2,
                                style: T.bodyBold.copyWith(
                                  color: selected ? C.lvD : C.tx,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // 이슈 #939 — 라이선스 옆 ? 도움말. FAQ 외부 링크.
                            Builder(
                              builder: (ctx) => InkResponse(
                                onTap: () => openLicenseHelp(
                                  ctx,
                                  marketLicenseHelpUrl(o.$1),
                                ),
                                radius: 18,
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.help_outline_rounded,
                                    size: 16,
                                    color: C.mu,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(o.$3,
                            style: T.caption.copyWith(color: C.mu)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  final String value;
  final bool isKorean;
  final ValueChanged<String>? onChanged;
  const _VisibilitySelector({
    required this.value,
    required this.isKorean,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <(String, String)>[
      ('public', isKorean ? '전체 공개' : 'Public'),
      ('friends_only', isKorean ? '친구에게만' : 'Friends only'),
    ];
    return Row(
      children: options
          .map((o) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _PriceChip(
                  label: o.$2,
                  selected: value == o.$1,
                  onTap: onChanged == null ? null : () => onChanged!(o.$1),
                ),
              ))
          .toList(),
    );
  }
}

class _RemovableTagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;
  const _RemovableTagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: C.lvL,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.lv.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#$label', style: T.caption.copyWith(color: C.lvD)),
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 13, color: C.mu),
          ],
        ),
      ),
    );
  }
}
