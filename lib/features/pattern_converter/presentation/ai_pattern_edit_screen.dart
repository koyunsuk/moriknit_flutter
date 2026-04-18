import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/ai_pattern_section.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../data/pattern_converter_repository.dart';

class AiPatternEditScreen extends ConsumerStatefulWidget {
  /// 저장되지 않은 새 도안 (uploadAndParse 직후)
  final PatternChart? unsavedChart;

  /// 이미 저장된 도안 ID (편집 재진입)
  final String? patternId;

  const AiPatternEditScreen({
    super.key,
    this.unsavedChart,
    this.patternId,
  }) : assert(
          unsavedChart != null || patternId != null,
          'unsavedChart or patternId must be provided',
        );

  @override
  ConsumerState<AiPatternEditScreen> createState() =>
      _AiPatternEditScreenState();
}

class _AiPatternEditScreenState extends ConsumerState<AiPatternEditScreen> {
  final _titleCtrl = TextEditingController();
  List<AiSection> _sections = [];
  bool _loading = true;

  // 각 섹션 제목 컨트롤러 map
  final Map<String, TextEditingController> _sectionTitleCtrls = {};
  // 각 단계 instruction 컨트롤러 map
  final Map<String, TextEditingController> _stepCtrls = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.unsavedChart != null) {
      final chart = widget.unsavedChart!;
      _titleCtrl.text = chart.title;
      _sections = chart.aiSections ?? [];
      _buildControllers();
      if (mounted) setState(() => _loading = false);
    } else {
      // patternId로 Firestore에서 로드
      final repo = PatternConverterRepository();
      final stream = repo.watchAiPattern(widget.patternId!);
      final chart = await stream.first;
      if (chart != null) {
        _titleCtrl.text = chart.title;
        _sections = chart.aiSections ?? [];
        _buildControllers();
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  void _buildControllers() {
    for (final sec in _sections) {
      _sectionTitleCtrls[sec.id] ??= TextEditingController(text: sec.title);
      for (final step in sec.steps) {
        _stepCtrls[step.id] ??= TextEditingController(text: step.instruction);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _sectionTitleCtrls.values) {
      c.dispose();
    }
    for (final c in _stepCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── 섹션 편집 헬퍼 ─────────────────────────────────────────────

  void _addSection() {
    final sec = AiSection.create(title: '새 섹션');
    _sectionTitleCtrls[sec.id] = TextEditingController(text: sec.title);
    setState(() => _sections = [..._sections, sec]);
  }

  void _deleteSection(String sectionId) {
    _sectionTitleCtrls[sectionId]?.dispose();
    _sectionTitleCtrls.remove(sectionId);
    setState(() =>
        _sections = _sections.where((s) => s.id != sectionId).toList());
  }

  void _addStep(String sectionId) {
    const uuid = Uuid();
    final step = AiStep(id: uuid.v4(), instruction: '');
    _stepCtrls[step.id] = TextEditingController();
    setState(() {
      _sections = _sections.map((sec) {
        if (sec.id != sectionId) return sec;
        return sec.copyWith(steps: [...sec.steps, step]);
      }).toList();
    });
    // 포커스 이동은 nextFrame에서 처리
  }

  void _deleteStep(String sectionId, String stepId) {
    _stepCtrls[stepId]?.dispose();
    _stepCtrls.remove(stepId);
    setState(() {
      _sections = _sections.map((sec) {
        if (sec.id != sectionId) return sec;
        return sec.copyWith(
            steps: sec.steps.where((s) => s.id != stepId).toList());
      }).toList();
    });
  }

  // ── 최신 컨트롤러 값으로 섹션 동기화 ─────────────────────────
  List<AiSection> _syncedSections() {
    return _sections.map((sec) {
      final title = _sectionTitleCtrls[sec.id]?.text ?? sec.title;
      final steps = sec.steps.map((step) {
        final instruction = _stepCtrls[step.id]?.text ?? step.instruction;
        return step.copyWith(instruction: instruction);
      }).toList();
      return sec.copyWith(title: title, steps: steps);
    }).toList();
  }

  // ── 저장 ──────────────────────────────────────────────────────
  Future<void> _save() async {
    final isKorean = ref.read(appLanguageProvider).isKorean;
    final messenger = ScaffoldMessenger.of(context);
    final syncedSections = _syncedSections();
    final title = _titleCtrl.text.trim().isEmpty ? '무제 도안' : _titleCtrl.text.trim();

    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '저장하는 중입니다.' : 'Saving...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          final patternRepo = ref.read(patternRepositoryProvider);
          final converterRepo = PatternConverterRepository();

          if (widget.unsavedChart != null) {
            // 새 도안 저장
            final chart = widget.unsavedChart!.copyWith(
              title: title,
              aiSections: syncedSections,
            );
            await patternRepo.save(chart);
            // 저장 후 편집 화면을 종료하고 도안 목록으로 이동
            if (mounted) {
              context.go(Routes.toolsMyParsedPatterns);
            }
          } else {
            // 기존 도안 업데이트
            final patternId = widget.patternId!;
            // 제목 업데이트 + 섹션 업데이트
            final existingChart = await patternRepo.get(patternId);
            if (existingChart != null) {
              await patternRepo.save(existingChart.copyWith(
                title: title,
                aiSections: syncedSections,
              ));
            } else {
              await converterRepo.updateSections(patternId, syncedSections);
            }
            if (mounted) {
              context.go(Routes.toolsMyParsedPatterns);
            }
          }
        },
      );
      if (!mounted) return;
      showSavedSnackBar(messenger,
          message: isKorean ? '저장됐어요.' : 'Saved.');
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(messenger, message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: C.tx,
          onPressed: () => context.pop(),
        ),
        title: Text(
          isKorean ? '변환 결과 확인' : 'Review Result',
          style: T.h3,
        ),
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(
              isKorean ? '저장하기' : 'Save',
              style: T.sm.copyWith(
                color: C.lv,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                const BgOrbs(),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 도안 제목
                      SectionTitle(
                          title: isKorean ? '도안 제목' : 'Pattern Title'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleCtrl,
                        style: T.body,
                        decoration: InputDecoration(
                          labelText: isKorean ? '제목' : 'Title',
                          hintText: isKorean ? '도안 제목을 입력해 주세요' : 'Enter title',
                          fillColor: C.gx,
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 섹션 리스트
                      SectionTitle(
                          title: isKorean ? '섹션 목록' : 'Sections'),
                      const SizedBox(height: 8),

                      if (_sections.isEmpty)
                        _EmptyPlaceholder(isKorean: isKorean)
                      else
                        ..._sections.map((sec) => _SectionCard(
                              key: ValueKey(sec.id),
                              section: sec,
                              titleCtrl: _sectionTitleCtrls[sec.id]!,
                              stepCtrls: _stepCtrls,
                              isKorean: isKorean,
                              onDeleteSection: () => _deleteSection(sec.id),
                              onAddStep: () => _addStep(sec.id),
                              onDeleteStep: (stepId) =>
                                  _deleteStep(sec.id, stepId),
                            )),

                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _addSection,
                        icon: Icon(Icons.add_circle_outline_rounded,
                            color: C.lv, size: 18),
                        label: Text(
                          isKorean ? '+ 섹션 추가' : '+ Add Section',
                          style: T.sm.copyWith(color: C.lv),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
            ),
            child: Text(isKorean ? '저장하기' : 'Save'),
          ),
        ),
      ),
    );
  }
}

// ── 섹션 카드 ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final AiSection section;
  final TextEditingController titleCtrl;
  final Map<String, TextEditingController> stepCtrls;
  final bool isKorean;
  final VoidCallback onDeleteSection;
  final VoidCallback onAddStep;
  final void Function(String stepId) onDeleteStep;

  const _SectionCard({
    super.key,
    required this.section,
    required this.titleCtrl,
    required this.stepCtrls,
    required this.isKorean,
    required this.onDeleteSection,
    required this.onAddStep,
    required this.onDeleteStep,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: titleCtrl,
                  style: T.body.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: isKorean ? '섹션 제목' : 'Section title',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    fillColor: Colors.transparent,
                    filled: true,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: C.og, size: 20),
                onPressed: onDeleteSection,
                tooltip: isKorean ? '섹션 삭제' : 'Delete section',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 20),

          // 단계 리스트
          if (section.steps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                isKorean ? '단계가 없어요. 아래 버튼으로 추가해 주세요.' : 'No steps. Tap below to add.',
                style: T.caption.copyWith(color: C.tx2),
              ),
            )
          else
            ...section.steps.map((step) {
              final ctrl = stepCtrls[step.id];
              if (ctrl == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 8),
                      child: Icon(Icons.drag_indicator_rounded,
                          size: 16, color: C.tx2),
                    ),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        maxLines: null,
                        style: T.sm,
                        decoration: InputDecoration(
                          hintText: isKorean ? '단계 내용' : 'Step instruction',
                          fillColor: C.gx,
                          filled: true,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: C.og, size: 18),
                      onPressed: () => onDeleteStep(step.id),
                      tooltip: isKorean ? '단계 삭제' : 'Delete step',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              );
            }),

          TextButton.icon(
            onPressed: onAddStep,
            icon: Icon(Icons.add_rounded, size: 16, color: C.lv),
            label: Text(
              isKorean ? '+ 단계 추가' : '+ Add Step',
              style: T.caption.copyWith(color: C.lv),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 플레이스홀더 ─────────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  final bool isKorean;
  const _EmptyPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(Icons.layers_outlined, size: 40, color: C.tx2),
          const SizedBox(height: 8),
          Text(
            isKorean ? '섹션이 없어요.' : 'No sections yet.',
            style: T.sm.copyWith(color: C.tx2),
          ),
          const SizedBox(height: 4),
          Text(
            isKorean ? '아래 버튼으로 섹션을 추가해 주세요.' : 'Add a section below.',
            style: T.caption.copyWith(color: C.tx2),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
