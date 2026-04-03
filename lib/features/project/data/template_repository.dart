import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/builtin_template.dart';
import '../domain/user_template.dart';

class TemplateRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('templates');

  Stream<List<UserTemplate>> watchTemplates() {
    if (_uid.isEmpty) return Stream.value([]);
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserTemplate.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> create({
    required String title,
    required String description,
    required List<String> stepTitles,
    required List<String> stepDescs,
  }) async {
    if (_uid.isEmpty) return;
    await _col.add({
      'title': title,
      'description': description,
      'stepTitles': stepTitles,
      'stepDescs': stepDescs,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': null,
    });
  }

  Future<void> update({
    required String id,
    required String title,
    required String description,
    required List<String> stepTitles,
    required List<String> stepDescs,
  }) async {
    if (_uid.isEmpty) return;
    await _col.doc(id).update({
      'title': title,
      'description': description,
      'stepTitles': stepTitles,
      'stepDescs': stepDescs,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> delete(String id) async {
    if (_uid.isEmpty) return;
    await _col.doc(id).delete();
  }

  Future<void> addStepToTemplate(String templateId, String stepName, String stepDesc) async {
    if (_uid.isEmpty) return;
    final doc = await _col.doc(templateId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final titles = List<String>.from(data['stepTitles'] as List? ?? []);
    final descs = List<String>.from(data['stepDescs'] as List? ?? []);
    titles.add(stepName);
    descs.add(stepDesc);
    await _col.doc(templateId).update({
      'stepTitles': titles,
      'stepDescs': descs,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ── 기본 템플릿 (builtin_templates 컬렉션) ────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _builtinCol =>
      _db.collection('builtin_templates');

  Stream<List<BuiltinTemplate>> watchBuiltinTemplates() {
    return _builtinCol
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => BuiltinTemplate.fromFirestore(doc))
              .where((t) => t.isActive)
              .toList();
          list.sort((a, b) => a.order.compareTo(b.order));
          return list;
        });
  }

  static List<Map<String, dynamic>> _builtinSeedData() {
    return [
      {
        'titleKo': '탑다운 스웨터',
        'titleEn': 'Top-Down Sweater',
        'descKo': '넥라인부터 시작 · 8단계 가이드 포함',
        'descEn': 'Start from the neckline · 8-step guide',
        'iconName': 'dry_cleaning',
        'colorHex': '#C084FC',
        'order': 1,
        'isActive': true,
        'stepsKo': [
          '코잡기 (Cast on)',
          '넥밴드 뜨기',
          '래글런 증가',
          '앞뒤판 & 소매 분리',
          '몸통 뜨기 (Body)',
          '밑단 마무리',
          '소매 뜨기',
          '마무리 (Finishing)',
        ],
        'stepsEn': [
          '코잡기 (Cast on)',
          '넥밴드 뜨기',
          '래글런 증가',
          '앞뒤판 & 소매 분리',
          '몸통 뜨기 (Body)',
          '밑단 마무리',
          '소매 뜨기',
          '마무리 (Finishing)',
        ],
        'stepNotesKo': [
          '넥라인 코수를 잡아요. 일반적으로 80~120코. 원형뜨기 시작 마커 설치.',
          '1×1 또는 2×2 리브로 2~4cm (약 10~16단). 목 너비가 편안한지 확인.',
          '8코마다 코늘림 4곳 × 2코 = 매 2단 8코 증가. 래글런 라인 마커 4개 설치.',
          '소매 코를 여분 실에 옮기고 앞뒤판 연결. 겨드랑이 코 2~8코 추가.',
          '원하는 기장까지 메리야스뜨기. 중간에 허리선 감소/증가 가능. 일반적으로 25~35cm.',
          '1×1 리브 2~3cm 뜨고 코막기. 너무 조이지 않게 느슨하게 막기.',
          '여분 실에서 코 되살리기. 소매 너비는 25~30cm 원형. 소매 감소: 7~10단마다 2코 감소.',
          '실 정리, 세탁 후 블로킹. 넥밴드 봉합, 겨드랑이 구멍 막기.',
        ],
        'stepNotesEn': [
          '넥라인 코수를 잡아요. 일반적으로 80~120코. 원형뜨기 시작 마커 설치.',
          '1×1 또는 2×2 리브로 2~4cm (약 10~16단). 목 너비가 편안한지 확인.',
          '8코마다 코늘림 4곳 × 2코 = 매 2단 8코 증가. 래글런 라인 마커 4개 설치.',
          '소매 코를 여분 실에 옮기고 앞뒤판 연결. 겨드랑이 코 2~8코 추가.',
          '원하는 기장까지 메리야스뜨기. 중간에 허리선 감소/증가 가능. 일반적으로 25~35cm.',
          '1×1 리브 2~3cm 뜨고 코막기. 너무 조이지 않게 느슨하게 막기.',
          '여분 실에서 코 되살리기. 소매 너비는 25~30cm 원형. 소매 감소: 7~10단마다 2코 감소.',
          '실 정리, 세탁 후 블로킹. 넥밴드 봉합, 겨드랑이 구멍 막기.',
        ],
        'stepTargetRows': [0, 14, 40, 0, 60, 10, 50, 0],
      },
      {
        'titleKo': '양말',
        'titleEn': 'Socks',
        'descKo': '커프부터 발끝까지 · 8단계 힐 가이드',
        'descEn': 'Cuff to toe · 8-step heel guide',
        'iconName': 'hiking',
        'colorHex': '#BE185D',
        'order': 2,
        'isActive': true,
        'stepsKo': [
          '코잡기',
          '커프 & 리브',
          '레그 뜨기',
          '힐 플랩 (Heel flap)',
          '힐 턴 (Heel turn)',
          '거싯 감소 (Gusset)',
          '발 뜨기',
          '발끝 감소 & 마무리 (Toe)',
        ],
        'stepsEn': [
          '코잡기',
          '커프 & 리브',
          '레그 뜨기',
          '힐 플랩 (Heel flap)',
          '힐 턴 (Heel turn)',
          '거싯 감소 (Gusset)',
          '발 뜨기',
          '발끝 감소 & 마무리 (Toe)',
        ],
        'stepNotesKo': [
          '양말 사이즈별: S=56코, M=64코, L=72코. 주로 매직루프 or DPN으로 시작.',
          '2×2 리브로 3~5cm. 탄성이 중요해요. 약 16~24단.',
          '메리야스뜨기 또는 무늬뜨기로 15~20cm. 패턴 넣을 자리.',
          '코의 절반으로 힐 작업. 왕복뜨기 20~24단. 슬립스티치로 강도 높이기.',
          '단계별 단 줄임으로 컵 모양 만들기. 남은 코 1/3 정도 될 때까지.',
          '힐 양쪽에서 코 줍기. 2단마다 1코씩 감소해서 원래 코수로 돌아가기.',
          '발 길이 - 발끝 길이만큼 뜨기. 발끝 시작점 맞추기 중요.',
          '4곳 감소, 매 2단마다. 16~20코 남으면 키치너 스티치로 닫기.',
        ],
        'stepNotesEn': [
          '양말 사이즈별: S=56코, M=64코, L=72코. 주로 매직루프 or DPN으로 시작.',
          '2×2 리브로 3~5cm. 탄성이 중요해요. 약 16~24단.',
          '메리야스뜨기 또는 무늬뜨기로 15~20cm. 패턴 넣을 자리.',
          '코의 절반으로 힐 작업. 왕복뜨기 20~24단. 슬립스티치로 강도 높이기.',
          '단계별 단 줄임으로 컵 모양 만들기. 남은 코 1/3 정도 될 때까지.',
          '힐 양쪽에서 코 줍기. 2단마다 1코씩 감소해서 원래 코수로 돌아가기.',
          '발 길이 - 발끝 길이만큼 뜨기. 발끝 시작점 맞추기 중요.',
          '4곳 감소, 매 2단마다. 16~20코 남으면 키치너 스티치로 닫기.',
        ],
        'stepTargetRows': [0, 20, 40, 22, 0, 16, 30, 12],
      },
      {
        'titleKo': '목도리',
        'titleEn': 'Scarf',
        'descKo': '단순하고 따뜻한 · 5단계 기본 완성',
        'descEn': 'Simple and warm · 5-step basic',
        'iconName': 'ac_unit',
        'colorHex': '#65A30D',
        'order': 3,
        'isActive': true,
        'stepsKo': [
          '코잡기',
          '패턴 뜨기 시작',
          '중간 지점',
          '목표 길이 완성',
          '코막기 & 마무리',
        ],
        'stepsEn': [
          '코잡기',
          '패턴 뜨기 시작',
          '중간 지점',
          '목표 길이 완성',
          '코막기 & 마무리',
        ],
        'stepNotesKo': [
          '목도리 너비에 맞게 코잡기. 일반적으로 30~50코. 거터스티치면 짝수/홀수 모두 OK.',
          '선택한 패턴(가터/메리야스/무늬뜨기) 시작. 첫 5단은 게이지 확인.',
          '목표 길이 절반. 원하는 최종 길이의 50%. 실 사용량 체크.',
          '세탁 후 약 10% 수축 감안. 150cm 목표면 165cm까지 뜨기.',
          '느슨하게 코막기. 실 정리 후 물세탁 블로킹으로 마무리.',
        ],
        'stepNotesEn': [
          '목도리 너비에 맞게 코잡기. 일반적으로 30~50코. 거터스티치면 짝수/홀수 모두 OK.',
          '선택한 패턴(가터/메리야스/무늬뜨기) 시작. 첫 5단은 게이지 확인.',
          '목표 길이 절반. 원하는 최종 길이의 50%. 실 사용량 체크.',
          '세탁 후 약 10% 수축 감안. 150cm 목표면 165cm까지 뜨기.',
          '느슨하게 코막기. 실 정리 후 물세탁 블로킹으로 마무리.',
        ],
        'stepTargetRows': [0, 10, 0, 0, 0],
      },
      {
        'titleKo': '장갑',
        'titleEn': 'Gloves',
        'descKo': '손가락 분리까지 · 7단계 상세 가이드',
        'descEn': 'Finger separation · 7-step detailed guide',
        'iconName': 'back_hand',
        'colorHex': '#FB923C',
        'order': 4,
        'isActive': true,
        'stepsKo': [
          '코잡기',
          '손목 리브',
          '손등 & 손바닥 뜨기',
          '엄지 분리',
          '손가락 분리',
          '손가락 완성',
          '엄지 완성',
        ],
        'stepsEn': [
          '코잡기',
          '손목 리브',
          '손등 & 손바닥 뜨기',
          '엄지 분리',
          '손가락 분리',
          '손가락 완성',
          '엄지 완성',
        ],
        'stepNotesKo': [
          '손목 둘레 측정. 일반적으로 36~48코. 2×2 리브 시작.',
          '2×2 또는 1×1 리브 5~7cm. 탄성 중요. 약 24~32단.',
          '메리야스뜨기로 손허리까지. 엄지 가싯 준비 마커 설치.',
          '엄지 가싯: 2단마다 2코 증가. 엄지 코 여분 실에 옮기고 연결.',
          '검지부터 차례로 분리. 각 손가락 코 = 전체 코 / 4 정도.',
          '각 손가락 원하는 길이까지 뜨고 감소로 마무리. 실 당겨 닫기.',
          '여분 실에서 엄지 코 되살리기. 원형뜨기로 엄지 길이 완성.',
        ],
        'stepNotesEn': [
          '손목 둘레 측정. 일반적으로 36~48코. 2×2 리브 시작.',
          '2×2 또는 1×1 리브 5~7cm. 탄성 중요. 약 24~32단.',
          '메리야스뜨기로 손허리까지. 엄지 가싯 준비 마커 설치.',
          '엄지 가싯: 2단마다 2코 증가. 엄지 코 여분 실에 옮기고 연결.',
          '검지부터 차례로 분리. 각 손가락 코 = 전체 코 / 4 정도.',
          '각 손가락 원하는 길이까지 뜨고 감소로 마무리. 실 당겨 닫기.',
          '여분 실에서 엄지 코 되살리기. 원형뜨기로 엄지 길이 완성.',
        ],
        'stepTargetRows': [0, 28, 20, 12, 0, 16, 12],
      },
      {
        'titleKo': '모자',
        'titleEn': 'Hat',
        'descKo': '게이지 계산부터 · 5단계 크라운 완성',
        'descEn': 'From gauge to crown · 5-step guide',
        'iconName': 'face',
        'colorHex': '#BE185D',
        'order': 5,
        'isActive': true,
        'stepsKo': [
          '코잡기',
          '브림 리브',
          '크라운 뜨기',
          '크라운 감소',
          '마무리',
        ],
        'stepsEn': [
          '코잡기',
          '브림 리브',
          '크라운 뜨기',
          '크라운 감소',
          '마무리',
        ],
        'stepNotesKo': [
          '머리 둘레 측정. 성인 56~58cm. 코수 = 둘레 × 게이지. 일반 90~120코.',
          '1×1 또는 2×2 리브 3~5cm. 접어 올리는 스타일이면 2배로.',
          '메리야스뜨기로 원하는 높이까지. 총 높이에서 리브 빼고 나머지.',
          '6~8군데 균등 감소. 매 2단마다 감소. 16~12코 남을 때까지.',
          '실 꿰어 남은 코 모아 닫기. 실 정리 후 블로킹.',
        ],
        'stepNotesEn': [
          '머리 둘레 측정. 성인 56~58cm. 코수 = 둘레 × 게이지. 일반 90~120코.',
          '1×1 또는 2×2 리브 3~5cm. 접어 올리는 스타일이면 2배로.',
          '메리야스뜨기로 원하는 높이까지. 총 높이에서 리브 빼고 나머지.',
          '6~8군데 균등 감소. 매 2단마다 감소. 16~12코 남을 때까지.',
          '실 꿰어 남은 코 모아 닫기. 실 정리 후 블로킹.',
        ],
        'stepTargetRows': [0, 20, 30, 16, 0],
      },
    ];
  }

  Future<void> seedBuiltinTemplates({bool forceSeed = false}) async {
    final existing = await _builtinCol.limit(1).get();
    if (existing.docs.isNotEmpty && !forceSeed) return;

    if (forceSeed && existing.docs.isNotEmpty) {
      final allDocs = await _builtinCol.get();
      final deleteBatch = _db.batch();
      for (final doc in allDocs.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
    }

    final batch = _db.batch();
    for (final tmpl in _builtinSeedData()) {
      batch.set(_builtinCol.doc(), tmpl);
    }
    await batch.commit();
  }

  Future<void> createBuiltinTemplate(BuiltinTemplate tmpl) async {
    await _builtinCol.add(tmpl.toJson());
  }

  Future<void> updateBuiltinTemplate(BuiltinTemplate tmpl) async {
    await _builtinCol.doc(tmpl.id).update(tmpl.toJson());
  }

  Future<void> deleteBuiltinTemplate(String id) async {
    await _builtinCol.doc(id).delete();
  }
}
