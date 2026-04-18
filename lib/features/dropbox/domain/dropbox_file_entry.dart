class DropboxFileEntry {
  final String name;
  final String path; // Dropbox path_lower
  final bool isFolder;
  final int? size;
  final String? rev;
  final DateTime? clientModified;

  const DropboxFileEntry({
    required this.name,
    required this.path,
    required this.isFolder,
    this.size,
    this.rev,
    this.clientModified,
  });

  factory DropboxFileEntry.fromJson(Map<String, dynamic> json) {
    final tag = json['.tag'] as String? ?? '';
    final isFolder = tag == 'folder';
    return DropboxFileEntry(
      name: json['name'] as String? ?? '',
      path: json['path_lower'] as String? ?? json['path_display'] as String? ?? '',
      isFolder: isFolder,
      size: isFolder ? null : json['size'] as int?,
      rev: isFolder ? null : json['rev'] as String?,
      clientModified: isFolder
          ? null
          : json['client_modified'] != null
              ? DateTime.tryParse(json['client_modified'] as String)
              : null,
    );
  }

  /// 정렬 기준: 폴더 먼저, 그 다음 파일 알파벳순 (대소문자 무시)
  static int compare(DropboxFileEntry a, DropboxFileEntry b) {
    if (a.isFolder && !b.isFolder) return -1;
    if (!a.isFolder && b.isFolder) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
