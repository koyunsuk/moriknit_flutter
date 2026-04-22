// lib/features/pattern/domain/pattern_session.dart
//
// 도안 뷰어 세션 상태 — Firestore `users/{uid}/pattern_sessions/{sessionId}`
// 에 저장되며, 자 위치 / 스티키노트 / 형광펜 / 프로젝트·스와치 연결 정보를 담습니다.
//
// freezed 대신 일반 dart class + toJson/fromJson 직접 구현 — 빌드러너 실행 불가 환경 대응.

import 'package:cloud_firestore/cloud_firestore.dart';

class PatternSession {
  final String id;
  final String uid;
  final String patternChartId;
  final String? projectId;
  final String? swatchId;
  final double rulerY;
  final List<StickyNote> stickyNotes;
  final List<StrokeData> strokes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PatternSession({
    required this.id,
    required this.uid,
    required this.patternChartId,
    this.projectId,
    this.swatchId,
    this.rulerY = 200.0,
    this.stickyNotes = const [],
    this.strokes = const [],
    this.createdAt,
    this.updatedAt,
  });

  PatternSession copyWith({
    String? id,
    String? uid,
    String? patternChartId,
    String? projectId,
    String? swatchId,
    double? rulerY,
    List<StickyNote>? stickyNotes,
    List<StrokeData>? strokes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearProjectId = false,
    bool clearSwatchId = false,
  }) {
    return PatternSession(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      patternChartId: patternChartId ?? this.patternChartId,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      swatchId: clearSwatchId ? null : (swatchId ?? this.swatchId),
      rulerY: rulerY ?? this.rulerY,
      stickyNotes: stickyNotes ?? this.stickyNotes,
      strokes: strokes ?? this.strokes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'patternChartId': patternChartId,
        'projectId': projectId,
        'swatchId': swatchId,
        'rulerY': rulerY,
        'stickyNotes': stickyNotes.map((e) => e.toJson()).toList(),
        'strokes': strokes.map((e) => e.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory PatternSession.fromJson(Map<String, dynamic> json) {
    return PatternSession(
      id: (json['id'] ?? '') as String,
      uid: (json['uid'] ?? '') as String,
      patternChartId: (json['patternChartId'] ?? '') as String,
      projectId: json['projectId'] as String?,
      swatchId: json['swatchId'] as String?,
      rulerY: (json['rulerY'] as num?)?.toDouble() ?? 200.0,
      stickyNotes: (json['stickyNotes'] as List?)
              ?.map((e) => StickyNote.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      strokes: (json['strokes'] as List?)
              ?.map((e) => StrokeData.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  factory PatternSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PatternSession.fromJson({...data, 'id': doc.id});
  }

  factory PatternSession.empty({required String uid, required String patternChartId}) {
    return PatternSession(
      id: '',
      uid: uid,
      patternChartId: patternChartId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

class StickyNote {
  final String id;
  final String text;
  final double x;
  final double y;

  const StickyNote({
    required this.id,
    this.text = '',
    this.x = 20.0,
    this.y = 120.0,
  });

  StickyNote copyWith({String? id, String? text, double? x, double? y}) =>
      StickyNote(
        id: id ?? this.id,
        text: text ?? this.text,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
      };

  factory StickyNote.fromJson(Map<String, dynamic> json) => StickyNote(
        id: (json['id'] ?? '') as String,
        text: (json['text'] ?? '') as String,
        x: (json['x'] as num?)?.toDouble() ?? 20.0,
        y: (json['y'] as num?)?.toDouble() ?? 120.0,
      );
}

class StrokeData {
  final List<double> xs;
  final List<double> ys;
  final int colorValue;

  const StrokeData({
    required this.xs,
    required this.ys,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
        'xs': xs,
        'ys': ys,
        'colorValue': colorValue,
      };

  factory StrokeData.fromJson(Map<String, dynamic> json) => StrokeData(
        xs: (json['xs'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            const [],
        ys: (json['ys'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            const [],
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0x66FFFF00,
      );
}
