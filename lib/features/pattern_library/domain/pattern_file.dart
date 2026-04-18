enum PatternFileSource { dropbox, upload, gallery, camera }

enum PatternParseStatus { pending, parsing, done, failed }

class PatternFile {
  final String id;
  final String fileName;
  final String storagePath;
  final String storageUrl;
  final String mimeType;
  final int fileSize;
  final PatternFileSource source;
  final Map<String, dynamic>? sourceMeta;
  final String? thumbnailUrl;
  final String? parsedChartId;
  final PatternParseStatus parseStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PatternFile({
    required this.id,
    required this.fileName,
    required this.storagePath,
    required this.storageUrl,
    required this.mimeType,
    required this.fileSize,
    required this.source,
    this.sourceMeta,
    this.thumbnailUrl,
    this.parsedChartId,
    required this.parseStatus,
    required this.createdAt,
    this.updatedAt,
  });

  factory PatternFile.fromMap(String id, Map<String, dynamic> map) {
    return PatternFile(
      id: id,
      fileName: map['fileName'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      storageUrl: map['storageUrl'] as String? ?? '',
      mimeType: map['mimeType'] as String? ?? '',
      fileSize: map['fileSize'] as int? ?? 0,
      source: PatternFileSource.values.firstWhere(
        (e) => e.name == (map['source'] as String? ?? ''),
        orElse: () => PatternFileSource.upload,
      ),
      sourceMeta: map['sourceMeta'] != null
          ? Map<String, dynamic>.from(map['sourceMeta'] as Map)
          : null,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      parsedChartId: map['parsedChartId'] as String?,
      parseStatus: PatternParseStatus.values.firstWhere(
        (e) => e.name == (map['parseStatus'] as String? ?? ''),
        orElse: () => PatternParseStatus.pending,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'storagePath': storagePath,
      'storageUrl': storageUrl,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'source': source.name,
      if (sourceMeta != null) 'sourceMeta': sourceMeta,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (parsedChartId != null) 'parsedChartId': parsedChartId,
      'parseStatus': parseStatus.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
    };
  }

  PatternFile copyWith({
    String? id,
    String? fileName,
    String? storagePath,
    String? storageUrl,
    String? mimeType,
    int? fileSize,
    PatternFileSource? source,
    Map<String, dynamic>? sourceMeta,
    String? thumbnailUrl,
    String? parsedChartId,
    PatternParseStatus? parseStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatternFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      storagePath: storagePath ?? this.storagePath,
      storageUrl: storageUrl ?? this.storageUrl,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      source: source ?? this.source,
      sourceMeta: sourceMeta ?? this.sourceMeta,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      parsedChartId: parsedChartId ?? this.parsedChartId,
      parseStatus: parseStatus ?? this.parseStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
