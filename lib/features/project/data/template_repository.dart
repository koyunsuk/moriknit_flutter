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
    String photoUrl = '',
  }) async {
    if (_uid.isEmpty) return;
    await _col.add({
      'title': title,
      'description': description,
      'stepTitles': stepTitles,
      'stepDescs': stepDescs,
      'photoUrl': photoUrl,
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
    String photoUrl = '',
  }) async {
    if (_uid.isEmpty) return;
    await _col.doc(id).update({
      'title': title,
      'description': description,
      'stepTitles': stepTitles,
      'stepDescs': stepDescs,
      'photoUrl': photoUrl,
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
      // #637 — 크롭 레글런 탑다운 (Banul 메리노블렌드 DK 기반 12단계)
      {
        'titleKo': '크롭 레글런 탑다운',
        'titleEn': 'Crop Raglan Top-Down',
        'descKo': 'Banul 도안 기반 · 12단계 · 7사이즈 지원 (XS~3XL)',
        'descEn': 'Banul-based · 12 steps · 7 sizes (XS~3XL)',
        'iconName': 'checkroom',
        'colorHex': '#DB2777',
        'order': 6,
        'isActive': true,
        'stepsKo': [
          '목둘레 코잡기',
          '목 고무단 (6cm)',
          '앞목 쉐이핑 & 래글런 늘림 1 (11단)',
          '래글런 늘림 2 (반복)',
          'XL+ 몸통 추가단',
          '소매 분리 & 겨드랑이 감아코',
          '몸통 메리야스 뜨기',
          '몸통 코줄임 (1단)',
          '몸통 고무단 (7cm)',
          '소매 뜨기',
          '소매 길이 완성',
          '소매 고무단 & 마무리',
        ],
        'stepsEn': [
          'Cast-on (Neck)',
          'Neck Ribbing (6cm)',
          'Front Shaping & Raglan Increase 1 (11 rnds)',
          'Raglan Increase 2 (Repeat)',
          'XL+ Body Extra Rounds',
          'Sleeve Separation & Underarm CO',
          'Body Stockinette',
          'Body Decrease (1 rnd)',
          'Body Ribbing (7cm)',
          'Sleeve Knitting',
          'Sleeve Length Complete',
          'Sleeve Ribbing & Finishing',
        ],
        'stepNotesKo': [
          '3.5mm 바늘 + 40cm 케이블. 사이즈별 원통 코잡기 — XS:92, S:96, M:104, L:108, XL/2XL/3XL:112코. 시작 마커 설치.',
          '1코 고무뜨기로 약 17단. 겹단 처리 후 4mm로 바늘 교체.',
          '셋업단: 마커 9개 배치. 독일식 짧은단 턴(German short row) 포함. 모든 사이즈 동일하게 11단.',
          '1단 늘림단(M1R×4, M1L×4 = +8코) + 2단 유지 반복. 사이즈별 반복: XS 23 · S 25 · M 26 · L 28 · XL 29 · 2XL 30 · 3XL 32회.',
          '몸통쪽 앞뒤판에만 +4코. XL 1회, 2XL·3XL 2회 반복. (XS/S/M/L은 건너뜀)',
          '소매 코를 자투리 실로 옮겨 쉬게 함. 겨드랑이 감아코 — XS/S:4, M/L:6, XL:8, 2XL:10, 3XL:12코.',
          '원통 메리야스. 단수표시링부터 사이즈별 — XS:35, S:37, M:39, L:41, XL:42, 2XL:43, 3XL:44cm까지.',
          '[k2tog, 겉뜨기 N코] × M번 + k2tog. 사이즈별 — XS:[K2tog,9]×17, S:[K2tog,10]×17, M:[K2tog,9]×19, L:[K2tog,10]×19.',
          '3.5mm로 바꿔 1코 고무뜨기. 다 뜨면 돗바늘 코막음으로 마무리.',
          '쉬어둔 소매 코 + 겨드랑이 감아코 절반씩 줍기. 원통 메리야스. 사이즈별 간격 k2tog/ssk 코줄임.',
          '소매 분리 지점부터 사이즈별 — XS:38, S/M:39, L/XL:40, 2XL:39, 3XL:38cm까지 뜨기.',
          '3.5mm 1코 고무뜨기 7cm + 돗바늘 코막음. 꼬리실 정리 + 겨드랑이 구멍 봉합.',
        ],
        'stepNotesEn': [
          '3.5mm needle + 40cm cable. Cast on by size — XS:92, S:96, M:104, L:108, XL+/2XL/3XL:112 sts. Place start marker.',
          '1x1 rib ~17 rnds. After hem fold, switch to 4mm needles.',
          'Setup round: 9 markers, German short rows included. 11 rnds for all sizes.',
          '1 increase rnd (M1R×4, M1L×4 = +8) + 2 plain rnds. Reps by size: XS 23 · S 25 · M 26 · L 28 · XL 29 · 2XL 30 · 3XL 32.',
          'Body front/back only +4 sts. XL ×1, 2XL·3XL ×2. (Skip for XS/S/M/L)',
          'Transfer sleeve sts to scrap yarn. Underarm CO — XS/S:4, M/L:6, XL:8, 2XL:10, 3XL:12 sts.',
          'Stockinette in round. From marker — XS:35, S:37, M:39, L:41, XL:42, 2XL:43, 3XL:44cm.',
          '[k2tog, knit N] × M + k2tog. By size — XS:[K2tog,9]×17, S:[K2tog,10]×17, M:[K2tog,9]×19, L:[K2tog,10]×19.',
          'Switch to 3.5mm, 1x1 rib. Bind off with tapestry needle.',
          'Pick up sleeve sts + half underarm CO. Stockinette in round. K2tog/ssk decreases at size-specific intervals.',
          'From sleeve separation — XS:38, S/M:39, L/XL:40, 2XL:39, 3XL:38cm.',
          '3.5mm 1x1 rib 7cm + tapestry bind off. Weave in ends + close underarm holes.',
        ],
        'stepTargetRows': [0, 17, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      },
    ];
  }

  /// #637 — 크롭 레글런 탑다운이 Firestore에 누락된 경우 자동 추가
  /// 기존 seed된 환경에서도 자동으로 새 프리셋 노출되도록 보장
  Future<void> ensureCropRaglanSeeded() async {
    final existing = await _builtinCol
        .where('titleKo', isEqualTo: '크롭 레글런 탑다운')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;
    final cropRaglan = _builtinSeedData().lastWhere(
      (t) => t['titleKo'] == '크롭 레글런 탑다운',
    );
    await _builtinCol.add(cropRaglan);
  }

  /// #639 — 인형 치수 프리셋을 BuiltinTemplate(kind=bodyMeasurement)으로 통합
  /// 사용자 철학: 프리셋=템플릿=동일한 자원.
  /// 기존 환경에서도 자동 노출되도록 누락 시 seed.
  Future<void> ensureDollPresetsSeeded() async {
    final existing = await _builtinCol
        .where('kind', isEqualTo: 'body_measurement')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final doll in _dollPresetSeedData()) {
      batch.set(_builtinCol.doc(), doll);
    }
    await batch.commit();
  }

  /// 인형 치수 프리셋 seed 데이터 (doll_presets.dart 값 기반)
  static List<Map<String, dynamic>> _dollPresetSeedData() {
    return [
      {
        'kind': 'body_measurement',
        'titleKo': '바비 인형',
        'titleEn': 'Barbie',
        'descKo': '29.21cm · 패션 인형 대표 (가슴 13.46cm)',
        'descEn': '29.21cm · Classic fashion doll (chest 13.46cm)',
        'iconName': 'face_retouching_natural',
        'colorHex': '#EC4899',
        'order': 100,
        'isActive': true,
        'stepsKo': ['가슴둘레', '목둘레', '상체 길이', '소매 길이', '상완', '손목', '어깨', '진동 깊이'],
        'stepsEn': ['Chest', 'Neck', 'Body Length', 'Sleeve Length', 'Upper Arm', 'Wrist', 'Shoulder', 'Armhole Depth'],
        'stepNotesKo': ['13.46cm', '6.0cm', '10cm', '7cm', '4cm', '2.5cm', '6cm', '2.5cm'],
        'stepNotesEn': ['13.46cm', '6.0cm', '10cm', '7cm', '4cm', '2.5cm', '6cm', '2.5cm'],
        'stepTargetRows': [0, 0, 0, 0, 0, 0, 0, 0],
        'measurementData': {
          'dollId': 'barbie',
          'heightCm': 29.21,
          'measurement': {
            'chestCm': 13.46, 'neckCm': 6.0, 'bodyLengthCm': 10, 'sleeveLengthCm': 7,
            'upperArmCm': 4, 'wristCm': 2.5, 'shoulderCm': 6, 'armholeDepthCm': 2.5,
          },
          'suggestedGauge': {'stitchesPer10cm': 36, 'rowsPer10cm': 44},
          'suggestedEase': 'doll',
          'suggestedYarn': '3ply 코튼 또는 아크릴 레이스사',
          'suggestedNeedle': '2.0~2.5mm',
        },
      },
      {
        'kind': 'body_measurement',
        'titleKo': '태미의 작은 동생 (1963)',
        'titleEn': "Tammy's Little Sister",
        'descKo': '29.2cm (11.5") · 빈티지 비율 · 가슴 13.5cm',
        'descEn': '29.2cm (11.5") · Vintage proportion · chest 13.5cm',
        'iconName': 'child_care',
        'colorHex': '#DB2777',
        'order': 101,
        'isActive': true,
        'stepsKo': ['가슴둘레', '목둘레', '상체 길이', '소매 길이', '상완', '손목', '어깨', '진동 깊이'],
        'stepsEn': ['Chest', 'Neck', 'Body Length', 'Sleeve Length', 'Upper Arm', 'Wrist', 'Shoulder', 'Armhole Depth'],
        'stepNotesKo': ['13.5cm', '6.5cm', '8cm', '7.7cm', '4.8cm', '3cm', '2.5cm', '2.9cm'],
        'stepNotesEn': ['13.5cm', '6.5cm', '8cm', '7.7cm', '4.8cm', '3cm', '2.5cm', '2.9cm'],
        'stepTargetRows': [0, 0, 0, 0, 0, 0, 0, 0],
        'measurementData': {
          'dollId': 'tammy',
          'heightCm': 29.2,
          'measurement': {
            'chestCm': 13.5, 'neckCm': 6.5, 'bodyLengthCm': 8, 'sleeveLengthCm': 7.7,
            'upperArmCm': 4.8, 'wristCm': 3, 'shoulderCm': 2.5, 'armholeDepthCm': 2.9,
          },
          'suggestedGauge': {'stitchesPer10cm': 40, 'rowsPer10cm': 50},
          'suggestedEase': 'doll',
          'suggestedYarn': 'vincent 3ply 또는 유사한 초극세사',
          'suggestedNeedle': 'US0 (2.0mm) 4개 DPN',
        },
      },
      {
        'kind': 'body_measurement',
        'titleKo': '파올라 레이나',
        'titleEn': 'Paola Reina',
        'descKo': '33.7cm · 아동 체형 초심자용 (가슴 15.5cm)',
        'descEn': '33.7cm · Child proportion for beginners (chest 15.5cm)',
        'iconName': 'child_friendly',
        'colorHex': '#F472B6',
        'order': 102,
        'isActive': true,
        'stepsKo': ['가슴둘레', '목둘레', '상체 길이', '소매 길이', '상완', '손목', '어깨', '진동 깊이'],
        'stepsEn': ['Chest', 'Neck', 'Body Length', 'Sleeve Length', 'Upper Arm', 'Wrist', 'Shoulder', 'Armhole Depth'],
        'stepNotesKo': ['15.5cm', '8cm', '15cm', '8.5cm', '5.5cm', '3.5cm', '7cm', '3.5cm'],
        'stepNotesEn': ['15.5cm', '8cm', '15cm', '8.5cm', '5.5cm', '3.5cm', '7cm', '3.5cm'],
        'stepTargetRows': [0, 0, 0, 0, 0, 0, 0, 0],
        'measurementData': {
          'dollId': 'paola_reina',
          'heightCm': 33.7,
          'measurement': {
            'chestCm': 15.5, 'neckCm': 8, 'bodyLengthCm': 15, 'sleeveLengthCm': 8.5,
            'upperArmCm': 5.5, 'wristCm': 3.5, 'shoulderCm': 7, 'armholeDepthCm': 3.5,
          },
          'suggestedGauge': {'stitchesPer10cm': 32, 'rowsPer10cm': 40},
          'suggestedEase': 'doll',
          'suggestedYarn': '3~4ply 코튼 · 메리노 블렌드',
          'suggestedNeedle': '2.5~3.0mm',
        },
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
