import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/ravelry_models.dart';
import 'ravelry_auth_provider.dart';

const _kFunctionsBase = String.fromEnvironment(
  'RAVELRY_BACKEND_BASE',
  defaultValue: 'https://us-central1-moriknit-ceea9.cloudfunctions.net',
);

class RavelryRepository {
  final Ref _ref;

  RavelryRepository(this._ref);

  Future<List<RavelryStashEntry>> fetchStash() async {
    final data = await _get('/ravelryStash');
    final items = (data['stash'] as List<dynamic>?) ??
        (data['stash_entries'] as List<dynamic>?) ??
        (data['results'] as List<dynamic>?) ??
        const [];
    return items
        .map((e) => RavelryStashEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RavelryLibraryPattern>> fetchLibrary() async {
    final data = await _get('/ravelryLibrary');
    final volumes = (data['volumes'] as List<dynamic>?) ??
        (data['library_volumes'] as List<dynamic>?) ??
        (data['patterns'] as List<dynamic>?) ??
        (data['items'] as List<dynamic>?) ??
        (data['results'] as List<dynamic>?) ??
        const [];
    return volumes
        .map((e) => RavelryLibraryPattern.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RavelryProject>> fetchProjects() async {
    final data = await _get('/ravelryProjects');
    final projects = (data['projects'] as List<dynamic>?) ??
        (data['items'] as List<dynamic>?) ??
        (data['results'] as List<dynamic>?) ??
        const [];
    return projects
        .map((e) => RavelryProject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 도안 상세 ─────────────────────────────────────────────────────────────────
  Future<RavelryPatternDetail> fetchPatternDetail(int patternId) async {
    final data = await _get('/ravelryPatternDetail', queryParams: {'id': '$patternId'});
    final pattern = (data['pattern'] as Map<String, dynamic>?) ?? data;
    return RavelryPatternDetail.fromJson(pattern);
  }

  Future<List<RavelryPatternFile>> fetchPatternFiles(int patternId) async {
    final data = await _get('/ravelryPatternFiles', queryParams: {'id': '$patternId'});
    final files = (data['pattern_files'] as List<dynamic>?) ??
        (data['files'] as List<dynamic>?) ?? const [];
    return files
        .whereType<Map<String, dynamic>>()
        .map(RavelryPatternFile.fromJson)
        .toList();
  }

  Future<Uint8List> downloadPatternFile(String fileUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    final idToken = await user.getIdToken(true);
    final encodedUrl = Uri.encodeQueryComponent(fileUrl);
    final response = await http.get(
      Uri.parse('$_kFunctionsBase/ravelryPatternDownload?url=$encodedUrl'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      _ref.read(ravelryAuthProvider.notifier).clearSession();
      throw Exception('Ravelry 연결이 끊겼습니다. 다시 연결해 주세요.');
    }
    if (response.statusCode != 200) {
      throw Exception('다운로드 실패 (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  // ── 프로젝트 상세 ─────────────────────────────────────────────────────────────
  Future<RavelryProjectDetail> fetchProjectDetail(int projectId) async {
    final data = await _get('/ravelryProjectDetail', queryParams: {'id': '$projectId'});
    final project = (data['project'] as Map<String, dynamic>?) ?? data;
    return RavelryProjectDetail.fromJson(project);
  }

  // ── 프로젝트 생성 ─────────────────────────────────────────────────────────────
  /// 이슈 #644 — packs 파라미터 추가. 모리니트 yarn → Ravelry stash 매핑 전달.
  Future<RavelryProject> createProject({
    required String name,
    int? patternId,
    String? notes,
    int statusTypeId = 1,
    List<Map<String, dynamic>>? packs,
  }) async {
    final projectBody = <String, dynamic>{
      'name': name,
      if (patternId != null) 'pattern_id': patternId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'status_type_id': statusTypeId,
      if (packs != null && packs.isNotEmpty) 'packs': packs,
    };
    final data = await _post('/ravelryCreateProject', {'project': projectBody});
    final project = (data['project'] as Map<String, dynamic>?) ?? data;
    return RavelryProject.fromJson(project);
  }

  // ── 프로젝트 수정 ─────────────────────────────────────────────────────────────
  Future<RavelryProject> updateProject({
    required int projectId,
    String? name,
    String? notes,
    int? statusTypeId,
    String? started,
    String? completed,
    List<Map<String, dynamic>>? packs,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (statusTypeId != null) 'status_type_id': statusTypeId,
      if (started != null) 'started': started,
      if (completed != null) 'completed': completed,
      if (packs != null && packs.isNotEmpty) 'packs': packs,
    };
    final data = await _post('/ravelryUpdateProject', {'project': body},
        queryParams: {'id': '$projectId'});
    final project = (data['project'] as Map<String, dynamic>?) ?? data;
    return RavelryProject.fromJson(project);
  }

  // ── 스태시 생성 ───────────────────────────────────────────────────────────────
  /// 이슈 #644 — 생성된 stash entry를 반환하도록 변경. id 캡처 후 YarnModel.ravelryStashId에 저장.
  /// Phase 7: yarnId 추가 — Ravelry 공식 yarn DB 매핑을 위한 yarn_id 전달.
  Future<RavelryStashEntry> createStash({
    required String name,
    String? colorwayName,
    String? notes,
    int stashStatusId = 1,
    int? yarnId,
  }) async {
    final data = await _post('/ravelryCreateStash', {
      'stash': {
        'name': name,
        if (colorwayName != null && colorwayName.isNotEmpty) 'colorway_name': colorwayName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'stash_status_id': stashStatusId,
        if (yarnId != null && yarnId > 0) 'yarn_id': yarnId,
      },
    });
    final stashJson = (data['stash'] as Map<String, dynamic>?) ?? data;
    return RavelryStashEntry.fromJson(stashJson);
  }

  // ── 이슈 #644 Phase 7 — Ravelry yarn DB 검색/상세 ───────────────────────────
  /// Ravelry 글로벌 yarn DB(10만+ 항목) 검색.
  Future<List<RavelryYarnSearchItem>> searchYarns(
    String query, {
    int page = 1,
    int pageSize = 25,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final data = await _get('/ravelryYarnsSearch', queryParams: {
      'query': trimmed,
      'page': '$page',
      'page_size': '$pageSize',
    });
    final yarns = (data['yarns'] as List<dynamic>?) ??
        (data['results'] as List<dynamic>?) ??
        const [];
    return yarns
        .whereType<Map<String, dynamic>>()
        .map(RavelryYarnSearchItem.fromJson)
        .toList();
  }

  /// Ravelry yarn 상세 조회.
  Future<RavelryYarnDetail> getYarn(int yarnId) async {
    final data = await _get('/ravelryYarnDetail', queryParams: {'id': '$yarnId'});
    final yarn = (data['yarn'] as Map<String, dynamic>?) ?? data;
    return RavelryYarnSearchItem.fromJson(yarn);
  }

  // ── HTTP 헬퍼 ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? queryParams}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You must be signed in to use Ravelry.');
    final idToken = await user.getIdToken(true);
    var uri = Uri.parse('$_kFunctionsBase$path');
    if (queryParams != null) uri = uri.replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $idToken'});
    if (response.statusCode == 401 || response.statusCode == 403) {
      _ref.read(ravelryAuthProvider.notifier).clearSession();
      throw Exception('Ravelry 연결이 끊겼습니다. 다시 연결해 주세요.');
    }
    if (response.statusCode != 200) {
      throw Exception('Ravelry API error ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? queryParams,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You must be signed in to use Ravelry.');
    final idToken = await user.getIdToken(true);
    var uri = Uri.parse('$_kFunctionsBase$path');
    if (queryParams != null) uri = uri.replace(queryParameters: queryParams);
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      _ref.read(ravelryAuthProvider.notifier).clearSession();
      throw Exception('Ravelry 연결이 끊겼습니다. 다시 연결해 주세요.');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      String errMsg;
      try {
        final errData = jsonDecode(response.body) as Map<String, dynamic>;
        errMsg = (errData['error'] as String?) ?? response.body;
      } catch (_) {
        errMsg = response.body;
      }
      throw Exception('Ravelry 오류: $errMsg');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

final ravelryRepositoryProvider = Provider<RavelryRepository?>((ref) {
  final auth = ref.watch(ravelryAuthProvider);
  if (!auth.isLoggedIn) return null;
  return RavelryRepository(ref);
});

final ravelryStashProvider = FutureProvider<List<RavelryStashEntry>>((ref) async {
  final auth = ref.watch(ravelryAuthProvider);
  final repo = ref.watch(ravelryRepositoryProvider);
  if (repo == null || !auth.isLoggedIn) return [];
  return repo.fetchStash();
});

final ravelryLibraryProvider = FutureProvider<List<RavelryLibraryPattern>>((ref) async {
  final auth = ref.watch(ravelryAuthProvider);
  final repo = ref.watch(ravelryRepositoryProvider);
  if (repo == null || !auth.isLoggedIn) return [];
  return repo.fetchLibrary();
});

final ravelryProjectsProvider = FutureProvider<List<RavelryProject>>((ref) async {
  final auth = ref.watch(ravelryAuthProvider);
  final repo = ref.watch(ravelryRepositoryProvider);
  if (repo == null || !auth.isLoggedIn) return [];
  return repo.fetchProjects();
});
