
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../pattern/domain/ai_pattern_section.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../domain/parsed_pattern.dart';
import 'pdf_thumbnail_extractor.dart';

class PatternConverterRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _functions = FirebaseFunctions.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _parsedCol =>
      _db.collection('users').doc(_uid).collection('parsed_patterns');

  CollectionReference<Map<String, dynamic>> get _chartsCol =>
      _db.collection('users').doc(_uid).collection('pattern_charts');

  /// 파일을 Storage에 업로드 후 Cloud Function으로 파싱, pattern_charts에 저장
  /// 이슈 #644 — [ravelryPatternId] 전달 시 변환된 PatternChart에 매핑됨 (Ravelry 임포트 도안용)
  Future<PatternChart> uploadAndParse({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    void Function(double)? onProgress,
    bool translateToKorean = false,
    int? ravelryPatternId,
  }) async {
    // 1. Firebase Storage 업로드
    final storagePath = 'users/$_uid/pattern_sources/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref(storagePath);
    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: mimeType),
    );

    uploadTask.snapshotEvents.listen((snap) {
      final progress = snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes);
      onProgress?.call(progress * 0.5); // 50%까지는 업로드
    });

    await uploadTask;
    onProgress?.call(0.5);

    // 1-b. PDF 커버 썸네일 추출 (이슈 #641)
    //  - PDF인 경우 첫 페이지를 JPG로 렌더링 → Storage 업로드 → downloadURL 획득
    //  - 실패해도 흐름 계속 (coverUrl = null → 기존 동작 유지)
    //  - 진행률: 0.5 → 0.6
    String? coverUrl;
    if (mimeType == 'application/pdf') {
      final thumbBytes =
          await PdfThumbnailExtractor.extractFirstPageThumbnail(bytes);
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        try {
          final coverPath =
              'users/$_uid/pattern_sources/${DateTime.now().millisecondsSinceEpoch}_cover.jpg';
          final coverRef = _storage.ref(coverPath);
          await coverRef.putData(
            thumbBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          coverUrl = await coverRef.getDownloadURL();
        } catch (_) {
          // 커버 업로드 실패는 치명적이지 않음 — fallback
          coverUrl = null;
        }
      }
    }
    onProgress?.call(0.6);

    // 2. Cloud Function 호출 (파싱) — 서버 타임아웃(120s)보다 여유 있게 설정
    final callable = _functions.httpsCallable(
      'parseKnittingPattern',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 280)),
    );
    final payload = {
      'storagePath': storagePath,
      'mimeType': mimeType,
      'fileName': fileName,
      if (translateToKorean) 'translateLanguage': 'ko',
    };
    final result = await callable.call(payload);
    onProgress?.call(0.9);

    final data = Map<String, dynamic>.from(result.data['result'] as Map);

    // 3. AI 섹션 데이터 변환
    final rawSections = (data['sections'] as List?) ?? [];
    final aiSections = rawSections
        .map((s) => AiSection.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList();

    // 4. PatternChart 생성 (저장 없이 반환 — 저장은 AiPatternEditScreen에서 수행)
    final patternType = mimeType.startsWith('image/') ? PatternType.image : PatternType.pdf;
    String patternImageUrl = '';
    String patternPdfUrl = '';
    if (patternType == PatternType.image) {
      patternImageUrl = await ref.getDownloadURL();
    } else {
      patternPdfUrl = storagePath;
      // PDF인 경우 추출된 커버가 있으면 imageUrl로 설정 (라이브러리 카드 표시용)
      if (coverUrl != null && coverUrl.isNotEmpty) {
        patternImageUrl = coverUrl;
      }
    }

    final chart = PatternChart(
      id: '',
      title: data['title'] as String? ?? fileName,
      rows: 0,
      cols: 0,
      mode: ChartMode.symbol,
      grid: const [],
      narrativeText: '',
      type: patternType,
      sourceType: PatternSourceType.aiConverted,
      pdfUrl: patternPdfUrl,
      imageUrl: patternImageUrl,
      aiSections: aiSections,
      ravelryPatternId: ravelryPatternId,
    );

    onProgress?.call(1.0);
    return chart;
  }

  /// AI 변환 도안 목록 스트림 (pattern_charts 컬렉션에서 aiConverted 타입만)
  /// 이슈 #722 — Stream.empty()는 emit 안 됨(무한로딩). Stream.value([])로 교체.
  /// 이슈 #724 — 옛 도안에 sourceType 필드 누락 시 쿼리에서 누락되는 회귀 수정.
  /// 전체 chart 가져온 뒤 클라이언트에서 aiConverted/sourceType-null 필터링.
  /// 색인 의존 X, parse 실패 doc은 건너뛰어 raw 에러 전파 차단.
  Stream<List<PatternChart>> watchAiPatterns() {
    if (_auth.currentUser == null) return Stream.value(<PatternChart>[]);
    return _chartsCol
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
      final result = <PatternChart>[];
      for (final d in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(d.data());
          if ((data['id'] as String?)?.isEmpty != false) data['id'] = d.id;
          final src = data['sourceType'] as String?;
          // aiConverted 또는 sourceType 미지정(옛 도안) 둘 다 표시.
          // 명시적으로 다른 type(예: drawn)이면 제외.
          if (src != null && src != 'aiConverted') continue;
          result.add(PatternChart.fromJson(data));
        } catch (_) {
          // 단일 doc parse 실패는 무음 — 전체 스트림 깨뜨리지 않음.
          continue;
        }
      }
      return result;
    });
  }

  /// 단일 AI 변환 도안 스트림 (pattern_charts 기반)
  Stream<PatternChart?> watchAiPattern(String patternId) {
    return _chartsCol.doc(patternId).snapshots().map((d) {
      if (!d.exists) return null;
      final data = Map<String, dynamic>.from(d.data()!);
      if ((data['id'] as String?)?.isEmpty != false) data['id'] = d.id;
      return PatternChart.fromJson(data);
    });
  }

  /// 도안 doc → PatternChart 디코딩 공통 헬퍼.
  /// 손상 필드 등으로 fromJson이 실패하면 null 반환 (무한로딩/raw 노출 회피).
  PatternChart? _decodeChart(DocumentSnapshot<Map<String, dynamic>> d) {
    try {
      if (!d.exists) return null;
      final data = Map<String, dynamic>.from(d.data()!);
      if ((data['id'] as String?)?.isEmpty != false) data['id'] = d.id;
      return PatternChart.fromJson(data);
    } catch (e, st) {
      debugPrint('[_decodeChart] fromJson FAILED: $e\n$st');
      return null;
    }
  }

  /// 백그라운드 서버 갱신 trigger — UI는 캐시로 진행, 서버 결과는 캐시에 반영.
  Future<void> _refreshFromServer(String patternId) async {
    try {
      await _chartsCol
          .doc(patternId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // 백그라운드 실패 무음
    }
  }

  /// #655 무한로딩 fix → #685 Phase 3: Firestore SDK 자체 캐시(Source.cache)
  /// 우선 fetch, 미스 시 서버 fetch(5s timeout), 실패 시 null.
  /// raw exception은 절대 rethrow하지 않음 — 호출부에서 친화 메시지 처리.
  Future<PatternChart?> getAiPattern(String patternId) async {
    debugPrint('[getAiPattern] start id=$patternId');

    // 1) Source.cache 우선 (Firestore SDK 영속 캐시)
    try {
      final cached = await _chartsCol
          .doc(patternId)
          .get(const GetOptions(source: Source.cache));
      if (cached.exists) {
        debugPrint('[getAiPattern] HIT cache for $patternId');
        // 백그라운드로 서버 갱신 trigger (UI는 캐시로 진행)
        unawaited(_refreshFromServer(patternId));
        return _decodeChart(cached);
      }
    } catch (_) {
      // 캐시 없음 — 정상. server 폴백으로 진행
    }

    // 2) 서버 fetch — 5초 타임아웃, 실패 시 null
    try {
      final d = await _chartsCol
          .doc(patternId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      debugPrint('[getAiPattern] server fetch exists=${d.exists}');
      if (!d.exists) return null;
      return _decodeChart(d);
    } on TimeoutException {
      debugPrint('[getAiPattern] TIMEOUT after 5s → null');
      return null;
    } catch (e, st) {
      debugPrint('[getAiPattern] EXCEPTION (swallowed): $e\n$st');
      return null;
    }
  }

  /// 단계 완료 상태 토글 저장 (pattern_charts 기반)
  Future<void> toggleStep({
    required String patternId,
    required String sectionId,
    required String stepId,
    required bool isCompleted,
  }) async {
    final doc = await _chartsCol.doc(patternId).get();
    if (!doc.exists) return;
    final data = Map<String, dynamic>.from(doc.data()!);
    if ((data['id'] as String?)?.isEmpty != false) data['id'] = doc.id;
    final chart = PatternChart.fromJson(data);

    final sections = chart.aiSections ?? [];
    final updatedSections = sections.map((sec) {
      if (sec.id != sectionId) return sec;
      final updatedSteps = sec.steps.map((step) {
        if (step.id != stepId) return step;
        return step.copyWith(isCompleted: isCompleted);
      }).toList();
      return sec.copyWith(steps: updatedSteps);
    }).toList();

    await _chartsCol.doc(patternId).update({
      'aiSections': updatedSections.map((s) => s.toMap()).toList(),
    });
  }

  /// AI 변환 도안 섹션 업데이트
  Future<void> updateSections(String patternId, List<AiSection> sections) async {
    await _chartsCol.doc(patternId).update({
      'aiSections': sections.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// AI 변환 도안 삭제 (pattern_charts 기반)
  Future<void> deleteAiPattern(String patternId) async {
    final doc = await _chartsCol.doc(patternId).get();
    if (!doc.exists) return;
    final data = Map<String, dynamic>.from(doc.data()!);
    if ((data['id'] as String?)?.isEmpty != false) data['id'] = doc.id;
    final chart = PatternChart.fromJson(data);

    // Storage 파일도 삭제
    if (chart.pdfUrl.isNotEmpty) {
      try {
        await _storage.ref(chart.pdfUrl).delete();
      } catch (_) {}
    }
    await _chartsCol.doc(patternId).delete();
  }

  // ─── 구버전 parsed_patterns 호환 메서드 (레거시 지원) ──────────────

  /// 단일 도안 스트림 (구버전 parsed_patterns 기반)
  Stream<ParsedPattern?> watchPattern(String patternId) {
    return _parsedCol.doc(patternId).snapshots().map((d) {
      if (!d.exists) return null;
      return ParsedPattern.fromFirestore(d.id, d.data()!);
    });
  }

  /// 도안 삭제 (구버전 parsed_patterns 기반)
  Future<void> deletePattern(String patternId) async {
    final doc = await _parsedCol.doc(patternId).get();
    if (!doc.exists) return;
    final pattern = ParsedPattern.fromFirestore(doc.id, doc.data()!);

    if (pattern.storageUrl.isNotEmpty) {
      try {
        await _storage.ref(pattern.storageUrl).delete();
      } catch (_) {}
    }
    await _parsedCol.doc(patternId).delete();
  }
}

