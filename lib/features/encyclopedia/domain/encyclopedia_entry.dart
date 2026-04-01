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
    );
  }

  Map<String, dynamic> toJson() => {
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
      };
}
