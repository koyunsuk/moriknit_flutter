import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/dropbox_file_entry.dart';
import 'dropbox_auth_provider.dart';

/// 이슈 #654 — list_folder 페이지 결과 (entries + cursor + has_more)
class DropboxListPage {
  final List<DropboxFileEntry> entries;
  final String? cursor;
  final bool hasMore;
  const DropboxListPage({
    required this.entries,
    required this.cursor,
    required this.hasMore,
  });
}

class DropboxApiClient {
  final DropboxAuthProvider _auth;

  DropboxApiClient(this._auth);

  // ── 내부 헬퍼 ────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getValidAccessToken();
    if (token == null) throw Exception('Dropbox 로그인이 필요합니다.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// POST 요청 — 401 시 토큰 refresh 후 1회 재시도
  Future<http.Response> _post(
    Uri uri,
    Object? body, {
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _authHeaders();
    if (extraHeaders != null) headers.addAll(extraHeaders);

    final encoded = body != null ? jsonEncode(body) : '';
    var response = await http.post(uri, headers: headers, body: encoded);

    if (response.statusCode == 401) {
      // refresh 후 재시도
      await _auth.login(); // refresh가 없으면 재로그인 흐름
      final refreshedHeaders = await _authHeaders();
      if (extraHeaders != null) refreshedHeaders.addAll(extraHeaders);
      response = await http.post(uri, headers: refreshedHeaders, body: encoded);
    }

    return response;
  }

  // ── 파일 목록 API ─────────────────────────────────────────────────────────────

  /// POST /2/files/list_folder
  /// [path]: Dropbox 폴더 경로 (루트는 빈 문자열 "" 또는 "")
  Future<List<DropboxFileEntry>> listFolder(String path) async {
    final response = await _post(
      Uri.parse('https://api.dropboxapi.com/2/files/list_folder'),
      {'path': path, 'recursive': false, 'include_media_info': false},
    );

    _assertOk(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = (json['entries'] as List<dynamic>? ?? [])
        .map((e) => DropboxFileEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    entries.sort(DropboxFileEntry.compare);
    return entries;
  }

  /// POST /2/files/list_folder/continue
  Future<List<DropboxFileEntry>> listFolderContinue(String cursor) async {
    final response = await _post(
      Uri.parse('https://api.dropboxapi.com/2/files/list_folder/continue'),
      {'cursor': cursor},
    );

    _assertOk(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = (json['entries'] as List<dynamic>? ?? [])
        .map((e) => DropboxFileEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    entries.sort(DropboxFileEntry.compare);
    return entries;
  }

  /// 이슈 #654 — 페이지네이션 정보를 포함한 list_folder.
  /// 첫 호출 (cursor=null) 시 path 사용, 이후 호출 (cursor 있음) 시 continue 사용.
  Future<DropboxListPage> listFolderPage({
    required String path,
    String? cursor,
  }) async {
    final response = cursor == null
        ? await _post(
            Uri.parse('https://api.dropboxapi.com/2/files/list_folder'),
            {'path': path, 'recursive': false, 'include_media_info': false},
          )
        : await _post(
            Uri.parse(
                'https://api.dropboxapi.com/2/files/list_folder/continue'),
            {'cursor': cursor},
          );

    _assertOk(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = (json['entries'] as List<dynamic>? ?? [])
        .map((e) => DropboxFileEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    entries.sort(DropboxFileEntry.compare);
    return DropboxListPage(
      entries: entries,
      cursor: json['cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  // ── 파일 다운로드 ─────────────────────────────────────────────────────────────

  /// POST /2/files/download?arg={percent-encoded-json}
  /// URL 쿼리 파라미터 방식: Dart Uri가 한글 포함 모든 문자를 percent-encoding으로 안전하게 처리
  Future<Uint8List> downloadFile(String dropboxPath) async {
    final token = await _auth.getValidAccessToken();
    if (token == null) throw Exception('Dropbox 로그인이 필요합니다.');

    var response = await _doDownload(token, dropboxPath);

    if (response.statusCode == 401) {
      await _auth.login();
      final newToken = await _auth.getValidAccessToken();
      if (newToken == null) throw Exception('Dropbox 인증 갱신 실패');
      response = await _doDownload(newToken, dropboxPath);
    }

    _assertOk(response);
    return response.bodyBytes;
  }

  Future<http.Response> _doDownload(String token, String path) {
    final uri = Uri.https('content.dropboxapi.com', '/2/files/download');
    final argJson = _asciiJson({'path': path});
    return http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Dropbox-API-Arg': argJson,
    });
  }

  /// HTTP 헤더에 안전하게 전달할 수 있는 ASCII-only JSON 문자열 생성
  static String _asciiJson(Map<String, dynamic> obj) {
    final raw = jsonEncode(obj);
    final buf = StringBuffer();
    for (final rune in raw.runes) {
      if (rune > 0x7F) {
        buf.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  // ── 공통 ─────────────────────────────────────────────────────────────────────

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String reason;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        reason = (decoded['error_summary'] as String?) ??
            (decoded['error'] as String?) ??
            response.body;
      } catch (_) {
        reason = response.body;
      }
      final detail = reason.isNotEmpty ? reason : '(empty body)';
      // Dropbox 앱에 files.content.read 권한이 없는 경우 (API 권한 설정 문제)
      if (detail.contains('files/download') ||
          detail.contains('not allowed to call') ||
          detail.contains('access_denied')) {
        throw Exception('DROPBOX_SCOPE_ERROR');
      }
      final short = detail.length > 160 ? '${detail.substring(0, 160)}…' : detail;
      throw Exception('Dropbox 오류 (${response.statusCode}): $short');
    }
  }
}
