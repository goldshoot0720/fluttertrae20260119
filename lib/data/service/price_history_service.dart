import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/price_history_models.dart';

class PriceHistoryService {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'PRICE_HISTORY_API',
    defaultValue: 'http://127.0.0.1:8765',
  );

  String get baseUrl => _defaultBaseUrl;

  Uri _apiUri(String path) {
    final normalized = baseUrl.isEmpty ? 'http://127.0.0.1:8765' : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<PriceHistoryPayload> resolve(String url, int days) async {
    final response = await http.post(
      _apiUri('/api/resolve'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url, 'days': days}),
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final message = payload['error']?.toString() ?? 'Resolve failed';
      throw Exception(message);
    }
    return PriceHistoryPayload.fromJson(payload);
  }

  Future<List<RecentPriceUrl>> fetchRecent() async {
    final response = await http.get(_apiUri('/api/recent'));
    if (response.statusCode >= 400) {
      throw Exception('Failed to load recent URLs.');
    }
    final data = jsonDecode(response.body);
    if (data is! List) {
      return [];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(RecentPriceUrl.fromJson)
        .toList();
  }

  Future<void> deleteRecent(int index) async {
    final response = await http.delete(_apiUri('/api/recent/$index'));
    if (response.statusCode >= 400) {
      throw Exception('Failed to delete recent URL.');
    }
  }
}
