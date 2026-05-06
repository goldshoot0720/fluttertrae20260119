import 'package:http/http.dart' as http;

import '../model/feng_bro_finance_models.dart';

class FengBroFinanceService {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

  static const List<FengBroFinanceInstrument> instruments = [
    FengBroFinanceInstrument(
      id: 'taiwan-weighted',
      name: '加權指數',
      symbol: 'TAIEX',
      url: 'https://tw.stock.yahoo.com/s/tse.php',
      category: 'Taiwan Index',
      unit: 'TWD',
    ),
    FengBroFinanceInstrument(
      id: 'tsmc',
      name: '台積電',
      symbol: '2330.TW',
      url: 'https://tw.stock.yahoo.com/quote/2330.TW',
      category: 'Taiwan Stock',
      unit: 'TWD',
    ),
    FengBroFinanceInstrument(
      id: 'nikkei-225',
      name: 'Nikkei 225 Index',
      symbol: '.N225',
      url: 'https://www.cnbc.com/quotes/.N225',
      category: 'Asia Index',
      unit: 'JPY',
    ),
    FengBroFinanceInstrument(
      id: 'kospi',
      name: 'KOSPI Index',
      symbol: '.KS11',
      url: 'https://www.cnbc.com/quotes/.KS11?qsearchterm=kospi',
      category: 'Asia Index',
      unit: 'KRW',
    ),
    FengBroFinanceInstrument(
      id: 'brent',
      name: 'ICE Brent Crude',
      symbol: '@LCO.1',
      url: 'https://www.cnbc.com/quotes/@LCO.1',
      category: 'Commodity',
      unit: 'USD',
    ),
    FengBroFinanceInstrument(
      id: 'us-30y',
      name: 'U.S. 30 Year Treasury',
      symbol: 'US30Y',
      url: 'https://www.cnbc.com/quotes/US30Y',
      category: 'Rates',
      unit: '%',
    ),
    FengBroFinanceInstrument(
      id: 'gold',
      name: 'Gold COMEX',
      symbol: '@GC.1',
      url: 'https://www.cnbc.com/quotes/@GC.1',
      category: 'Commodity',
      unit: 'USD',
    ),
    FengBroFinanceInstrument(
      id: 'dow',
      name: 'Dow Jones Industrial Average',
      symbol: '.DJI',
      url: 'https://www.cnbc.com/quotes/.DJI',
      category: 'US Index',
      unit: 'USD',
    ),
    FengBroFinanceInstrument(
      id: 'sp-500',
      name: 'S&P 500 Index',
      symbol: '.SPX',
      url: 'https://www.cnbc.com/quotes/.SPX',
      category: 'US Index',
      unit: 'USD',
    ),
    FengBroFinanceInstrument(
      id: 'nasdaq',
      name: 'NASDAQ Composite',
      symbol: '.IXIC',
      url: 'https://www.cnbc.com/quotes/.IXIC',
      category: 'US Index',
      unit: 'USD',
    ),
    FengBroFinanceInstrument(
      id: 'vix',
      name: 'CBOE Volatility Index',
      symbol: '.VIX',
      url: 'https://www.cnbc.com/quotes/.VIX',
      category: 'Volatility',
      unit: 'Index',
    ),
    FengBroFinanceInstrument(
      id: 'bitcoin',
      name: 'Bitcoin/USD Coin Metrics',
      symbol: 'BTC.CM=',
      url: 'https://www.cnbc.com/quotes/BTC.CM=',
      category: 'Crypto',
      unit: 'USD',
    ),
    FengBroFinanceInstrument(
      id: 'ether',
      name: 'Ether/USD Coin Metrics',
      symbol: 'ETH.CM=',
      url: 'https://www.cnbc.com/quotes/ETH.CM=',
      category: 'Crypto',
      unit: 'USD',
    ),
  ];

  Future<FengBroFinanceSummary> fetchQuotes() async {
    final fetchedAt = DateTime.now();
    final quotes = await Future.wait(
      instruments.map((instrument) => _fetchQuote(instrument, fetchedAt)),
    );
    return FengBroFinanceSummary(fetchedAt: fetchedAt, quotes: quotes);
  }

  Future<FengBroFinanceQuote> _fetchQuote(
    FengBroFinanceInstrument instrument,
    DateTime fetchedAt,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(instrument.url),
        headers: const {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );
      if (response.statusCode >= 400) {
        throw Exception('CNBC 回應 ${response.statusCode}');
      }
      if (instrument.url.contains('tw.stock.yahoo.com')) {
        return parseYahooQuoteFromHtml(instrument, response.body, fetchedAt);
      }
      return parseCnbcQuoteFromHtml(instrument, response.body, fetchedAt);
    } catch (error) {
      return FengBroFinanceQuote(
        instrument: instrument,
        last: null,
        change: null,
        changePercent: null,
        dayHigh: null,
        dayLow: null,
        week52High: null,
        week52Low: null,
        fetchedAt: fetchedAt,
        warning: error.toString(),
      );
    }
  }

  static FengBroFinanceQuote parseCnbcQuoteFromHtml(
    FengBroFinanceInstrument instrument,
    String html,
    DateTime fetchedAt,
  ) {
    final text = _htmlToText(html);
    return FengBroFinanceQuote(
      instrument: instrument,
      last: _extractLast(text),
      change: _extractChange(text),
      changePercent: _extractChangePercent(text),
      dayHigh: _extractNumberAfterLabel(text, 'Day High'),
      dayLow: _extractNumberAfterLabel(text, 'Day Low'),
      week52High: _extractNumberAfterLabel(text, '52 Week High'),
      week52Low: _extractNumberAfterLabel(text, '52 Week Low'),
      fetchedAt: fetchedAt,
    );
  }

  static FengBroFinanceQuote parseYahooQuoteFromHtml(
    FengBroFinanceInstrument instrument,
    String html,
    DateTime fetchedAt,
  ) {
    final text = _htmlToText(html);
    return FengBroFinanceQuote(
      instrument: instrument,
      last: _extractNumberAfterChineseLabel(text, '成交') ?? _extractLast(text),
      change: _extractNumberAfterChineseLabel(text, '漲跌'),
      changePercent: _extractNumberAfterChineseLabel(text, '漲跌幅'),
      dayHigh: _extractNumberAfterChineseLabel(text, '最高'),
      dayLow: _extractNumberAfterChineseLabel(text, '最低'),
      week52High: null,
      week52Low: null,
      fetchedAt: fetchedAt,
      signalOverride: _extractRecordSignal(text),
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
        .replaceAll(RegExp(r'<[^>]+>'), '\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
  }

  static double? _extractLast(String text) {
    final lines = text.split('\n').map((line) => line.trim()).toList();
    final index = lines.indexWhere((line) => RegExp(r'^Last\b').hasMatch(line));
    if (index == -1) {
      return _extractNumberAfterLabel(text, 'Last');
    }

    for (var i = index + 1; i < lines.length && i <= index + 8; i++) {
      final line = lines[i];
      if (line.isEmpty ||
          RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}').hasMatch(line) ||
          RegExp(r'^\d{1,2}:\d{2}').hasMatch(line)) {
        continue;
      }
      final value = _firstNumber(line);
      if (value != null) return value;
    }

    final section = lines.skip(index).take(10).join(' ');
    return _firstNumber(section);
  }

  static double? _extractChange(String text) {
    final lastSection = _lastSection(text);
    final match = RegExp(
      r'([+-]\d[\d,]*(?:\.\d+)?)\s*\(',
    ).firstMatch(lastSection);
    return _parseNumber(match?.group(1));
  }

  static double? _extractChangePercent(String text) {
    final lastSection = _lastSection(text);
    final match = RegExp(
      r'\(([+-]?\d[\d,]*(?:\.\d+)?)%\)',
    ).firstMatch(lastSection);
    return _parseNumber(match?.group(1));
  }

  static String _lastSection(String text) {
    final start = text.indexOf(RegExp(r'\bLast\b'));
    if (start == -1) return text;
    final end = text.indexOf('52 week range', start);
    return end == -1 ? text.substring(start) : text.substring(start, end);
  }

  static double? _extractNumberAfterLabel(String text, String label) {
    final escaped = RegExp.escape(label);
    final match = RegExp(
      '$escaped\\s+([-+]?\\d[\\d,]*(?:\\.\\d+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    return _parseNumber(match?.group(1));
  }

  static double? _extractNumberAfterChineseLabel(String text, String label) {
    final escaped = RegExp.escape(label);
    final suffixGuard = label == '漲跌' ? '(?!幅)' : '';
    final match = RegExp(
      '$escaped$suffixGuard\\s*[:：]?\\s*([-+]?\\d[\\d,]*(?:\\.\\d+)?)(?:%|％)?',
    ).firstMatch(text);
    return _parseNumber(match?.group(1));
  }

  static FengBroFinanceSignal? _extractRecordSignal(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'創(?:盤中|收盤|歷史)?新高|創新高|再創高|續創高').hasMatch(compact)) {
      return FengBroFinanceSignal.recordHigh;
    }
    if (RegExp(r'創(?:盤中|收盤|歷史)?新低|創新低|再創低|續創低').hasMatch(compact)) {
      return FengBroFinanceSignal.recordLow;
    }
    return null;
  }

  static double? _firstNumber(String value) {
    final match = RegExp(r'[-+]?\d[\d,]*(?:\.\d+)?').firstMatch(value);
    return _parseNumber(match?.group(0));
  }

  static double? _parseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '').trim());
  }
}
