import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/bug_report_provider.dart';
import '../../auth/domain/user_model.dart';
import '../data/bug_metadata_collector.dart';
import '../data/bug_report_repository.dart';
import '../domain/bug_report.dart';

Future<void> showBugReportSheet(
  BuildContext context,
  WidgetRef ref,
  UserModel user,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BugReportSheet(user: user),
  );
}

class _BugReportSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const _BugReportSheet({required this.user});

  @override
  ConsumerState<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends ConsumerState<_BugReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();

  String _category = 'ui';
  bool _wantsReply = false;

  // 이미지: (XFile, bytes) 쌍으로 관리
  final List<(XFile, Uint8List)> _images = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    final remaining = 5 - _images.length;
    final toAdd = picked.take(remaining);
    final pairs = await Future.wait(
      toAdd.map((f) async => (f, await f.readAsBytes())),
    );
    setState(() => _images.addAll(pairs));
  }

  Future<void> _submit() async {
    debugPrint('🔍 #822 _submit() entered');
    if (!_formKey.currentState!.validate()) {
      debugPrint('🔍 #822 validate fail → return');
      return;
    }
    debugPrint('🔍 #822 validate OK');
    final isKorean = ref.read(appLanguageProvider).isKorean;

    // #822 (재수정) — sheet 안에서 platform channel(DeviceInfo/PackageInfo) await 시 cold start
    //   1-3초 메인스레드 점유 → ANR (Input dispatching timed out). 분리:
    //   - sync 정보만 sheet 닫기 전 즉시 캡처 (MediaQuery/Route/Locale — platform channel X)
    //   - async platform channel 호출은 sheet 닫은 후 백그라운드에서

    // 1) 입력값 캡처 (sheet dispose 후에도 안전)
    final user = widget.user;
    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final category = _category;
    final steps = _stepsCtrl.text.trim();
    final wantsReply = _wantsReply;
    final imageBytes = _images.map((e) => e.$2).toList();

    // 2) (재진단) — collectBugMetadataSync 호출이 ANR 원인. 완전 제거.
    //    sync인데도 _getCurrentRoute(GoRouter.routerDelegate.currentConfiguration)
    //    또는 ref.read(networkStatusServiceProvider) 가 메인스레드 점유.
    //    메타데이터는 모두 빈 값으로 진행 — 이슈 등록은 차단 안 함.
    debugPrint('🔍 #822 sync 메타 수집 SKIP (ANR 원인 확정)');

    // 3) main scaffold messenger 캡처
    final messenger = ScaffoldMessenger.of(context);

    // 3-1) ref 의존 인스턴스 미리 캡처 (sheet dispose 후 ref 사용 불가).
    //   #822 후속 — "Bad state: Cannot use ref after the widget was disposed" 방지.
    final repo = ref.read(bugReportRepositoryProvider);
    final notifier = ref.read(bugReportProvider.notifier);

    // 4) sheet 즉시 닫음 → 메인스레드 부담 해제 (이제 사용자 인터랙션 가능)
    debugPrint('🔍 #822 Navigator.pop 시작');
    Navigator.of(context).pop();
    debugPrint('🔍 #822 Navigator.pop 완료');

    // 빈 syncMeta
    const syncMeta = (
      screenSize: '',
      viewportInsets: '',
      currentRoute: '',
      currentScreenName: '',
      localeName: '',
      isOnline: '',
    );

    // 5) 백그라운드 submit (platform channel + 이미지 업로드 + Firestore 모두 백그라운드)
    _submitInBackground(
      messenger: messenger,
      repo: repo,
      notifier: notifier,
      isKorean: isKorean,
      user: user,
      title: title,
      description: description,
      category: category,
      steps: steps,
      wantsReply: wantsReply,
      imageBytes: imageBytes,
      syncMeta: syncMeta,
    );
  }

  /// 시트 닫힌 후 백그라운드에서 진행. ref/widget context 의존 없이 동작.
  /// platform channel (DeviceInfo/PackageInfo) 호출도 백그라운드에서 (ANR 방지).
  /// repo/notifier는 sheet 닫기 전 미리 캡처해서 전달 (ref 사용 불가 회피).
  Future<void> _submitInBackground({
    required ScaffoldMessengerState messenger,
    required BugReportRepository repo,
    required BugReportNotifier notifier,
    required bool isKorean,
    required UserModel user,
    required String title,
    required String description,
    required String category,
    required String steps,
    required bool wantsReply,
    required List<Uint8List> imageBytes,
    required ({String screenSize, String viewportInsets, String currentRoute, String currentScreenName, String localeName, String isOnline}) syncMeta,
  }) async {
    // 진행 SnackBar (배경에서 작업 중임을 알림)
    messenger.showSnackBar(SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isKorean ? '버그리포트 전송 중...' : 'Submitting bug report...',
            style: T.body.copyWith(color: Colors.white),
          ),
        ],
      ),
      duration: const Duration(seconds: 30),
      backgroundColor: C.lvD,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

    try {
      // 1) 백그라운드에서 platform channel 호출 (DeviceInfo / PackageInfo).
      //    sheet 닫힌 상태이므로 메인스레드 부담 무관 → ANR 안전.
      String deviceInfo = '';
      String osVersion = '';
      String platform = '';
      String appVersion = '';
      try {
        final asyncMeta = await collectBugMetadataAsync();
        deviceInfo = asyncMeta.deviceInfo;
        osVersion = asyncMeta.osVersion;
        platform = asyncMeta.platform;
        appVersion = asyncMeta.appVersion;
      } catch (_) {}

      // 2) 이미지 업로드 (캡처된 repo 사용 — ref.read 호출 X)
      final imageUrls = imageBytes.isNotEmpty
          ? await repo.uploadImages(user.uid, imageBytes)
          : <String>[];

      // 3) BugReport 구성 — sync 정보(sheet 시점 캡처) + async 정보(백그라운드 수집)
      final report = BugReport(
        title: title,
        description: description,
        category: category,
        steps: steps,
        deviceInfo: deviceInfo,
        osVersion: osVersion,
        appVersion: appVersion,
        platform: platform,
        screenSize: syncMeta.screenSize,
        currentRoute: syncMeta.currentRoute,
        currentScreenName: syncMeta.currentScreenName,
        localeName: syncMeta.localeName,
        isOnline: syncMeta.isOnline,
        viewportInsets: syncMeta.viewportInsets,
        uid: user.uid,
        userEmail: user.email,
        userName: user.displayName,
        imageUrls: imageUrls,
        wantsReply: wantsReply,
        userTier: user.subscription.planId,
        createdAt: DateTime.now(),
      );

      // 캡처된 notifier 사용 (ref 호출 X — sheet dispose 후 안전)
      final issueNumber = await notifier.submit(report);

      messenger.hideCurrentSnackBar();
      final msg = issueNumber != null
          ? (isKorean ? '이슈 #$issueNumber 로 등록되었습니다.' : 'Submitted as issue #$issueNumber.')
          : (isKorean ? '제출되었습니다. 검토 후 처리됩니다.' : "Submitted. We'll review it shortly.");
      messenger.showSnackBar(SnackBar(
        content: Text(msg, style: T.body.copyWith(color: Colors.white)),
        backgroundColor: C.lvD,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      notifier.reset();
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(
          isKorean ? '제출 중 오류: $e' : 'Submit failed: $e',
          style: T.body.copyWith(color: Colors.white),
        ),
        backgroundColor: C.og,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    final categories = [
      (value: 'ui', label: isKorean ? 'UI 버그' : 'UI Bug'),
      (value: 'crash', label: isKorean ? '앱 크래시' : 'App Crash'),
      (value: 'feature', label: isKorean ? '기능 요청' : 'Feature'),
      (value: 'other', label: isKorean ? '기타' : 'Other'),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: C.bd, width: 1),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.bd2, borderRadius: BorderRadius.circular(99))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.bug_report_outlined, color: C.og, size: 22),
                  const SizedBox(width: 8),
                  Text(isKorean ? '버그 / 의견 제출' : 'Report a Bug', style: T.h3),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: C.mu),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카테고리
                      Text(isKorean ? '카테고리' : 'Category', style: T.captionBold.copyWith(color: C.tx2)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((cat) {
                          final selected = _category == cat.value;
                          return GestureDetector(
                            onTap: () => setState(() => _category = cat.value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? C.lv.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: selected ? C.lv : C.bd, width: selected ? 1.5 : 1),
                              ),
                              child: Text(cat.label, style: T.sm.copyWith(color: selected ? C.lvD : C.tx2, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // 제목
                      Text(isKorean ? '제목' : 'Title', style: T.captionBold.copyWith(color: C.tx2)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleCtrl,
                        style: T.body,
                        decoration: InputDecoration(hintText: isKorean ? '문제를 한 줄로 요약해 주세요' : 'Summarize the issue'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? (isKorean ? '제목을 입력해 주세요' : 'Enter a title') : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // 설명
                      Text(isKorean ? '설명' : 'Description', style: T.captionBold.copyWith(color: C.tx2)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        style: T.body,
                        maxLines: 4,
                        decoration: InputDecoration(hintText: isKorean ? '어떤 문제가 발생했나요?' : 'Describe what happened.', alignLabelWithHint: true),
                        validator: (v) => (v == null || v.trim().isEmpty) ? (isKorean ? '설명을 입력해 주세요' : 'Enter a description') : null,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 16),

                      // 재현 방법
                      Row(children: [
                        Text(isKorean ? '재현 방법' : 'Steps to Reproduce', style: T.captionBold.copyWith(color: C.tx2)),
                        const SizedBox(width: 6),
                        Text(isKorean ? '(선택)' : '(optional)', style: T.caption),
                      ]),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _stepsCtrl,
                        style: T.body,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: isKorean ? '1. 어느 화면에서\n2. 어떤 버튼을\n3. 무슨 일이 발생했는지' : '1. Go to\n2. Tap\n3. Observe',
                          alignLabelWithHint: true,
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 20),

                      // 이미지 첨부
                      Row(children: [
                        Text(isKorean ? '스크린샷 첨부' : 'Screenshots', style: T.captionBold.copyWith(color: C.tx2)),
                        const SizedBox(width: 6),
                        Text('(최대 5장)', style: T.caption.copyWith(color: C.mu)),
                        const Spacer(),
                        if (_images.length < 5)
                          TextButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                            label: Text(isKorean ? '추가' : 'Add'),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), visualDensity: VisualDensity.compact),
                          ),
                      ]),
                      if (_images.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _images.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: kIsWeb
                                      ? Image.memory(_images[i].$2, width: 80, height: 80, fit: BoxFit.cover)
                                      : Image.file(File(_images[i].$1.path), width: 80, height: 80, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 3, right: 3,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _images.removeAt(i)),
                                    child: Container(
                                      width: 20, height: 20,
                                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 답변받기
                      GestureDetector(
                        onTap: () => setState(() => _wantsReply = !_wantsReply),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _wantsReply ? C.lv.withValues(alpha: 0.10) : C.gx,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _wantsReply ? C.lv : C.bd, width: _wantsReply ? 1.5 : 1),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _wantsReply ? C.lv : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _wantsReply ? C.lv : C.bd2, width: 1.5),
                                ),
                                child: _wantsReply
                                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isKorean ? '답변 받기' : 'Request a reply',
                                      style: T.body.copyWith(
                                        color: _wantsReply ? C.lvD : C.tx,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      isKorean ? '접수된 이메일로 처리 결과를 알려드립니다.' : 'We\'ll follow up to your registered email.',
                                      style: T.caption.copyWith(color: C.mu),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 제출
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          // #822 (재진단) — onPressed에서 즉시 return + postFrame에 _submit 호출.
                          //   메인 스레드 즉시 반환 → ANR 차단 시도.
                          onPressed: () {
                            debugPrint('🔍 #822 button tapped');
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              debugPrint('🔍 #822 postFrame: _submit 시작');
                              _submit();
                            });
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: C.lv, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: Text(isKorean ? '제출하기' : 'Submit', style: T.bodyBold.copyWith(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
