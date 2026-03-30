import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/bug_report_provider.dart';
import '../../auth/domain/user_model.dart';
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

  Future<({String deviceInfo, String osVersion, String platform})> _getSystemInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final info = await plugin.webBrowserInfo;
        final ua = info.userAgent ?? '';
        // OS 추출: userAgent에서 플랫폼 정보 파싱
        String osVersion = info.platform ?? '';
        if (ua.contains('Windows')) {
          osVersion = 'Windows';
        } else if (ua.contains('Mac OS X')) {
          osVersion = 'macOS';
        } else if (ua.contains('Android')) {
          osVersion = 'Android (웹)';
        } else if (ua.contains('iPhone') || ua.contains('iPad')) {
          osVersion = 'iOS (웹)';
        } else if (ua.contains('Linux')) {
          osVersion = 'Linux';
        }
        final browser = ua.contains('Chrome') ? 'Chrome'
            : ua.contains('Firefox') ? 'Firefox'
            : ua.contains('Safari') ? 'Safari'
            : 'Browser';
        return (deviceInfo: browser, osVersion: osVersion, platform: 'web');
      }
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return (
          deviceInfo: '${info.manufacturer} ${info.model}',
          osVersion: 'Android ${info.version.release} (SDK ${info.version.sdkInt})',
          platform: 'android',
        );
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return (
          deviceInfo: '${info.name} (${info.model})',
          osVersion: '${info.systemName} ${info.systemVersion}',
          platform: 'ios',
        );
      }
      return (deviceInfo: 'Unknown', osVersion: '', platform: 'other');
    } catch (e) {
      debugPrint('[BugReport] 시스템 정보 수집 실패: $e');
      return (deviceInfo: 'Unknown', osVersion: '', platform: 'other');
    }
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '1.0.0';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isKorean = ref.read(appLanguageProvider).isKorean;

    final sysInfo = await _getSystemInfo();
    final appVersion = await _getAppVersion();

    if (!mounted) return;

    int? issueNumber;
    try {
      issueNumber = await runWithMoriLoadingDialog<int?>(
        context,
        message: isKorean ? '제출하는 중입니다.' : 'Submitting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          // 이미지 업로드
          final repo = ref.read(bugReportRepositoryProvider);
          final imageUrls = _images.isNotEmpty
              ? await repo.uploadImages(widget.user.uid, _images.map((e) => e.$2).toList())
              : <String>[];

          final report = BugReport(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            category: _category,
            steps: _stepsCtrl.text.trim(),
            deviceInfo: sysInfo.deviceInfo,
            osVersion: sysInfo.osVersion,
            appVersion: appVersion,
            platform: sysInfo.platform,
            uid: widget.user.uid,
            userEmail: widget.user.email,
            userName: widget.user.displayName,
            imageUrls: imageUrls,
            wantsReply: _wantsReply,
            userTier: widget.user.subscription.planId,
            createdAt: DateTime.now(),
          );

          return ref.read(bugReportProvider.notifier).submit(report);
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isKorean ? '제출 중 오류가 발생했습니다.' : 'An error occurred. Please try again.'),
          backgroundColor: C.og,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    final msg = issueNumber != null
        ? (isKorean ? '이슈 #$issueNumber 로 등록되었습니다.' : 'Submitted as issue #$issueNumber.')
        : (isKorean ? '제출되었습니다. 검토 후 처리됩니다.' : 'Submitted. We\'ll review it shortly.');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: T.body.copyWith(color: Colors.white)),
      backgroundColor: C.lvD,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

    ref.read(bugReportProvider.notifier).reset();
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
                          onPressed: _submit,
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
