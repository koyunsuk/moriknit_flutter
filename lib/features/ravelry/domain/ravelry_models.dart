int _readInt(Map<String, dynamic> json, List<String> keys, [int fallback = 0]) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

double? _readDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

Map<String, dynamic>? _readMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
  }
  return null;
}

List<dynamic>? _readList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List<dynamic>) return value;
  }
  return null;
}

String? _photoUrlFrom(dynamic source) {
  if (source is! Map<String, dynamic>) return null;
  final photos = _readList(source, ['photos', 'project_photos', 'pattern_photos']);
  if (photos != null && photos.isNotEmpty) {
    final first = photos.first;
    if (first is Map<String, dynamic>) {
      return _readString(first, [
        'medium_url',
        'small_url',
        'thumbnail_url',
        'square_url',
        'sort_order_photo_url',
      ]);
    }
  }

  final firstPhoto = _readMap(source, ['first_photo', 'photo']);
  if (firstPhoto != null) {
    return _readString(firstPhoto, [
      'medium_url',
      'small_url',
      'thumbnail_url',
      'square_url',
    ]);
  }

  return _readString(source, [
    'photo_url',
    'thumbnail_url',
    'small_photo_url',
    'medium_photo_url',
  ]);
}

class RavelryStashEntry {
  final int id;
  final String name;
  final String? yarnName;
  final String? colorName;
  final String? brandName;
  final double? gramsTotal;
  final double? yardsTotal;
  final String? weightName;
  final String? thumbnailUrl;
  final String? notes;
  final DateTime? updatedAt;

  const RavelryStashEntry({
    required this.id,
    required this.name,
    this.yarnName,
    this.colorName,
    this.brandName,
    this.gramsTotal,
    this.yardsTotal,
    this.weightName,
    this.thumbnailUrl,
    this.notes,
    this.updatedAt,
  });

  factory RavelryStashEntry.fromJson(Map<String, dynamic> json) {
    final yarn = _readMap(json, ['yarn']);
    final yarnWeight = yarn != null ? _readMap(yarn, ['yarn_weight', 'weight']) : null;
    final company = yarn != null ? _readMap(yarn, ['yarn_company', 'brand']) : null;

    return RavelryStashEntry(
      id: _readInt(json, ['id', 'stash_id']),
      name: _readString(json, ['name', 'yarn_name', 'display_name']) ??
          _readString(yarn ?? const {}, ['name', 'yarn_name']) ??
          'Untitled stash yarn',
      yarnName: _readString(yarn ?? const {}, ['name', 'yarn_name']) ??
          _readString(json, ['yarn_name']),
      colorName: _readString(json, ['color_family_name', 'colorway_name', 'color']),
      brandName: _readString(company ?? const {}, ['name']) ??
          _readString(json, ['brand_name', 'yarn_company_name']),
      gramsTotal: _readDouble(json, ['grams_total', 'total_grams', 'grams']),
      yardsTotal: _readDouble(json, ['yards_total', 'total_yards', 'yardage']),
      weightName: _readString(yarnWeight ?? const {}, ['name']) ??
          _readString(json, ['weight_name']),
      thumbnailUrl: _photoUrlFrom(json) ?? _photoUrlFrom(yarn),
      notes: _readString(json, ['notes', 'note']),
      updatedAt: DateTime.tryParse(
        _readString(json, ['updated_at', 'updated_on', 'last_updated']) ?? '',
      ),
    );
  }
}

class RavelryLibraryPattern {
  final int id;
  final String name;
  final String? authorName;
  final String? thumbnailUrl;
  final bool isFree;
  final double? price;
  final double? difficultyAverage;
  final String? craft;
  final List<String> categories;
  final String? ravelryUrl;

  const RavelryLibraryPattern({
    required this.id,
    required this.name,
    this.authorName,
    this.thumbnailUrl,
    this.isFree = false,
    this.price,
    this.difficultyAverage,
    this.craft,
    this.categories = const [],
    this.ravelryUrl,
  });

  factory RavelryLibraryPattern.fromJson(Map<String, dynamic> json) {
    final pattern = _readMap(json, ['pattern', 'first_pattern']) ?? json;
    final author = _readMap(pattern, ['pattern_author', 'designer', 'author']);
    final craft = _readMap(pattern, ['craft']);
    final categoryItems = _readList(pattern, ['pattern_categories', 'categories']) ?? const [];
    final categories = categoryItems
        .whereType<Map<String, dynamic>>()
        .map((item) => _readString(item, ['name', 'label']) ?? '')
        .where((item) => item.isNotEmpty)
        .toList();

    final permalink = _readString(pattern, ['permalink']);

    return RavelryLibraryPattern(
      id: _readInt(pattern, ['id', 'pattern_id', 'queued_pattern_id']),
      name: _readString(pattern, ['name', 'pattern_name', 'title']) ??
          _readString(json, ['name', 'pattern_name', 'title']) ??
          'Untitled pattern',
      authorName: _readString(author ?? const {}, ['name', 'designer_name']) ??
          _readString(json, ['designer_name', 'author_name']),
      thumbnailUrl: _photoUrlFrom(pattern) ?? _photoUrlFrom(json),
      isFree: pattern['free'] == true || json['free'] == true,
      price: _readDouble(pattern, ['price']) ?? _readDouble(json, ['price']),
      difficultyAverage: _readDouble(pattern, ['difficulty_average']),
      craft: _readString(craft ?? const {}, ['name']) ??
          _readString(pattern, ['craft_name', 'craft']),
      categories: categories,
      ravelryUrl: permalink != null
          ? 'https://www.ravelry.com/patterns/library/$permalink'
          : _readString(pattern, ['pattern_url', 'url']),
    );
  }
}

class RavelryProject {
  final int id;
  final String name;
  final String? patternName;
  final String? status;
  final String? thumbnailUrl;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;

  const RavelryProject({
    required this.id,
    required this.name,
    this.patternName,
    this.status,
    this.thumbnailUrl,
    this.startedAt,
    this.completedAt,
    this.notes,
  });

  factory RavelryProject.fromJson(Map<String, dynamic> json) {
    final pattern = _readMap(json, ['pattern']);
    final statusType = _readMap(json, ['status_type', 'status']);

    return RavelryProject(
      id: _readInt(json, ['id', 'project_id']),
      name: _readString(json, ['name', 'project_name', 'title']) ?? 'Untitled project',
      patternName: _readString(pattern ?? const {}, ['name', 'pattern_name', 'title']) ??
          _readString(json, ['pattern_name']),
      status: _readString(statusType ?? const {}, ['name']) ??
          _readString(json, ['status_name', 'status']),
      thumbnailUrl: _photoUrlFrom(json) ?? _photoUrlFrom(pattern),
      startedAt: DateTime.tryParse(
        _readString(json, ['started', 'started_at', 'start_date']) ?? '',
      ),
      completedAt: DateTime.tryParse(
        _readString(json, ['completed', 'completed_at', 'finish_date']) ?? '',
      ),
      notes: _readString(json, ['notes', 'note']),
    );
  }

  String get statusKo {
    return switch (status?.toLowerCase()) {
      'finished' => '완성',
      'in-progress' => '진행 중',
      'hibernating' => '일시정지',
      'frog' => '해체함',
      _ => status ?? '상태 없음',
    };
  }
}

class RavelryYarnResult {
  final int id;
  final String name;
  final String? brandName;
  final String? weightName;
  final double? grams;
  final double? yardage;
  final String? thumbnailUrl;
  final double? ratingAverage;

  const RavelryYarnResult({
    required this.id,
    required this.name,
    this.brandName,
    this.weightName,
    this.grams,
    this.yardage,
    this.thumbnailUrl,
    this.ratingAverage,
  });

  factory RavelryYarnResult.fromJson(Map<String, dynamic> json) {
    final weight = _readMap(json, ['yarn_weight', 'weight']);

    return RavelryYarnResult(
      id: _readInt(json, ['id', 'yarn_id']),
      name: _readString(json, ['name', 'yarn_name']) ?? 'Untitled yarn',
      brandName: _readString(json, ['yarn_company_name', 'brand_name']),
      weightName: _readString(weight ?? const {}, ['name']) ??
          _readString(json, ['weight_name']),
      grams: _readDouble(json, ['grams']),
      yardage: _readDouble(json, ['yardage', 'yards']),
      thumbnailUrl: _photoUrlFrom(json),
      ratingAverage: _readDouble(json, ['rating_average']),
    );
  }
}
