// 이슈 #723 — 스와치 그룹 도메인 모델.
//
// 사용자가 직접 만든 스와치 묶음 (실/바늘/프로젝트 등 자유 기준).
// 카운터 그룹(프로젝트별 자동 묶음)과 달리, 사용자 정의 묶음 단위.
//
// 저장 경로: users/{uid}/swatch_groups/{gid}
// 스와치 자체는 건드리지 않고, 그룹 안에 swatchIds 만 보관.

import 'package:cloud_firestore/cloud_firestore.dart';

class SwatchGroup {
  final String id;
  final String name;
  final String? description;
  final List<String> swatchIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SwatchGroup({
    required this.id,
    required this.name,
    this.description,
    this.swatchIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  SwatchGroup copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? swatchIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SwatchGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      swatchIds: swatchIds ?? this.swatchIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'swatchIds': swatchIds,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  factory SwatchGroup.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return SwatchGroup(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      description: json['description'] as String?,
      swatchIds: (json['swatchIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  factory SwatchGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SwatchGroup.fromJson({...data, 'id': doc.id});
  }

  factory SwatchGroup.empty({String name = ''}) {
    final now = DateTime.now();
    return SwatchGroup(
      id: '',
      name: name,
      swatchIds: const [],
      createdAt: now,
      updatedAt: now,
    );
  }
}
