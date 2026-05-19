import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/firestore_timeout_extension.dart';
import '../../counter/data/counter_repository.dart';
import '../../counter/domain/counter_model.dart';
import '../../pattern/domain/narrative_block.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../domain/builtin_template.dart';
import '../domain/project_step.dart';

class ProjectStepRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _stepsRef(String projectId) =>
      _db.collection('users').doc(_uid).collection('projects').doc(projectId).collection('steps');

  Stream<List<ProjectStep>> watchSteps(String projectId) {
    if (_uid.isEmpty) return Stream.value([]);
    return _stepsRef(projectId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ProjectStep.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<ProjectStep?> watchStep(String projectId, String stepId) {
    if (_uid.isEmpty || projectId.isEmpty || stepId.isEmpty) return Stream.value(null);
    return _stepsRef(projectId).doc(stepId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ProjectStep.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> addStep(
    String projectId,
    String name,
    int order, {
    String description = '',
    String note = '',
    String? photoUrl,
    int targetRow = 0,
    StepBlockType blockType = StepBlockType.text,
  }) async {
    await _stepsRef(projectId).add({
      'name': name,
      'description': description,
      'isDone': false,
      'note': note,
      'order': order,
      'photoUrl': photoUrl,
      'targetRow': targetRow,
      'blockType': blockType.name,
      'createdAt': DateTime.now().toIso8601String(),
      'doneAt': null,
    }).withServerTimeout(op: 'add_step');
  }

  Future<void> updateStepPhoto(String projectId, String stepId, String photoUrl) async {
    await _stepsRef(projectId).doc(stepId).update({'photoUrl': photoUrl}).withServerTimeout(op: 'update_step_photo');
  }

  Future<void> toggleStep(String projectId, ProjectStep step) async {
    final nowDone = !step.isDone;
    await _stepsRef(projectId).doc(step.id).update({
      'isDone': nowDone,
      'doneAt': nowDone ? DateTime.now().toIso8601String() : null,
    }).withServerTimeout(op: 'toggle_step');
    // 진행률 카운트 업데이트
    await _updateProgressCounts(projectId);
  }

  Future<void> _updateProgressCounts(String projectId) async {
    if (_uid.isEmpty) return;
    final snap = await _stepsRef(projectId).get().withServerTimeout(op: 'progress_counts_get');
    final total = snap.docs.length;
    final completed = snap.docs.where((d) => (d.data()['isDone'] as bool? ?? false)).length;
    final percent = total > 0 ? (completed / total * 100).roundToDouble() : 0.0;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('projects')
        .doc(projectId)
        .update({
      'completedStepCount': completed,
      'totalStepCount': total,
      'progressPercent': percent,
    }).withServerTimeout(op: 'progress_counts_update');
  }

  Future<void> updateStep(
    String projectId,
    String stepId, {
    required String name,
    String description = '',
    String note = '',
    int? targetRow,
    StepBlockType? blockType,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'description': description,
      'note': note,
    };
    if (targetRow != null) updates['targetRow'] = targetRow;
    if (blockType != null) updates['blockType'] = blockType.name;
    await _stepsRef(projectId).doc(stepId).update(updates).withServerTimeout(op: 'update_step');
  }

  Future<void> updateNote(String projectId, String stepId, String note) async {
    await _stepsRef(projectId).doc(stepId).update({'note': note}).withServerTimeout(op: 'update_note');
  }

  Future<void> deleteStep(String projectId, String stepId) async {
    await _stepsRef(projectId).doc(stepId).delete().withServerTimeout(op: 'delete_step');
  }

  Future<void> updateStepOrder(String projectId, String stepId, int newOrder) async {
    await _stepsRef(projectId).doc(stepId).update({'order': newOrder}).withServerTimeout(op: 'update_step_order');
  }

  Future<void> swapStepOrders(String projectId, String stepIdA, int newOrderA, String stepIdB, int newOrderB) async {
    final batch = _db.batch();
    batch.update(_stepsRef(projectId).doc(stepIdA), {'order': newOrderA});
    batch.update(_stepsRef(projectId).doc(stepIdB), {'order': newOrderB});
    await batch.commit().withServerTimeout(op: 'swap_step_orders');
  }

  Future<void> addDefaultSteps(String projectId) async {
    final defaults = ['코잡기 (Cast on)', '몸통 뜨기', '소매 분리', '마무리 (Finishing)'];
    for (int i = 0; i < defaults.length; i++) {
      await addStep(projectId, defaults[i], i);
    }
  }

  Future<void> copySteps(String fromProjectId, String toProjectId) async {
    final snap = await _stepsRef(fromProjectId).orderBy('order').get().withServerTimeout(op: 'copy_steps_get');
    for (final doc in snap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['isDone'] = false;
      data['doneAt'] = null;
      data['photoUrl'] = null;
      data['createdAt'] = DateTime.now().toIso8601String();
      await _stepsRef(toProjectId).add(data).withServerTimeout(op: 'copy_step_add');
    }
  }

  Future<void> addBuiltinTemplateSteps(String projectId, BuiltinTemplate template, bool isKorean) async {
    final steps = isKorean ? template.stepsKo : template.stepsEn;
    final notesKo = template.stepNotesKo;
    final notesEn = template.stepNotesEn;
    final targetRows = template.stepTargetRows;
    for (int i = 0; i < steps.length; i++) {
      final note = isKorean
          ? (i < notesKo.length ? notesKo[i] : '')
          : (i < notesEn.length ? notesEn[i] : '');
      final targetRow = i < targetRows.length ? targetRows[i] : 0;
      await addStep(projectId, steps[i], i, note: note, targetRow: targetRow);
    }
  }

  /// 이슈 #627 + #626 — 도안의 sections(=단계 그룹)을 프로젝트 단계로그로 미러링.
  /// 각 섹션 1개 = ProjectStep 1개. 섹션에 속한 서술형 블록은 note에 불릿으로 합침.
  ///
  /// 게이트 (#626):
  /// - 도안이 draft이면(isComplete == false) 아무 것도 하지 않음 (no-op).
  /// - 내용이 비어있는(블록·steps 모두 없는) 개별 섹션은 skip.
  Future<void> addPatternSectionSteps(
    String projectId,
    PatternChart chart,
    bool isKorean,
  ) async {
    // 이슈 #626 — draft 도안은 미러링 차단
    if (!chart.isComplete) return;

    final sections = chart.aiSections ?? const [];
    if (sections.isEmpty) return;

    final blocks = chart.narrativeBlocks;
    int order = 0;
    for (final sec in sections) {
      final title = isKorean ? (sec.titleKo ?? sec.title) : sec.title;

      // 섹션에 속한 서술형 블록 우선, 없으면 AiStep 사용
      final sectionBlocks =
          blocks.where((b) => b.sectionId == sec.id).toList()
            ..sort((a, b) => a.order.compareTo(b.order));

      final noteLines = <String>[];
      if (sectionBlocks.isNotEmpty) {
        for (final b in sectionBlocks) {
          noteLines.add('• ${b.text}');
        }
      } else {
        for (final s in sec.steps) {
          final text = isKorean ? (s.instructionKo ?? s.instruction) : s.instruction;
          if (text.trim().isNotEmpty) noteLines.add('• $text');
        }
      }

      // 이슈 #626 — 내용 없는 섹션(제목만 있는 껍데기) skip
      if (noteLines.isEmpty && title.trim().isEmpty) continue;
      if (noteLines.isEmpty && sectionBlocks.isEmpty && sec.steps.isEmpty) {
        continue;
      }

      await _stepsRef(projectId).add({
        'name': title.isEmpty ? (isKorean ? '섹션 ${order + 1}' : 'Section ${order + 1}') : title,
        'description': '',
        'isDone': false,
        'note': noteLines.join('\n'),
        'order': order,
        'photoUrl': null,
        'targetRow': 0,
        'blockType': StepBlockType.text.name,
        'createdAt': DateTime.now().toIso8601String(),
        'doneAt': null,
        'sourceSectionId': sec.id,
        'sourcePatternChartId': chart.id,
      }).withServerTimeout(op: 'add_pattern_section_step');
      order++;
    }
    await _updateProgressCounts(projectId);
  }

  /// 이슈 #627 (B-1) + #821 — 단계 미러링 + 도안당 카운터 1개 자동 생성.
  /// `addPatternSectionSteps`의 확장판. 도안 라이브러리 핵심 흐름.
  ///
  /// 정책 (#821, 2026-05-19 확정):
  /// - 섹션별 ProjectStep 생성은 유지 (단계 미러링)
  /// - **카운터는 도안 1개당 1개만 자동 생성** (첫 단계에 앵커)
  /// - 단계 전환은 카운터의 `currentStepIndex` 필드로 추적
  /// - 더 세분화된 카운터는 사용자가 단계 화면 [추가 카운터]로 수동 생성
  ///
  /// targetRowCount는 첫 단계 섹션 텍스트에서 "N단"/"Row N" 패턴으로 추정.
  Future<void> addPatternSectionStepsWithCounters(
    String projectId,
    PatternChart chart,
    bool isKorean,
    CounterRepository counterRepo,
  ) async {
    if (!chart.isComplete) return;
    final sections = chart.aiSections ?? const [];
    if (sections.isEmpty) return;

    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final blocks = chart.narrativeBlocks;

    // #821 — 첫 단계 step의 ID, 이름, 예상 단수를 보관해 도안당 카운터 1개 생성에 사용.
    String? firstStepId;
    String? firstStepName;
    int? firstStepEstimatedRows;

    int order = 0;
    for (final sec in sections) {
      final title = isKorean ? (sec.titleKo ?? sec.title) : sec.title;

      final sectionBlocks = blocks.where((b) => b.sectionId == sec.id).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      final noteLines = <String>[];
      if (sectionBlocks.isNotEmpty) {
        for (final b in sectionBlocks) {
          noteLines.add('• ${b.text}');
        }
      } else {
        for (final s in sec.steps) {
          final text = isKorean ? (s.instructionKo ?? s.instruction) : s.instruction;
          if (text.trim().isNotEmpty) noteLines.add('• $text');
        }
      }
      if (noteLines.isEmpty && sectionBlocks.isEmpty && sec.steps.isEmpty) {
        continue;
      }

      final estimatedRows = _estimateRowCount(sec, sectionBlocks);
      final stepName = title.isEmpty
          ? (isKorean ? '섹션 ${order + 1}' : 'Section ${order + 1}')
          : title;

      final stepDocRef = await _stepsRef(projectId).add({
        'name': stepName,
        'description': '',
        'isDone': false,
        'note': noteLines.join('\n'),
        'order': order,
        'photoUrl': null,
        'targetRow': estimatedRows ?? 0,
        'blockType': StepBlockType.text.name,
        'createdAt': DateTime.now().toIso8601String(),
        'doneAt': null,
        'sourceSectionId': sec.id,
        'sourcePatternChartId': chart.id,
      }).withServerTimeout(op: 'add_section_step_with_counter');

      // #821 — 첫 단계만 카운터 앵커로 기억. 카운터는 루프 종료 후 1개만 생성.
      if (firstStepId == null) {
        firstStepId = stepDocRef.id;
        firstStepName = stepName;
        firstStepEstimatedRows = estimatedRows;
      }

      order++;
    }

    // #821 — 도안 1개당 카운터 1개 자동 생성 (첫 단계에 앵커, currentStepIndex=0).
    if (firstStepId != null) {
      final patternName = chart.title;
      final counterName =
          (patternName.trim().isNotEmpty ? patternName : (firstStepName ?? ''));
      final counter = CounterModel(
        id: '',
        uid: uid,
        name: counterName,
        projectId: projectId,
        projectStepId: firstStepId,
        patternChartId: chart.id,
        targetRowCount: firstStepEstimatedRows ?? 0,
        currentStepIndex: 0,
      );
      await counterRepo.createCounter(counter);
    }

    await _updateProgressCounts(projectId);
  }

  /// 섹션의 블록·steps 텍스트에서 "N단" / "Row N" 패턴 추출하여 가장 큰 N 반환.
  /// 카운터 targetRow 추정용. 매칭 없으면 null.
  int? _estimateRowCount(
    dynamic sec,
    List<NarrativeBlock> sectionBlocks,
  ) {
    final regex = RegExp(r'(\d+)\s*(단|Row|row|행)', caseSensitive: false);
    int maxRow = 0;
    for (final b in sectionBlocks) {
      for (final m in regex.allMatches(b.text)) {
        final n = int.tryParse(m.group(1) ?? '');
        if (n != null && n > maxRow) maxRow = n;
      }
    }
    final steps = sec.steps as List;
    for (final s in steps) {
      final txt = (s.instruction as String?) ?? '';
      for (final m in regex.allMatches(txt)) {
        final n = int.tryParse(m.group(1) ?? '');
        if (n != null && n > maxRow) maxRow = n;
      }
      final txtKo = (s.instructionKo as String?) ?? '';
      for (final m in regex.allMatches(txtKo)) {
        final n = int.tryParse(m.group(1) ?? '');
        if (n != null && n > maxRow) maxRow = n;
      }
    }
    return maxRow > 0 ? maxRow : null;
  }

  Future<void> addTemplateSteps(String projectId, String templateType) async {
    // Each entry: (name, note, targetRow)
    final templates = <String, List<(String, String, int)>>{
      'topdown': [
        ('코잡기 (Cast on)', '넥라인 코수를 잡아요. 일반적으로 80~120코. 원형뜨기 시작 마커 설치.', 0),
        ('넥밴드 뜨기', '1×1 또는 2×2 리브로 2~4cm (약 10~16단). 목 너비가 편안한지 확인.', 14),
        ('래글런 증가', '8코마다 코늘림 4곳 × 2코 = 매 2단 8코 증가. 래글런 라인 마커 4개 설치.', 40),
        ('앞뒤판 & 소매 분리', '소매 코를 여분 실에 옮기고 앞뒤판 연결. 겨드랑이 코 2~8코 추가.', 0),
        ('몸통 뜨기 (Body)', '원하는 기장까지 메리야스뜨기. 중간에 허리선 감소/증가 가능. 일반적으로 25~35cm.', 60),
        ('밑단 마무리', '1×1 리브 2~3cm 뜨고 코막기. 너무 조이지 않게 느슨하게 막기.', 10),
        ('소매 뜨기', '여분 실에서 코 되살리기. 소매 너비는 25~30cm 원형. 소매 감소: 7~10단마다 2코 감소.', 50),
        ('마무리 (Finishing)', '실 정리, 세탁 후 블로킹. 넥밴드 봉합, 겨드랑이 구멍 막기.', 0),
      ],
      'socks': [
        ('코잡기', '양말 사이즈별: S=56코, M=64코, L=72코. 주로 매직루프 or DPN으로 시작.', 0),
        ('커프 & 리브', '2×2 리브로 3~5cm. 탄성이 중요해요. 약 16~24단.', 20),
        ('레그 뜨기', '메리야스뜨기 또는 무늬뜨기로 15~20cm. 패턴 넣을 자리.', 40),
        ('힐 플랩 (Heel flap)', '코의 절반으로 힐 작업. 왕복뜨기 20~24단. 슬립스티치로 강도 높이기.', 22),
        ('힐 턴 (Heel turn)', '단계별 단 줄임으로 컵 모양 만들기. 남은 코 1/3 정도 될 때까지.', 0),
        ('거싯 감소 (Gusset)', '힐 양쪽에서 코 줍기. 2단마다 1코씩 감소해서 원래 코수로 돌아가기.', 16),
        ('발 뜨기', '발 길이 - 발끝 길이만큼 뜨기. 발끝 시작점 맞추기 중요.', 30),
        ('발끝 감소 & 마무리 (Toe)', '4곳 감소, 매 2단마다. 16~20코 남으면 키치너 스티치로 닫기.', 12),
      ],
      'scarf': [
        ('코잡기', '목도리 너비에 맞게 코잡기. 일반적으로 30~50코. 거터스티치면 짝수/홀수 모두 OK.', 0),
        ('패턴 뜨기 시작', '선택한 패턴(가터/메리야스/무늬뜨기) 시작. 첫 5단은 게이지 확인.', 10),
        ('중간 지점', '목표 길이 절반. 원하는 최종 길이의 50%. 실 사용량 체크.', 0),
        ('목표 길이 완성', '세탁 후 약 10% 수축 감안. 150cm 목표면 165cm까지 뜨기.', 0),
        ('코막기 & 마무리', '느슨하게 코막기. 실 정리 후 물세탁 블로킹으로 마무리.', 0),
      ],
      'gloves': [
        ('코잡기', '손목 둘레 측정. 일반적으로 36~48코. 2×2 리브 시작.', 0),
        ('손목 리브', '2×2 또는 1×1 리브 5~7cm. 탄성 중요. 약 24~32단.', 28),
        ('손등 & 손바닥 뜨기', '메리야스뜨기로 손허리까지. 엄지 가싯 준비 마커 설치.', 20),
        ('엄지 분리', '엄지 가싯: 2단마다 2코 증가. 엄지 코 여분 실에 옮기고 연결.', 12),
        ('손가락 분리', '검지부터 차례로 분리. 각 손가락 코 = 전체 코 / 4 정도.', 0),
        ('손가락 완성', '각 손가락 원하는 길이까지 뜨고 감소로 마무리. 실 당겨 닫기.', 16),
        ('엄지 완성', '여분 실에서 엄지 코 되살리기. 원형뜨기로 엄지 길이 완성.', 12),
      ],
      'hat': [
        ('코잡기', '머리 둘레 측정. 성인 56~58cm. 코수 = 둘레 × 게이지. 일반 90~120코.', 0),
        ('브림 리브', '1×1 또는 2×2 리브 3~5cm. 접어 올리는 스타일이면 2배로.', 20),
        ('크라운 뜨기', '메리야스뜨기로 원하는 높이까지. 총 높이에서 리브 빼고 나머지.', 30),
        ('크라운 감소', '6~8군데 균등 감소. 매 2단마다 감소. 16~12코 남을 때까지.', 16),
        ('마무리', '실 꿰어 남은 코 모아 닫기. 실 정리 후 블로킹.', 0),
      ],
      // 이슈 #637 — 래글런 탑다운 (Banul 메리노블렌드 DK 크롭 레글런 기반)
      'crop_raglan_topdown': [
        ('목둘레 코잡기', '3.5mm 바늘 + 40cm 케이블. 사이즈별 원통 코잡기 — XS:92, S:96, M:104, L:108, XL/2XL/3XL:112코. 시작 마커 설치.', 0),
        ('목 고무단 (6cm)', '1코 고무뜨기로 약 17단. 겹단 처리 후 4mm로 바늘 교체.', 17),
        ('앞목 쉐이핑 & 래글런 늘림 1 (11단)', '셋업단: 마커 9개 배치 (오른쪽뒷판/레글런/오른쪽소매/레글런/앞판/레글런/왼쪽소매/레글런/왼쪽뒷판). 독일식 짧은단 턴(german short row) 포함. 모든 사이즈 동일하게 11단.', 11),
        ('래글런 늘림 2 (반복)', '1단 늘림단(M1R×4, M1L×4 = +8코) + 2단 유지 반복. 사이즈별 반복: XS 23회 · S 25회 · M 26회 · L 28회 · XL 29회 · 2XL 30회 · 3XL 32회.', 0),
        ('XL+ 몸통 추가단', '몸통쪽 앞뒤판에만 +4코. XL 1회, 2XL·3XL 2회 반복. (XS/S/M/L은 건너뜀)', 0),
        ('소매 분리 & 겨드랑이 감아코', '소매 코를 자투리 실로 옮겨 쉬게 함. 겨드랑이 감아코 — XS/S:4, M/L:6, XL:8, 2XL:10, 3XL:12코.', 0),
        ('몸통 메리야스 뜨기', '원통 메리야스. 단수표시링부터 사이즈별 — XS:35, S:37, M:39, L:41, XL:42, 2XL:43, 3XL:44cm까지.', 0),
        ('몸통 코줄임 (1단)', '[k2tog, 겉뜨기 N코] × M번 + k2tog. 사이즈별 — XS:[K2tog,9]×17, S:[K2tog,10]×17, M:[K2tog,9]×19, L:[K2tog,10]×19, XL:[K2tog,9]×21, 2XL:[K2tog,10]×21, 3XL:[K2tog,9]×23.', 0),
        ('몸통 고무단 (7cm)', '3.5mm로 바꿔 1코 고무뜨기. 다 뜨면 돗바늘 코막음으로 마무리.', 0),
        ('소매 뜨기', '쉬어둔 소매 코 + 겨드랑이 감아코 절반씩 줍기. 원통 메리야스. 2코 남을 때까지 겉뜨기 k2tog/ssk 코줄임을 사이즈별 간격으로 반복.', 0),
        ('소매 길이 완성', '소매 분리 지점부터 사이즈별 — XS:38, S/M:39, L/XL:40, 2XL:39, 3XL:38cm까지 뜨기.', 0),
        ('소매 고무단 & 마무리', '3.5mm 1코 고무뜨기 7cm + 돗바늘 코막음. 꼬리실 정리 + 겨드랑이 구멍 봉합.', 0),
      ],
    };
    final steps = templates[templateType] ?? templates['topdown']!;
    for (int i = 0; i < steps.length; i++) {
      await addStep(
        projectId,
        steps[i].$1,
        i,
        note: steps[i].$2,
        targetRow: steps[i].$3,
      );
    }
  }
}
