import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/oil_price_point.dart';

const String kOqdSourceUrl = 'https://www.gulfmerc.com/';

@pragma('vm:entry-point')
Future<void> syncOilPriceBackground() async {
  await OilPriceService().syncScheduled();
}

class OilPriceSyncResult {
  final bool fetched;
  final String message;
  final OilPricePoint? point;

  const OilPriceSyncResult({
    required this.fetched,
    required this.message,
    this.point,
  });
}

class OilPriceService {
  OilPriceService._();

  static final OilPriceService _instance = OilPriceService._();

  factory OilPriceService() => _instance;

  static const String _historyKey = 'oil_price_history_v1';
  static const String _lastScheduledFetchKey = 'oil_price_last_scheduled_fetch';

  Timer? _timer;

  Future<void> init() async {
    await syncOnAppLaunch();
    _startForegroundScheduler();
  }

  Future<OilPriceSyncResult> syncOnAppLaunch() {
    return sync(force: true, allowBeforeOnePm: true);
  }

  Future<OilPriceSyncResult> syncScheduled() {
    return sync(force: false, allowBeforeOnePm: false);
  }

  Future<OilPriceSyncResult> sync({
    required bool force,
    required bool allowBeforeOnePm,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    if (!force && !allowBeforeOnePm) {
      if (now.hour < 13) {
        return const OilPriceSyncResult(
          fetched: false,
          message: 'Waiting for the daily 1 PM fetch window.',
        );
      }

      if (prefs.getString(_lastScheduledFetchKey) == todayKey) {
        return const OilPriceSyncResult(
          fetched: false,
          message: 'Already fetched the OQD marker price today.',
        );
      }
    }

    final point = await fetchLatestPrice();
    await _upsertHistory(point);

    if (!force && !allowBeforeOnePm) {
      await prefs.setString(_lastScheduledFetchKey, todayKey);
    }

    return OilPriceSyncResult(
      fetched: true,
      message: 'Fetched ${point.price.toStringAsFixed(2)} for ${DateFormat('yyyy/MM/dd').format(point.marketDate)}.',
      point: point,
    );
  }

  Future<List<OilPricePoint>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }

    final history = decoded
        .whereType<Map<String, dynamic>>()
        .map(OilPricePoint.fromJson)
        .toList()
      ..sort((a, b) => a.marketDate.compareTo(b.marketDate));
    return history;
  }

  Future<OilPricePoint?> latestStoredPoint() async {
    final history = await loadHistory();
    if (history.isEmpty) {
      return null;
    }
    return history.last;
  }

  Future<OilPricePoint> fetchLatestPrice() async {
    final html = await _downloadHtml(kOqdSourceUrl);
    return parseMarkerPriceFromHtml(html);
  }

  Future<void> _upsertHistory(OilPricePoint point) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    final marketKey = DateFormat('yyyy-MM-dd').format(point.marketDate);

    final index = history.indexWhere(
      (item) => DateFormat('yyyy-MM-dd').format(item.marketDate) == marketKey,
    );

    if (index >= 0) {
      history[index] = point;
    } else {
      history.add(point);
    }

    history.sort((a, b) => a.marketDate.compareTo(b.marketDate));
    final encoded = jsonEncode(history.map((item) => item.toJson()).toList());
    await prefs.setString(_historyKey, encoded);
  }

  void _startForegroundScheduler() {
    _timer ??= Timer.periodic(const Duration(minutes: 30), (_) async {
      try {
        await syncScheduled();
      } catch (_) {
        // Keep the scheduler quiet; the UI can surface errors on demand.
      }
    });
  }

  Future<String> _downloadHtml(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'SubscriptionManager/1.0.0 OilMonitor',
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Failed to fetch OQD marker page: HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      return response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  static OilPricePoint parseMarkerPriceFromHtml(String html) {
    final plainText = _htmlToText(html);

    final topBannerPattern = RegExp(
      r'OQD Marker Price\s+([A-Za-z]+\s+\d{1,2},\s*\d{4})\s+is\s+([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    );
    final summaryPattern = RegExp(
      r'OQD Daily Marker Price\s+([0-9]+(?:\.[0-9]+)?)\s+(\d{1,2}\s+[A-Za-z]{3}[-,]\s*\d{4})',
      caseSensitive: false,
    );

    final topBannerMatch = topBannerPattern.firstMatch(plainText);
    if (topBannerMatch != null) {
      final marketDate = _parseMarketDate(topBannerMatch.group(1)!);
      final price = double.parse(topBannerMatch.group(2)!);
      return OilPricePoint(
        marketDate: marketDate,
        price: price,
        fetchedAt: DateTime.now(),
        sourceUrl: kOqdSourceUrl,
      );
    }

    final summaryMatch = summaryPattern.firstMatch(plainText);
    if (summaryMatch != null) {
      final price = double.parse(summaryMatch.group(1)!);
      final marketDate = _parseMarketDate(summaryMatch.group(2)!);
      return OilPricePoint(
        marketDate: marketDate,
        price: price,
        fetchedAt: DateTime.now(),
        sourceUrl: kOqdSourceUrl,
      );
    }

    throw const FormatException(
      'Unable to locate OQD Daily Marker Price on the Gulf Mercantile Exchange homepage.',
    );
  }

  static String _htmlToText(String html) {
    return html
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
        .replaceAll('&amp;', '&')
        .replaceAll('&#8217;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static DateTime _parseMarketDate(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    const formats = [
      'MMMM d, yyyy',
      'd MMM-yyyy',
      'd MMM, yyyy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format, 'en_US').parseStrict(normalized);
      } catch (_) {
        // Try the next supported format.
      }
    }

    throw FormatException('Unsupported OQD market date format: $value');
  }
}
