import 'knit_symbols.dart';

/// Firestore `knit_symbols` 컬렉션의 단일 도안 기호 항목
/// 뜨개백과(encyclopedia)와 완전히 독립된 심볼 전용 컬렉션
class KnitSymbolEntry {
  final String id;
  final String name;       // 한국어 이름
  final String nameEn;     // 영문 이름
  final String abbreviation; // 약어 (e.g. K, P, YO)
  final String svgUrl;     // Firebase Storage SVG 다운로드 URL
  final String category;   // basic|decrease|increase|cable|special|lace
  final int order;
  final int spanWidth;     // 가로 병합 셀 수 (기본 1)
  final int spanHeight;    // 세로 병합 단 수 (기본 1)

  const KnitSymbolEntry({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.abbreviation,
    required this.svgUrl,
    required this.category,
    required this.order,
    this.spanWidth = 1,
    this.spanHeight = 1,
  });

  factory KnitSymbolEntry.fromFirestore(String id, Map<String, dynamic> data) {
    return KnitSymbolEntry(
      id: id,
      name: data['name'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? '',
      abbreviation: data['abbreviation'] as String? ?? '',
      svgUrl: data['svgUrl'] as String? ?? '',
      category: data['category'] as String? ?? 'basic',
      order: (data['order'] as num?)?.toInt() ?? 0,
      spanWidth: (data['spanWidth'] as num?)?.toInt() ?? 1,
      spanHeight: (data['spanHeight'] as num?)?.toInt() ?? 1,
    );
  }

  /// #685 — Hive 영속 캐시 직렬화 (Timestamp 의존성 X, 일반 Map only)
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'nameEn': nameEn,
        'abbreviation': abbreviation,
        'svgUrl': svgUrl,
        'category': category,
        'order': order,
        'spanWidth': spanWidth,
        'spanHeight': spanHeight,
      };

  /// #685 — Hive 캐시 복원용. Firestore Timestamp 없이 일반 Map 입력.
  factory KnitSymbolEntry.fromJson(Map<String, dynamic> json) {
    return KnitSymbolEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameEn: json['nameEn'] as String? ?? '',
      abbreviation: json['abbreviation'] as String? ?? '',
      svgUrl: json['svgUrl'] as String? ?? '',
      category: json['category'] as String? ?? 'basic',
      order: (json['order'] as num?)?.toInt() ?? 0,
      spanWidth: (json['spanWidth'] as num?)?.toInt() ?? 1,
      spanHeight: (json['spanHeight'] as num?)?.toInt() ?? 1,
    );
  }

  /// 도안 셀에 저장되는 symbolId (abbreviation 기반 key)
  String get symbolId => abbreviation.toLowerCase().replaceAll(' ', '_');

  SymbolCategory get symbolCategory {
    switch (category.toLowerCase()) {
      case 'decrease': return SymbolCategory.decrease;
      case 'increase': return SymbolCategory.increase;
      case 'cable':    return SymbolCategory.cable;
      case 'special':  return SymbolCategory.special;
      case 'lace':     return SymbolCategory.lace;
      default:         return SymbolCategory.basic;
    }
  }
}
