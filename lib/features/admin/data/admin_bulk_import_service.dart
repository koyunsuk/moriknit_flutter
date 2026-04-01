import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_import_models.dart';

final adminBulkImportServiceProvider = Provider<AdminBulkImportService>(
  (_) => AdminBulkImportService(),
);

class AdminBulkImportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── 파일 파싱 ───────────────────────────────────────────────

  Future<AdminImportPreview> parseFile({
    required AdminImportKind kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return _parseExcel(kind: kind, fileName: fileName, bytes: bytes);
    }
    return _parseCsv(kind: kind, fileName: fileName, bytes: bytes);
  }

  AdminImportPreview _errorPreview(AdminImportKind kind, String name, String msg) {
    return AdminImportPreview(
      kind: kind,
      fileName: name,
      headers: kind.headers,
      validRows: const [],
      errors: [msg],
    );
  }

  // ── CSV 파싱 ────────────────────────────────────────────────

  Future<AdminImportPreview> _parseCsv({
    required AdminImportKind kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final raw = _decodeCsv(bytes);
    final rows = _parseDelimited(raw);
    return _buildPreview(kind: kind, fileName: fileName, rows: rows);
  }

  // ── Excel 파싱 ──────────────────────────────────────────────

  Future<AdminImportPreview> _parseExcel({
    required AdminImportKind kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      if (sheet.rows.isEmpty) return _errorPreview(kind, fileName, 'Empty sheet');

      final rows = sheet.rows.map((row) {
        return row.map((cell) => cell?.value?.toString() ?? '').toList();
      }).toList();

      return _buildPreview(kind: kind, fileName: fileName, rows: rows);
    } catch (e) {
      return _errorPreview(kind, fileName, 'Excel parse error: $e');
    }
  }

  // ── 공통 미리보기 생성 ──────────────────────────────────────

  AdminImportPreview _buildPreview({
    required AdminImportKind kind,
    required String fileName,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) return _errorPreview(kind, fileName, 'Empty file');

    final headers = rows.first.map(_normalizeHeader).toList();
    final errors = <String>[];
    final validRows = <Map<String, String>>[];

    for (var i = 1; i < rows.length; i++) {
      final values = rows[i];
      if (values.every((v) => v.trim().isEmpty)) continue;
      final mapped = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        mapped[headers[j]] = j < values.length ? values[j].trim() : '';
      }
      if (_isTemplateRequirementRow(mapped)) continue;
      final err = _validate(kind, mapped);
      if (err != null) {
        errors.add('row ${i + 1}: $err');
      } else {
        validRows.add(mapped);
      }
    }

    return AdminImportPreview(
      kind: kind,
      fileName: fileName,
      headers: headers,
      validRows: validRows,
      errors: errors,
    );
  }

  // ── Firestore 저장 (500개 청크) ─────────────────────────────

  Future<AdminImportResult> applyPreview({
    required AdminImportPreview preview,
    required String adminUid,
    void Function(int done, int total)? onProgress,
  }) async {
    final rows = preview.validRows;
    const chunkSize = 490; // Firestore batch 한계 500보다 여유있게
    int created = 0;

    for (var start = 0; start < rows.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, rows.length);
      final chunk = rows.sublist(start, end);
      final batch = _db.batch();

      for (final row in chunk) {
        switch (preview.kind) {
          case AdminImportKind.market:
            batch.set(_db.collection('market_items').doc(), _marketPayload(row));
          case AdminImportKind.pattern:
            batch.set(_db.collection('market_items').doc(), _patternPayload(row));
          case AdminImportKind.encyclopedia:
            batch.set(_db.collection('encyclopedia').doc(), _encyclopediaPayload(row, adminUid));
          case AdminImportKind.communityPost:
            batch.set(_db.collection('posts').doc(), _communityPayload(row));
          case AdminImportKind.yarnBrand:
            {
              final docId = (row['brand_id'] ?? '').trim();
              final docRef = docId.isEmpty
                  ? _db.collection('yarnBrands').doc()
                  : _db.collection('yarnBrands').doc(docId);
              batch.set(docRef, _brandPayload(row), SetOptions(merge: true));
            }
          case AdminImportKind.needleBrand:
            {
              final docId = (row['brand_id'] ?? '').trim();
              final docRef = docId.isEmpty
                  ? _db.collection('needleBrands').doc()
                  : _db.collection('needleBrands').doc(docId);
              batch.set(docRef, _brandPayload(row), SetOptions(merge: true));
            }
        }
        created++;
      }

      await batch.commit();
      onProgress?.call(created, rows.length);
    }

    await _db.collection('admin_import_logs').add({
      'kind': preview.kind.key,
      'fileName': preview.fileName,
      'validCount': preview.validCount,
      'invalidCount': preview.invalidCount,
      'errors': preview.errors.take(20).toList(),
      'adminUid': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return AdminImportResult(createdCount: created, skippedCount: preview.invalidCount);
  }

  // ── 유틸리티 ────────────────────────────────────────────────

  String _decodeCsv(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  List<List<String>> _parseDelimited(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const [];
    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    return lines.map((line) => _parseLine(line, delimiter)).toList();
  }

  List<String> _parseLine(String line, String delimiter) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (!inQuotes && char == delimiter) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    values.add(buffer.toString());
    return values;
  }

  String _normalizeHeader(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
    return switch (normalized) {
      'category' => 'category_key',
      'term' => 'term_ko',
      'description' => 'description_ko',
      'symbol' => 'symbol_key',
      _ => normalized,
    };
  }

  bool _isTemplateRequirementRow(Map<String, String> row) {
    final values = row.values.map((value) => value.trim().toLowerCase()).toSet();
    return values.isNotEmpty &&
        values.difference({'required', 'optional', '필수', '선택'}).isEmpty;
  }

  String? _validate(AdminImportKind kind, Map<String, String> row) {
    switch (kind) {
      case AdminImportKind.market:
        if ((row['title'] ?? '').isEmpty) return 'title is required';
        if ((row['price'] ?? '').isEmpty) return 'price is required';
        if ((row['category_key'] ?? '').isEmpty) return 'category_key is required';
        return null;
      case AdminImportKind.pattern:
        if ((row['title'] ?? '').isEmpty) return 'title is required';
        if ((row['price'] ?? '').isEmpty) return 'price is required';
        return null;
      case AdminImportKind.encyclopedia:
        if ((row['term_key'] ?? '').isEmpty) return 'term_key is required';
        if ((row['term_ko'] ?? '').isEmpty) return 'term_ko is required';
        if ((row['category_key'] ?? '').isEmpty) return 'category_key is required';
        if ((row['description_ko'] ?? '').isEmpty) return 'description_ko is required';
        return null;
      case AdminImportKind.communityPost:
        if ((row['title'] ?? '').isEmpty) return 'title is required';
        if ((row['content'] ?? '').isEmpty) return 'content is required';
        if ((row['author_name'] ?? '').isEmpty) return 'author_name is required';
        if ((row['category_key'] ?? '').isEmpty) return 'category_key is required';
        return null;
      case AdminImportKind.yarnBrand:
      case AdminImportKind.needleBrand:
        if ((row['name'] ?? '').isEmpty) return 'name is required';
        return null;
    }
  }

  // ── Firestore 페이로드 ──────────────────────────────────────

  Map<String, dynamic> _marketPayload(Map<String, String> row) => {
        'sellerUid': row['seller_uid'] ?? 'official',
        'sellerName': row['seller_name'] ?? 'moriknit',
        'title': row['title'] ?? '',
        'description': row['description'] ?? '',
        'price': int.tryParse(row['price'] ?? '') ?? 0,
        'category': row['category_key'] ?? 'tool',
        'accentHex': row['accent_hex']?.isNotEmpty == true ? row['accent_hex'] : '#F472B6',
        'imageType': row['image_type']?.isNotEmpty == true ? row['image_type'] : 'product',
        'isOfficial': _toBool(row['is_official']),
        'isSoldOut': _toBool(row['is_sold_out']),
        'status': row['status']?.isNotEmpty == true ? row['status'] : 'approved',
        'imageUrl': row['image_url'] ?? '',
        'pdfUrl': row['pdf_url'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _patternPayload(Map<String, String> row) => {
        ..._marketPayload(row),
        'category': 'pattern',
        'imageType': row['image_type']?.isNotEmpty == true ? row['image_type'] : 'pattern',
      };

  Map<String, dynamic> _encyclopediaPayload(Map<String, String> row, String adminUid) => {
        'termKey': row['term_key'] ?? '',
        'term': row['term_ko'] ?? '',
        'termEn': row['term_en'] ?? '',
        'termJa': row['term_ja'] ?? '',
        'abbreviation': row['abbreviation'] ?? '',
        'categoryKey': row['category_key'] ?? 'term',
        'category': row['category_key'] ?? 'term',
        'description': row['description_ko'] ?? '',
        'descriptionEn': row['description_en'] ?? '',
        'descriptionJa': row['description_ja'] ?? '',
        'aliases': _splitPipe(row['aliases']),
        'symbolKey': row['symbol_key'] ?? '',
        'symbol': row['symbol_key'] ?? '',
        'referenceUrl': row['reference_url'] ?? '',
        'videoUrl': row['video_url'] ?? '',
        'order': int.tryParse(row['order'] ?? '') ?? 0,
        'status': row['status']?.isNotEmpty == true ? row['status'] : 'approved',
        'createdBy': adminUid,
        'approvedBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _communityPayload(Map<String, String> row) => {
        'uid': row['uid'] ?? 'official',
        'authorName': row['author_name']?.isNotEmpty == true ? row['author_name'] : 'moriknit',
        'category': row['category_key']?.isNotEmpty == true ? row['category_key'] : 'showcase',
        'title': row['title'] ?? '',
        'content': row['content'] ?? '',
        'imageUrls': _splitPipe(row['image_urls']),
        'attachmentUrls': _splitPipe(row['attachment_urls']),
        'attachmentNames': _splitPipe(row['attachment_names']),
        'likeCount': int.tryParse(row['like_count'] ?? '') ?? 0,
        'commentCount': int.tryParse(row['comment_count'] ?? '') ?? 0,
        'likedBy': _splitPipe(row['liked_by']),
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _brandPayload(Map<String, String> row) {
    final name = (row['name'] ?? '').trim();
    return {
      'name': name,
      'nameLower': name.toLowerCase(),
      'country': (row['country'] ?? '').trim(),
      'website': (row['website'] ?? '').trim(),
      'notes': (row['notes'] ?? '').trim(),
      'isActive': row['is_active']?.trim().isEmpty ?? true ? true : _toBool(row['is_active']),
      'sortOrder': int.tryParse(row['sort_order'] ?? '') ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool _toBool(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes' || v == 'y';
  }

  List<String> _splitPipe(String? value) {
    if (value == null || value.trim().isEmpty) return const [];
    return value.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }
}
