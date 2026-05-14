import 'package:cloud_firestore/cloud_firestore.dart';

class EncyclopediaEntry {
  final String id;
  final String term;
  final String termEn;
  final String termJa;
  final String abbreviation;
  final String category;
  final String description;
  final String descriptionEn;
  final String descriptionJa;
  final List<String> aliases;
  final String symbol;
  final String referenceUrl;
  final String videoUrl;
  final String status;
  final String createdBy;
  final String approvedBy;
  final int order;
  final DateTime createdAt;
  final String craftType;

  const EncyclopediaEntry({
    required this.id,
    required this.term,
    this.termEn = '',
    this.termJa = '',
    this.abbreviation = '',
    required this.category,
    required this.description,
    this.descriptionEn = '',
    this.descriptionJa = '',
    this.aliases = const [],
    this.symbol = '',
    this.referenceUrl = '',
    this.videoUrl = '',
    this.status = 'approved',
    this.createdBy = '',
    this.approvedBy = '',
    this.order = 0,
    required this.createdAt,
    this.craftType = 'knitting',
  });

  factory EncyclopediaEntry.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return EncyclopediaEntry(
      id: doc.id,
      term: data['term'] as String? ?? '',
      termEn: data['termEn'] as String? ?? '',
      termJa: data['termJa'] as String? ?? '',
      abbreviation: data['abbreviation'] as String? ?? '',
      category: data['category'] as String? ?? 'term',
      description: data['description'] as String? ?? '',
      descriptionEn: data['descriptionEn'] as String? ?? '',
      descriptionJa: data['descriptionJa'] as String? ?? '',
      aliases: List<String>.from(data['aliases'] as List? ?? const <String>[]),
      symbol: data['symbol'] as String? ?? '',
      referenceUrl: data['referenceUrl'] as String? ?? '',
      videoUrl: data['videoUrl'] as String? ?? '',
      status: data['status'] as String? ?? 'approved',
      createdBy: data['createdBy'] as String? ?? '',
      approvedBy: data['approvedBy'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      craftType: data['craftType'] as String? ?? 'knitting',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'term': term,
        'termEn': termEn,
        'termJa': termJa,
        'abbreviation': abbreviation,
        'category': category,
        'description': description,
        'descriptionEn': descriptionEn,
        'descriptionJa': descriptionJa,
        'aliases': aliases,
        'symbol': symbol,
        'referenceUrl': referenceUrl,
        'videoUrl': videoUrl,
        'status': status,
        'createdBy': createdBy,
        'approvedBy': approvedBy,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'craftType': craftType,
      };

  /// 로컬 캐시(Hive 등) 복원용 — Firestore Timestamp 의존성 없음.
  /// id는 json['id'] 우선, 없으면 빈 문자열.
  factory EncyclopediaEntry.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    DateTime parsedCreatedAt;
    if (createdAtRaw is String) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else if (createdAtRaw is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    } else if (createdAtRaw is DateTime) {
      parsedCreatedAt = createdAtRaw;
    } else {
      parsedCreatedAt = DateTime.now();
    }
    return EncyclopediaEntry(
      id: json['id'] as String? ?? '',
      term: json['term'] as String? ?? '',
      termEn: json['termEn'] as String? ?? '',
      termJa: json['termJa'] as String? ?? '',
      abbreviation: json['abbreviation'] as String? ?? '',
      category: json['category'] as String? ?? 'term',
      description: json['description'] as String? ?? '',
      descriptionEn: json['descriptionEn'] as String? ?? '',
      descriptionJa: json['descriptionJa'] as String? ?? '',
      aliases: List<String>.from(json['aliases'] as List? ?? const <String>[]),
      symbol: json['symbol'] as String? ?? '',
      referenceUrl: json['referenceUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'approved',
      createdBy: json['createdBy'] as String? ?? '',
      approvedBy: json['approvedBy'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: parsedCreatedAt,
      craftType: json['craftType'] as String? ?? 'knitting',
    );
  }
}
