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
  /// Ravelry yarn DB ID — `/yarns/{id}.json` 호출에 사용 (#658 상세 보강).
  final int? yarnId;

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
    this.yarnId,
  });

  factory RavelryStashEntry.fromJson(Map<String, dynamic> json) {
    final yarn = _readMap(json, ['yarn']);
    final yarnWeight = yarn != null ? _readMap(yarn, ['yarn_weight', 'weight']) : null;
    final company = yarn != null ? _readMap(yarn, ['yarn_company', 'brand']) : null;
    final resolvedYarnId = yarn != null
        ? _readInt(yarn, ['id', 'yarn_id'], -1)
        : _readInt(json, ['yarn_id'], -1);

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
      yarnId: resolvedYarnId == -1 ? null : resolvedYarnId,
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
    final nestedPattern = _readMap(json, ['pattern', 'first_pattern']);
    final pattern = nestedPattern ?? json;
    final author = _readMap(pattern, ['pattern_author', 'designer', 'author']);
    final craft = _readMap(pattern, ['craft']);
    final categoryItems = _readList(pattern, ['pattern_categories', 'categories']) ?? const [];
    final categories = categoryItems
        .whereType<Map<String, dynamic>>()
        .map((item) => _readString(item, ['name', 'label']) ?? '')
        .where((item) => item.isNotEmpty)
        .toList();

    final permalink = _readString(pattern, ['permalink']);

    // 실제 Ravelry 패턴 ID: 중첩 pattern.id 우선, 없으면 root의 pattern_id, 최후 fallback은 id(volume id일 수 있음)
    final resolvedId = nestedPattern != null
        ? _readInt(nestedPattern, ['id', 'pattern_id'])
        : (json['pattern_id'] as int?) ?? (json['queued_pattern_id'] as int?) ?? _readInt(json, ['id']);

    return RavelryLibraryPattern(
      id: resolvedId,
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

// ── 도안 파일 ─────────────────────────────────────────────────────────────────
class RavelryPatternFile {
  final int id;
  final String fileName;
  final String? url;

  const RavelryPatternFile({required this.id, required this.fileName, this.url});

  factory RavelryPatternFile.fromJson(Map<String, dynamic> json) {
    return RavelryPatternFile(
      id: _readInt(json, ['id']),
      fileName: _readString(json, ['asset_file_name', 'name', 'filename']) ?? 'file',
      url: _readString(json, ['url', 'download_url', 'asset_url']),
    );
  }
}

// ── 도안 상세 ─────────────────────────────────────────────────────────────────
class RavelryPatternDetail {
  final int id;
  final String name;
  final String? authorName;
  final String? notesHtml;
  final List<String> photoUrls;
  final String? craft;
  final bool isFree;
  final double? price;
  final double? difficultyAverage;
  final List<String> categories;
  final String? ravelryUrl;
  final String? pdfUrl;
  final List<RavelryPatternFile> files;

  const RavelryPatternDetail({
    required this.id,
    required this.name,
    this.authorName,
    this.notesHtml,
    this.photoUrls = const [],
    this.craft,
    this.isFree = false,
    this.price,
    this.difficultyAverage,
    this.categories = const [],
    this.ravelryUrl,
    this.pdfUrl,
    this.files = const [],
  });

  factory RavelryPatternDetail.fromJson(Map<String, dynamic> json) {
    final author = _readMap(json, ['pattern_author', 'designer', 'author']);
    final craftMap = _readMap(json, ['craft']);
    final categoryItems = _readList(json, ['pattern_categories', 'categories']) ?? [];
    final categories = categoryItems
        .whereType<Map<String, dynamic>>()
        .map((e) => _readString(e, ['name', 'label']) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final photos = _readList(json, ['photos', 'pattern_photos']) ?? [];
    final photoUrls = photos
        .whereType<Map<String, dynamic>>()
        .map((p) => _readString(p, ['medium_url', 'small_url', 'square_url']) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final filesList = _readList(json, ['pattern_files', 'files']) ?? [];
    final files = filesList
        .whereType<Map<String, dynamic>>()
        .map((f) => RavelryPatternFile.fromJson(f))
        .toList();

    final permalink = _readString(json, ['permalink']);

    return RavelryPatternDetail(
      id: _readInt(json, ['id', 'pattern_id']),
      name: _readString(json, ['name', 'pattern_name', 'title']) ?? 'Untitled',
      authorName: _readString(author ?? const {}, ['name']) ??
          _readString(json, ['designer_name', 'author_name']),
      notesHtml: _readString(json, ['notes_html', 'notes']),
      photoUrls: photoUrls,
      craft: _readString(craftMap ?? const {}, ['name']) ??
          _readString(json, ['craft_name']),
      isFree: json['free'] == true,
      price: _readDouble(json, ['price']),
      difficultyAverage: _readDouble(json, ['difficulty_average']),
      categories: categories,
      ravelryUrl: permalink != null
          ? 'https://www.ravelry.com/patterns/library/$permalink'
          : _readString(json, ['pattern_url', 'url']),
      pdfUrl: _readString(json, ['pdf_url', 'download_url']) ??
          _readString(_readMap(json, ['printing']) ?? const {}, ['pdf_url', 'url', 'download_url']) ??
          _readString(_readMap(_readMap(json, ['printing']) ?? const {}, ['pdf']) ?? const {}, ['url', 'download_url']),
      files: files,
    );
  }
}

// ── 프로젝트 상세 ─────────────────────────────────────────────────────────────
class RavelryProjectDetail {
  final int id;
  final String name;
  final int? patternId;
  final String? patternName;
  final String? status;
  final int? statusTypeId;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<String> photoUrls;

  const RavelryProjectDetail({
    required this.id,
    required this.name,
    this.patternId,
    this.patternName,
    this.status,
    this.statusTypeId,
    this.notes,
    this.startedAt,
    this.completedAt,
    this.photoUrls = const [],
  });

  factory RavelryProjectDetail.fromJson(Map<String, dynamic> json) {
    final pattern = _readMap(json, ['pattern']);
    final statusType = _readMap(json, ['status_type', 'status']);

    final photos = _readList(json, ['project_photos', 'photos']) ?? [];
    final photoUrls = photos
        .whereType<Map<String, dynamic>>()
        .map((p) => _readString(p, ['medium_url', 'small_url', 'square_url']) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return RavelryProjectDetail(
      id: _readInt(json, ['id', 'project_id']),
      name: _readString(json, ['name', 'project_name', 'title']) ?? 'Untitled project',
      patternId: pattern != null ? _readInt(pattern, ['id'], -1).let((v) => v == -1 ? null : v) : null,
      patternName: _readString(pattern ?? const {}, ['name', 'title']) ??
          _readString(json, ['pattern_name']),
      status: _readString(statusType ?? const {}, ['name']) ??
          _readString(json, ['status_name', 'status']),
      statusTypeId: statusType != null ? _readInt(statusType, ['id'], -1).let((v) => v == -1 ? null : v) : null,
      notes: _readString(json, ['notes', 'note']),
      startedAt: DateTime.tryParse(
        _readString(json, ['started', 'started_at', 'start_date']) ?? '',
      ),
      completedAt: DateTime.tryParse(
        _readString(json, ['completed', 'completed_at', 'finish_date']) ?? '',
      ),
      photoUrls: photoUrls,
    );
  }

  String get statusKo {
    return switch (status?.toLowerCase()) {
      'finished' => '완성',
      'in-progress' || 'inprogress' => '진행 중',
      'hibernating' => '일시정지',
      'frog' => '해체함',
      _ => status ?? '상태 없음',
    };
  }
}

extension _IntLet on int {
  T let<T>(T Function(int) fn) => fn(this);
}

// ── 이슈 #644 Phase 7 — Ravelry yarn DB 검색 결과 / 상세 ────────────────────
/// Ravelry `/yarns/search.json` 항목 또는 `/yarns/{id}.json` 응답을 표현.
class RavelryYarnSearchItem {
  final int id;
  final String name;
  final String? yarnCompanyName;
  final String? yarnWeight;
  final double? gaugeStitches;
  final double? gaugeRows;
  final String? fiberContent;
  final String? recommendedNeedle;
  final bool? machineWashable;
  final String? permalink;
  final String? photoUrl;
  final double? grams;
  final double? yardage;
  final double? ratingAverage;
  final bool discontinued;

  const RavelryYarnSearchItem({
    required this.id,
    required this.name,
    this.yarnCompanyName,
    this.yarnWeight,
    this.gaugeStitches,
    this.gaugeRows,
    this.fiberContent,
    this.recommendedNeedle,
    this.machineWashable,
    this.permalink,
    this.photoUrl,
    this.grams,
    this.yardage,
    this.ratingAverage,
    this.discontinued = false,
  });

  factory RavelryYarnSearchItem.fromJson(Map<String, dynamic> json) {
    final company = _readMap(json, ['yarn_company']);
    final yarnWeightMap = _readMap(json, ['yarn_weight']);
    final fibers = _readList(json, ['yarn_fibers']);
    final fiberStr = (fibers ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((f) {
          final fiberType = _readMap(f, ['fiber_type']);
          final name = _readString(fiberType ?? const {}, ['name']) ??
              _readString(f, ['name']);
          final pct = _readDouble(f, ['percentage']);
          if (name == null) return '';
          if (pct != null) return '${pct.toStringAsFixed(0)}% $name';
          return name;
        })
        .where((s) => s.isNotEmpty)
        .join(', ');

    return RavelryYarnSearchItem(
      id: _readInt(json, ['id', 'yarn_id']),
      name: _readString(json, ['name', 'yarn_name']) ?? 'Untitled yarn',
      yarnCompanyName: _readString(company ?? const {}, ['name']) ??
          _readString(json, ['yarn_company_name', 'brand_name']),
      yarnWeight: _readString(yarnWeightMap ?? const {}, ['name']) ??
          _readString(json, ['weight_name', 'yarn_weight']),
      gaugeStitches: _readDouble(json, ['gauge_stitches', 'gauge']),
      gaugeRows: _readDouble(json, ['gauge_rows']),
      fiberContent: fiberStr.isEmpty
          ? _readString(json, ['fiber_content', 'composition'])
          : fiberStr,
      recommendedNeedle: _readString(json, ['knit_needle_size_metric', 'recommended_needle_size']),
      machineWashable: json['machine_washable'] is bool
          ? json['machine_washable'] as bool
          : null,
      permalink: _readString(json, ['permalink']),
      photoUrl: _photoUrlFrom(json),
      grams: _readDouble(json, ['grams']),
      yardage: _readDouble(json, ['yardage', 'yards']),
      ratingAverage: _readDouble(json, ['rating_average']),
      discontinued: json['discontinued'] == true,
    );
  }

  String? get ravelryUrl =>
      permalink != null ? 'https://www.ravelry.com/yarns/library/$permalink' : null;
}

/// `/yarns/{id}.json` 상세 — 검색 항목과 동일 구조 + 추가 필드.
typedef RavelryYarnDetail = RavelryYarnSearchItem;

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
