import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/oil_price_point.dart';

class OilPriceSnapshot {
  final OilPricePoint point;
  final String sourceUrl;

  const OilPriceSnapshot({
    required this.point,
    required this.sourceUrl,
  });
}

class OilPriceService {
  static const String _sourceUrl = 'https://www.gulfmerc.com/';
  static const String _historyKey = 'oil_price_history_v1';
  static const int _maxHistoryItems = 120;

  Future<OilPriceSnapshot> fetchLatestPrice() async {
    final html = await _downloadHtml();
    final parsed = _extractMarkerPrice(html);
    final point = OilPricePoint(
      capturedAt: DateTime.now(),
      price: parsed.price,
      publishedLabel: parsed.publishedLabel,
    );

    await _savePoint(point);

    return OilPriceSnapshot(
      point: point,
      sourceUrl: _sourceUrl,
    );
  }

  Future<List<OilPricePoint>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_historyKey) ?? const [];
    final items = <OilPricePoint>[];

    for (final raw in rawItems) {
      try {
        items.add(
          OilPricePoint.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Ignore malformed cached rows.
      }
    }

    items.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return items;
  }

  Future<void> _savePoint(OilPricePoint point) async {
    final history = await loadHistory();

    if (history.isNotEmpty) {
      final previous = history.last;
      final minutesSinceLast =
          point.capturedAt.difference(previous.capturedAt).inMinutes;
      final priceDelta = (point.price - previous.price).abs();

      if (minutesSinceLast < 30 &&
          priceDelta < 0.001 &&
          point.publishedLabel == previous.publishedLabel) {
        return;
      }
    }

    final updated = [...history, point];
    if (updated.length > _maxHistoryItems) {
      updated.removeRange(0, updated.length - _maxHistoryItems);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _historyKey,
      updated.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<String> _downloadHtml() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.userAgent = 'AtlasMonitor/1.0.3';

    try {
      final request = await client.getUrl(Uri.parse(_sourceUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Unexpected status ${response.statusCode} from $_sourceUrl',
        );
      }

      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  _OilPriceParseResult _extractMarkerPrice(String html) {
    final plainText = html
        .replaceAll(
          RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final match = RegExp(
      r'OQD Daily Marker Price\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]{1,2}\s+[A-Za-z]{3}[-,]\s*[0-9]{4})',
      caseSensitive: false,
    ).firstMatch(plainText);

    if (match == null) {
      throw const FormatException(
        'Unable to parse OQD Daily Marker Price from gulfmerc.com.',
      );
    }

    return _OilPriceParseResult(
      price: double.parse(match.group(1)!),
      publishedLabel: match.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  }
}

class _OilPriceParseResult {
  final double price;
  final String publishedLabel;

  const _OilPriceParseResult({
    required this.price,
    required this.publishedLabel,
  });
}
