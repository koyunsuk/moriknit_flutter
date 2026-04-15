import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../pattern/data/pattern_repository.dart';
import '../../pattern/domain/pattern_chart.dart';
import '../domain/parsed_pattern.dart';

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
  Future<PatternChart> uploadAndParse({
    required File file,
    required String fileName,
    required String mimeType,
    void Function(double)? onProgress,
  }) async {
    // 1. Firebase Storage 업로드
    final storagePath = 'users/$_uid/pattern_sources/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref(storagePath);
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: mimeType),
    );

    uploadTask.snapshotEvents.listen((snap) {
      final progress = snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes);
      onProgress?.call(progress * 0.5); // 50%까지는 업로드
    });

    await uploadTask;
    onProgress?.call(0.5);

    // 2. Cloud Function 호출 (파싱)
    final callable = _functions.httpsCallable('parseKnittingPattern');
    final result = await callable.call({
      'storagePath': storagePath,
      'mimeType': mimeType,
      'fileName': fileName,
    });
    onProgress?.call(0.9);

    final data = Map<String, dynamic>.from(result.data['result'] as Map);

    // 3. AI 섹션 데이터 변환
    final rawSections = (data['sections'] as List?) ?? [];
    final aiSections = rawSections
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();

    // 4. PatternChart로 pattern_charts 컬렉션에 저장
    // 이미지 파일은 PatternType.image, PDF는 PatternType.pdf
    final patternType = mimeType.startsWith('image/') ? PatternType.image : PatternType.pdf;
    String patternImageUrl = '';
    String patternPdfUrl = '';
    if (patternType == PatternType.image) {
      patternImageUrl = await ref.getDownloadURL();
    } else {
      patternPdfUrl = storagePath;
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
    );

    final saved = await PatternRepository().save(chart);
    onProgress?.call(1.0);
    return saved;
  }

  /// AI 변환 도안 목록 스트림 (pattern_charts 컬렉션에서 aiConverted 타입만)
  Stream<List<PatternChart>> watchAiPatterns() {
    if (_auth.currentUser == null) return const Stream.empty();
    return _chartsCol
        .where('sourceType', isEqualTo: 'aiConverted')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              if ((data['id'] as String?)?.isEmpty != false) data['id'] = d.id;
              return PatternChart.fromJson(data);
            }).toList());
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
      if (sec['id'] != sectionId) return sec;
      final steps = (sec['steps'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
      final updatedSteps = steps.map((step) {
        if (step['id'] != stepId) return step;
        return {...step, 'isCompleted': isCompleted};
      }).toList();
      return {...sec, 'steps': updatedSteps};
    }).toList();

    await _chartsCol.doc(patternId).update({'aiSections': updatedSections});
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
