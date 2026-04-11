import 'dart:convert';
import 'dart:math';

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

  Future<PriceHistoryPayload> resolveWithBigGo(
    String historyId,
    int days,
  ) async {
    final response = await http.post(
      Uri.parse('https://biggo.com.tw/api/v1/spa/product/history'),
      headers: const {
        'Content-Type': 'application/json',
        'region': 'tw',
        'referer': 'https://biggo.com.tw/',
      },
      body: jsonEncode({'history_id': historyId, 'days': days}),
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final message = payload['message']?.toString() ??
          payload['error']?.toString() ??
          'BigGo API failed';
      throw Exception(message);
    }

    final history = (payload['price_history'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PricePoint.fromJson)
        .toList();

    if (history.isEmpty) {
      throw Exception('BigGo 無歷史資料');
    }

    final title = (payload['title'] as String?) ?? 'BigGo $historyId';
    return _buildPayloadFromHistory(
      title: title,
      history: history,
      sourceUrl: 'https://biggo.com.tw/',
    );
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

  PriceHistoryPayload _buildPayloadFromHistory({
    required String title,
    required List<PricePoint> history,
    required String sourceUrl,
  }) {
    final ordered = [...history]..sort((a, b) => a.x.compareTo(b.x));
    final stats = _computeStats(ordered);
    final highlights = _buildHighlights(ordered, stats.medianPrice);
    final subtitle = _buildSubtitle(ordered);

    return PriceHistoryPayload(
      title: title,
      subtitle: subtitle,
      sourceUrl: sourceUrl,
      history: ordered,
      sampledHistory: ordered,
      highlights: highlights,
      stats: stats,
    );
  }

  String _buildSubtitle(List<PricePoint> history) {
    if (history.isEmpty) return '';
    final start =
        DateTime.fromMillisecondsSinceEpoch(history.first.x, isUtc: true);
    final end =
        DateTime.fromMillisecondsSinceEpoch(history.last.x, isUtc: true);
    return '${_fmtDate(start)} to ${_fmtDate(end)}, ${history.length} points';
  }

  String _fmtDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, PricePoint> _buildHighlights(
    List<PricePoint> history,
    double medianPrice,
  ) {
    final oldest = history.first;
    final latest = history.last;
    final highest =
        history.reduce((a, b) => a.y >= b.y ? a : b);
    final lowest =
        history.reduce((a, b) => a.y <= b.y ? a : b);
    final median = history.reduce((a, b) {
      final diffA = (a.y - medianPrice).abs();
      final diffB = (b.y - medianPrice).abs();
      return diffA <= diffB ? a : b;
    });

    return {
      'oldest': oldest,
      'latest': latest,
      'highest': highest,
      'lowest': lowest,
      'median': median,
    };
  }

  PriceStats _computeStats(List<PricePoint> history) {
    final prices = history.map((p) => p.y).toList();
    final latest = history.last;
    final oldest = history.first;
    final highest = prices.reduce(max);
    final lowest = prices.reduce(min);
    final average = prices.reduce((a, b) => a + b) / prices.length;
    final sorted = [...prices]..sort();
    final middle = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[middle].toDouble()
        : (sorted[middle - 1] + sorted[middle]) / 2;
    final interval = _diffYmd(
      history.firstWhere((p) => p.y == lowest).x,
      history.last.x,
    );

    return PriceStats(
      latestPrice: latest.y,
      oldestPrice: oldest.y,
      highestPrice: highest,
      lowestPrice: lowest,
      averagePrice: average,
      medianPrice: median,
      latestMinusLowest: latest.y - lowest,
      interval: interval,
    );
  }

  PriceInterval _diffYmd(int startMs, int endMs) {
    var start =
        DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true);
    var end = DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true);
    if (end.isBefore(start)) {
      final temp = start;
      start = end;
      end = temp;
    }

    var years = end.year - start.year;
    var months = end.month - start.month;
    var days = end.day - start.day;

    if (days < 0) {
      months -= 1;
      final prevMonth = DateTime(end.year, end.month, 0);
      days += prevMonth.day;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    return PriceInterval(years: years, months: months, days: days);
  }
}
