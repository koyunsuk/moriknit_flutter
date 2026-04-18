import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/dropbox_file_entry.dart';
import 'dropbox_auth_provider.dart';

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

  // ── 파일 다운로드 ─────────────────────────────────────────────────────────────

  /// POST content.dropboxapi.com/2/files/download
  /// header: Dropbox-API-Arg: {"path": "..."}
  Future<Uint8List> downloadFile(String dropboxPath) async {
    final token = await _auth.getValidAccessToken();
    if (token == null) throw Exception('Dropbox 로그인이 필요합니다.');

    final apiArg = jsonEncode({'path': dropboxPath});
    final headers = {
      'Authorization': 'Bearer $token',
      'Dropbox-API-Arg': apiArg,
    };

    var response = await http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/download'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      // refresh 후 1회 재시도
      await _auth.login();
      final refreshedToken = await _auth.getValidAccessToken();
      if (refreshedToken == null) throw Exception('Dropbox 인증 갱신 실패');
      final refreshedHeaders = {
        'Authorization': 'Bearer $refreshedToken',
        'Dropbox-API-Arg': apiArg,
      };
      response = await http.post(
        Uri.parse('https://content.dropboxapi.com/2/files/download'),
        headers: refreshedHeaders,
      );
    }

    _assertOk(response);
    return response.bodyBytes;
  }

  // ── 공통 ─────────────────────────────────────────────────────────────────────

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Dropbox API 오류 (${response.statusCode}): ${response.body}',
      );
    }
  }
}
