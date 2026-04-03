import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    });
  }

  Future<void> updateStepPhoto(String projectId, String stepId, String photoUrl) async {
    await _stepsRef(projectId).doc(stepId).update({'photoUrl': photoUrl});
  }

  Future<void> toggleStep(String projectId, ProjectStep step) async {
    final nowDone = !step.isDone;
    await _stepsRef(projectId).doc(step.id).update({
      'isDone': nowDone,
      'doneAt': nowDone ? DateTime.now().toIso8601String() : null,
    });
    // 진행률 카운트 업데이트
    await _updateProgressCounts(projectId);
  }

  Future<void> _updateProgressCounts(String projectId) async {
    if (_uid.isEmpty) return;
    final snap = await _stepsRef(projectId).get();
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
    });
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
    await _stepsRef(projectId).doc(stepId).update(updates);
  }

  Future<void> updateNote(String projectId, String stepId, String note) async {
    await _stepsRef(projectId).doc(stepId).update({'note': note});
  }

  Future<void> deleteStep(String projectId, String stepId) async {
    await _stepsRef(projectId).doc(stepId).delete();
  }

  Future<void> updateStepOrder(String projectId, String stepId, int newOrder) async {
    await _stepsRef(projectId).doc(stepId).update({'order': newOrder});
  }

  Future<void> swapStepOrders(String projectId, String stepIdA, int newOrderA, String stepIdB, int newOrderB) async {
    final batch = _db.batch();
    batch.update(_stepsRef(projectId).doc(stepIdA), {'order': newOrderA});
    batch.update(_stepsRef(projectId).doc(stepIdB), {'order': newOrderB});
    await batch.commit();
  }

  Future<void> addDefaultSteps(String projectId) async {
    final defaults = ['코잡기 (Cast on)', '몸통 뜨기', '소매 분리', '마무리 (Finishing)'];
    for (int i = 0; i < defaults.length; i++) {
      await addStep(projectId, defaults[i], i);
    }
  }

  Future<void> copySteps(String fromProjectId, String toProjectId) async {
    final snap = await _stepsRef(fromProjectId).orderBy('order').get();
    for (final doc in snap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['isDone'] = false;
      data['doneAt'] = null;
      data['photoUrl'] = null;
      data['createdAt'] = DateTime.now().toIso8601String();
      await _stepsRef(toProjectId).add(data);
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
