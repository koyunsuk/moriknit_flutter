import 'dart:convert';

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
        (data['patterns'] as List<dynamic>?) ??
        (data['results'] as List<dynamic>?) ??
        const [];
    return volumes
        .map((e) => RavelryLibraryPattern.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RavelryProject>> fetchProjects() async {
    final data = await _get('/ravelryProjects');
    final projects = (data['projects'] as List<dynamic>?) ??
        (data['results'] as List<dynamic>?) ??
        const [];
    return projects
        .map((e) => RavelryProject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to use Ravelry.');
    }

    final idToken = await user.getIdToken(true);
    final response = await http.get(
      Uri.parse('$_kFunctionsBase$path'),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Ravelry API error ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

final ravelryRepositoryProvider = Provider<RavelryRepository?>((ref) {
  final auth = ref.watch(ravelryAuthProvider);
  if (!auth.isLoggedIn) return null;
  return RavelryRepository();
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
