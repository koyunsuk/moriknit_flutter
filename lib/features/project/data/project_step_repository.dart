import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> addStep(String projectId, String name, int order, {String? photoUrl}) async {
    await _stepsRef(projectId).add({
      'name': name,
      'isDone': false,
      'note': '',
      'order': order,
      'photoUrl': photoUrl,
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
  }

  Future<void> updateNote(String projectId, String stepId, String note) async {
    await _stepsRef(projectId).doc(stepId).update({'note': note});
  }

  Future<void> deleteStep(String projectId, String stepId) async {
    await _stepsRef(projectId).doc(stepId).delete();
  }

  Future<void> addDefaultSteps(String projectId) async {
    final defaults = ['코잡기 (Cast on)', '몸통 뜨기', '소매 분리', '마무리 (Finishing)'];
    for (int i = 0; i < defaults.length; i++) {
      await addStep(projectId, defaults[i], i);
    }
  }

  Future<void> addTemplateSteps(String projectId, String templateType) async {
    final templates = <String, List<String>>{
      'topdown': [
        '코잡기 (Cast on)',
        '넥밴드 & 목 뜨기',
        '래글런 증가 (Raglan increases)',
        '앞뒤판 & 소매 분리',
        '몸통 뜨기 (Body)',
        '소매 뜨기 (Sleeves)',
        '밑단 마무리 (Hem)',
        '마무리 (Finishing)',
      ],
      'socks': [
        '코잡기 (Cast on)',
        '커프 & 리브 (Cuff/Rib)',
        '레그 뜨기 (Leg)',
        '힐 플랩 (Heel flap)',
        '힐 턴 (Heel turn)',
        '거싯 감소 (Gusset)',
        '발 뜨기 (Foot)',
        '발끝 감소 & 마무리 (Toe)',
      ],
      'scarf': [
        '코잡기 (Cast on)',
        '패턴 뜨기 시작',
        '절반 지점 확인',
        '목표 길이 완성',
        '코막기 & 마무리 (Bind off)',
      ],
      'gloves': [
        '코잡기 (Cast on)',
        '손목 리브 (Wrist rib)',
        '손등 & 손바닥 뜨기',
        '엄지 분리 (Thumb gusset)',
        '손가락 분리 뜨기',
        '손가락 마무리',
        '엄지 완성',
      ],
      'hat': [
        '코잡기 (Cast on)',
        '브림 리브 (Brim rib)',
        '크라운 뜨기 (Crown)',
        '크라운 감소 (Decreases)',
        '마무리 (Finishing)',
      ],
    };
    final steps = templates[templateType] ?? templates['topdown']!;
    for (int i = 0; i < steps.length; i++) {
      await addStep(projectId, steps[i], i);
    }
  }
}
