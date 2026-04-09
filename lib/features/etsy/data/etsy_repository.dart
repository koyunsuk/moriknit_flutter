import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/etsy_models.dart';
import 'etsy_auth_provider.dart';

const _kApiBase = 'https://openapi.etsy.com/v3/application';
const _kClientId = 'sy3q9x9d1bp2g0136w3jd1ve';

class EtsyRepository {
  final String accessToken;
  final String clientId;

  const EtsyRepository({required this.accessToken, required this.clientId});

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_kApiBase$path').replace(queryParameters: query);
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $accessToken',
      'x-api-key': clientId,
    });
    if (response.statusCode != 200) {
      throw Exception('Etsy API error ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<EtsyListing>> fetchActiveListings(int shopId) async {
    final data = await _get(
      '/shops/$shopId/listings/active',
      query: {'includes': 'Images', 'limit': '25'},
    );
    final results = (data['results'] as List<dynamic>?) ?? [];
    return results
        .map((e) => EtsyListing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EtsyShop?> fetchMyShop(String userId) async {
    try {
      final data = await _get('/users/$userId/shops');
      final results = (data['results'] as List<dynamic>?) ?? [];
      if (results.isEmpty) return null;
      return EtsyShop.fromJson(results.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

final etsyRepositoryProvider = Provider<EtsyRepository?>((ref) {
  final auth = ref.watch(etsyAuthProvider);
  if (!auth.isLoggedIn || auth.accessToken == null) return null;
  return EtsyRepository(
    accessToken: auth.accessToken!,
    clientId: _kClientId,
  );
});

final etsyShopProvider = FutureProvider<EtsyShop?>((ref) async {
  final auth = ref.watch(etsyAuthProvider);
  final repo = ref.watch(etsyRepositoryProvider);
  if (repo == null || auth.userId == null) return null;
  return repo.fetchMyShop(auth.userId!);
});

final etsyListingsProvider = FutureProvider<List<EtsyListing>>((ref) async {
  final repo = ref.watch(etsyRepositoryProvider);
  final shop = ref.watch(etsyShopProvider).valueOrNull;
  if (repo == null || shop == null) return [];
  return repo.fetchActiveListings(shop.shopId);
});
