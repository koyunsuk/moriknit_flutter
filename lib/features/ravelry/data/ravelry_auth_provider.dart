import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _kFunctionsBase = String.fromEnvironment(
  'RAVELRY_BACKEND_BASE',
  defaultValue: 'https://us-central1-moriknit-ceea9.cloudfunctions.net',
);

class RavelryAuthState {
  final bool isLoggedIn;
  final String? username;
  final bool isLoading;
  final String? error;

  const RavelryAuthState({
    this.isLoggedIn = false,
    this.username,
    this.isLoading = false,
    this.error,
  });

  RavelryAuthState copyWith({
    bool? isLoggedIn,
    String? username,
    bool? isLoading,
    String? error,
  }) {
    return RavelryAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RavelryAuthNotifier extends StateNotifier<RavelryAuthState> {
  RavelryAuthNotifier() : super(const RavelryAuthState()) {
    refreshSession();
  }

  Future<void> refreshSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = const RavelryAuthState();
      return;
    }

    try {
      final response = await _authorizedGet('/ravelrySession');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      state = state.copyWith(
        isLoggedIn: data['isLoggedIn'] as bool? ?? false,
        username: data['username'] as String?,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      debugPrint('Failed to refresh Ravelry session: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to refresh Ravelry session.');
    }
  }

  Future<void> login() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authorizedPost('/ravelryAuthStart');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final authUrl = data['authUrl'] as String?;
      if (authUrl == null || authUrl.isEmpty) {
        throw Exception('Missing Ravelry authorization URL.');
      }

      state = state.copyWith(isLoading: false);
      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        state = state.copyWith(error: 'Failed to open the Ravelry login page.');
      }
    } catch (e) {
      debugPrint('Ravelry login start failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start Ravelry login.',
      );
    }
  }

  Future<void> handleOAuthCallback(Uri uri) async {
    final status = uri.queryParameters['status'];
    final message = uri.queryParameters['message'];

    if (status == 'success') {
      await refreshSession();
      return;
    }

    state = state.copyWith(
      isLoading: false,
      error: (message != null && message.isNotEmpty)
          ? message
          : 'Ravelry login failed.',
    );
  }

  Future<void> logout() async {
    try {
      await _authorizedPost('/ravelryDisconnect');
    } catch (e) {
      debugPrint('Ravelry disconnect failed: $e');
    }
    state = const RavelryAuthState();
  }

  Future<http.Response> _authorizedGet(String path) async {
    final token = await _requireFirebaseIdToken();
    final response = await http.get(
      Uri.parse('$_kFunctionsBase$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _throwIfFailed(response);
    return response;
  }

  Future<http.Response> _authorizedPost(String path) async {
    final token = await _requireFirebaseIdToken();
    final response = await http.post(
      Uri.parse('$_kFunctionsBase$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _throwIfFailed(response);
    return response;
  }

  Future<String> _requireFirebaseIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to connect Ravelry.');
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw Exception('Failed to get Firebase ID token.');
    }
    return token;
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    try {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final error = map['error'];
      if (error is String && error.isNotEmpty) {
        throw Exception(error);
      }
    } catch (_) {}

    throw Exception('Ravelry request failed: ${response.statusCode}');
  }
}

final ravelryAuthProvider =
    StateNotifierProvider<RavelryAuthNotifier, RavelryAuthState>(
  (ref) => RavelryAuthNotifier(),
);
