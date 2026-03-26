import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/model/us_debt_point.dart';
import '../data/service/us_debt_service.dart';

class USDebtScreen extends StatefulWidget {
  const USDebtScreen({super.key});

  @override
  State<USDebtScreen> createState() => _USDebtScreenState();
}

class _USDebtScreenState extends State<USDebtScreen> {
  final USDebtService _service = USDebtService();

  USDebtSnapshot? _snapshot;
  List<USDebtPoint> _history = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      USDebtSnapshot? snapshot = _snapshot;
      if (refresh || snapshot == null) {
        snapshot = await _service.fetchLatestDebt();
      }
      final history = await _service.loadHistory();

      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _service.fetchLatestDebt();
      final history = await _service.loadHistory();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _history = history;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _openSource() async {
    final url = _snapshot?.sourceUrl ?? 'https://www.usdebtclock.org/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _snapshot?.point ?? (_history.isNotEmpty ? _history.last : null);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D20),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'US Debt',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _isRefreshing ? null : _refresh,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16213E),
                foregroundColor: Colors.white,
              ),
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('更新'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
                  _buildHeroCard(latest),
                  const SizedBox(height: 16),
                  _buildChartCard(),
                  const SizedBox(height: 16),
                  _buildHistoryCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard(USDebtPoint? latest) {
    final debtFormat = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 0,
    );
    final latestValue = latest == null ? '--' : debtFormat.format(latest.debt.round());
    final updatedAt = latest == null
        ? '--'
        : DateFormat('yyyy/MM/dd HH:mm').format(latest.capturedAt.toLocal());
    final rateLabel = _snapshot == null
        ? '--'
        : '${NumberFormat.decimalPattern('en_US').format(_snapshot!.ratePerSecond.round())} / sec';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163042), Color(0xFF1E2748), Color(0xFF302347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFF3E527A).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFF80DEEA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'US National Debt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            latestValue,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Last synced: $updatedAt',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB9C8DE),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated growth rate: $rateLabel',
            style: const TextStyle(fontSize: 13, color: Color(0xFF92A5C6)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _DebtTag(
                icon: Icons.public_rounded,
                label: 'Source: usdebtclock.org',
              ),
              _DebtTag(
                icon: Icons.open_in_new_rounded,
                label: 'Open source site',
                onTap: _openSource,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final recent = _history.length > 30 ? _history.sublist(_history.length - 30) : _history;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171B32),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2C3358)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'US National Debt History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${recent.length} points',
                style: const TextStyle(color: Color(0xFF8EA1C4)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: recent.length < 2
                ? const Center(
                    child: Text(
                      '至少需要兩筆資料才能顯示圖表，先按更新累積歷史資料。',
                      style: TextStyle(color: Color(0xFF8EA1C4)),
                      textAlign: TextAlign.center,
                    ),
                  )
                : CustomPaint(
                    painter: _USDebtChartPainter(recent),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final recentHistory = _history.reversed.take(10).toList();
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171B32),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2C3358)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Samples',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (recentHistory.isEmpty)
            const Text(
              '目前還沒有 US Debt 歷史資料。',
              style: TextStyle(color: Color(0xFF8EA1C4)),
            )
          else
            ...recentHistory.map((point) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(point.capturedAt.toLocal()),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      formatter.format(point.debt.round()),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF80DEEA),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF4A1E2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE57373)),
        ),
        child: Text(message),
      ),
    );
  }
}

class _DebtTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DebtTag({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF80DEEA)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );

    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: content,
        ),
      ),
    );
  }
}

class _USDebtChartPainter extends CustomPainter {
  final List<USDebtPoint> history;

  _USDebtChartPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 16.0;
    const bottomPadding = 28.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final values = history.map((item) => item.debt).toList();
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final span = max(maxValue - minValue, 1.0);

    final gridPaint = Paint()
      ..color = const Color(0xFF2C3358)
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (var i = 0; i < history.length; i++) {
      final x = leftPadding + (chartWidth * i / (history.length - 1));
      final normalized = (history[i].debt - minValue) / span;
      final y = topPadding + chartHeight - (normalized * chartHeight);
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height - bottomPadding);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(controlX, previous.dy, controlX, current.dy, current.dx, current.dy);
      fillPath.cubicTo(controlX, previous.dy, controlX, current.dy, current.dx, current.dy);
    }

    fillPath
      ..lineTo(points.last.dx, size.height - bottomPadding)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x6632E0C4), Color(0x0032E0C4)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF80DEEA)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFFB2EBF2);
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }

    _drawLabels(canvas, size, minValue, maxValue);
  }

  void _drawLabels(Canvas canvas, Size size, double minValue, double maxValue) {
    final firstDate = DateFormat('MM/dd').format(history.first.capturedAt.toLocal());
    final lastDate = DateFormat('MM/dd').format(history.last.capturedAt.toLocal());
    final shortNumber = NumberFormat.compactCurrency(symbol: '\$');

    _paintText(
      canvas,
      text: shortNumber.format(maxValue.round()),
      offset: const Offset(8, 0),
      color: const Color(0xFF8EA1C4),
    );
    _paintText(
      canvas,
      text: shortNumber.format(minValue.round()),
      offset: Offset(8, size.height - 46),
      color: const Color(0xFF8EA1C4),
    );
    _paintText(
      canvas,
      text: firstDate,
      offset: Offset(8, size.height - 22),
      color: const Color(0xFF8EA1C4),
    );
    _paintText(
      canvas,
      text: lastDate,
      offset: Offset(size.width - 44, size.height - 22),
      color: const Color(0xFF8EA1C4),
    );
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required Color color,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _USDebtChartPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
