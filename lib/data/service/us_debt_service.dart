import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/us_debt_point.dart';

class USDebtSnapshot {
  final USDebtPoint point;
  final double ratePerSecond;
  final String sourceUrl;

  const USDebtSnapshot({
    required this.point,
    required this.ratePerSecond,
    required this.sourceUrl,
  });
}

class USDebtService {
  static const String _sourceUrl = 'https://www.usdebtclock.org/';
  static const String _historyKey = 'us_debt_history_v1';
  static const int _maxHistoryItems = 120;

  Future<USDebtSnapshot> fetchLatestDebt() async {
    final html = await _downloadHtml();
    final fieldId = _extractDebtFieldId(html);
    final formula = _extractFormula(html, fieldId);

    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch / 1000;
    final debtValue =
        formula.baseValue + (nowSeconds - formula.anchorSeconds) * formula.ratePerSecond;

    final point = USDebtPoint(
      capturedAt: now,
      debt: debtValue,
    );

    await _savePoint(point);

    return USDebtSnapshot(
      point: point,
      ratePerSecond: formula.ratePerSecond,
      sourceUrl: _sourceUrl,
    );
  }

  Future<List<USDebtPoint>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_historyKey) ?? const [];

    final items = <USDebtPoint>[];
    for (final raw in rawItems) {
      try {
        items.add(
          USDebtPoint.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Ignore malformed cached rows.
      }
    }

    items.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return items;
  }

  Future<void> _savePoint(USDebtPoint point) async {
    final history = await loadHistory();

    if (history.isNotEmpty) {
      final previous = history.last;
      final minutesSinceLast =
          point.capturedAt.difference(previous.capturedAt).inMinutes;
      final debtDelta = (point.debt - previous.debt).abs();

      if (minutesSinceLast < 5 && debtDelta < 5000) {
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
    client.userAgent = 'SubscriptionManager/1.0.0';

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

  String _extractDebtFieldId(String html) {
    final match = RegExp(
      r'<div id="layer29"><span id="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);

    if (match == null) {
      throw const FormatException('Unable to locate US National Debt field.');
    }

    return match.group(1)!;
  }

  _DebtFormula _extractFormula(String html, String fieldId) {
    final escapedFieldId = RegExp.escape(fieldId);
    final pattern =
        'var\\s+$escapedFieldId\\s*=\\s*([^;]+);'
        '\\s*var\\s+([A-Za-z0-9_]+)\\s*=\\s*([^;]+);'
        '\\s*var\\s+([A-Za-z0-9_]+)\\s*=\\s*([^;]+);'
        '.*?document\\.getElementById\\s*\\(\\s*[\\\'"]'
        '$escapedFieldId'
        '[\\\'"]\\s*\\)';
    final match = RegExp(pattern, dotAll: true).firstMatch(html);

    if (match == null) {
      throw const FormatException('Unable to parse US National Debt formula.');
    }

    final baseValue = _evaluateExpression(match.group(1)!);
    final ratePerSecond = _evaluateExpression(match.group(3)!);
    final anchorSeconds = _evaluateExpression(match.group(5)!);

    return _DebtFormula(
      baseValue: baseValue,
      ratePerSecond: ratePerSecond,
      anchorSeconds: anchorSeconds,
    );
  }

  double _evaluateExpression(String expression) {
    final sanitized = expression
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'[^0-9+\-*/. ]'), ' ')
        .replaceAll(RegExp(r'\s+'), '');

    if (sanitized.isEmpty) {
      throw FormatException('Unsupported expression: $expression');
    }

    final tokenMatches = RegExp(r'([*/]?)(-?\d+(?:\.\d+)?)').allMatches(sanitized);
    if (tokenMatches.isEmpty) {
      throw FormatException('Unsupported expression: $expression');
    }

    double? result;
    for (final token in tokenMatches) {
      final op = token.group(1)!;
      final value = double.parse(token.group(2)!);
      if (result == null) {
        result = value;
        continue;
      }

      if (op == '*') {
        result *= value;
      } else if (op == '/') {
        result /= value;
      } else {
        result += value;
      }
    }

    return result!;
  }
}

class _DebtFormula {
  final double baseValue;
  final double ratePerSecond;
  final double anchorSeconds;

  const _DebtFormula({
    required this.baseValue,
    required this.ratePerSecond,
    required this.anchorSeconds,
  });
}
