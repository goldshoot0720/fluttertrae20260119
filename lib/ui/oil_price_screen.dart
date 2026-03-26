import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/model/oil_price_point.dart';
import '../data/service/oil_price_service.dart';

class OilPriceScreen extends StatefulWidget {
  const OilPriceScreen({super.key});

  @override
  State<OilPriceScreen> createState() => _OilPriceScreenState();
}

class _OilPriceScreenState extends State<OilPriceScreen> {
  final OilPriceService _service = OilPriceService();

  List<OilPricePoint> _history = [];
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
      if (refresh || _history.isEmpty) {
        await _service.fetchLatestPrice();
      }
      final history = await _service.loadHistory();

      if (!mounted) return;
      setState(() {
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
      await _service.fetchLatestPrice();
      final history = await _service.loadHistory();
      if (!mounted) return;
      setState(() {
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
    final url = _history.isNotEmpty ? _history.last.sourceUrl : kOqdSourceUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _history.isNotEmpty ? _history.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EEE4),
      appBar: AppBar(
        title: const Text(
          'Oil Price',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _isRefreshing ? null : _refresh,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('刷新'),
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

  Widget _buildHeroCard(OilPricePoint? latest) {
    final priceLabel = latest == null ? '--' : '\$${latest.price.toStringAsFixed(2)}';
    final updatedAt = latest == null
        ? '--'
        : DateFormat('yyyy/MM/dd HH:mm').format(latest.fetchedAt.toLocal());
    final marketDate =
        latest == null ? '--' : DateFormat('yyyy/MM/dd').format(latest.marketDate.toLocal());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0E5D2), Color(0xFFEADAC2), Color(0xFFE6D6C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD9C7B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.oil_barrel_rounded,
                  color: Color(0xFFD9A46D),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'OQD Daily Marker Price',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1B18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            priceLabel,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E1B18),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Market date: $marketDate',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6D645B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last synced: $updatedAt',
            style: const TextStyle(fontSize: 13, color: Color(0xFF7E746A)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _OilTag(
                icon: Icons.public_rounded,
                label: 'Source: gulfmerc.com',
              ),
              _OilTag(
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
    final low = recent.isEmpty ? null : recent.map((item) => item.price).reduce(min);
    final high = recent.isEmpty ? null : recent.map((item) => item.price).reduce(max);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0D4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '內容展示',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1B18),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: recent.length < 2
                ? const Center(
                    child: Text(
                      '目前樣本數不足，請先刷新幾次後再查看圖表。',
                      style: TextStyle(color: Color(0xFF7E746A)),
                      textAlign: TextAlign.center,
                    ),
                  )
                : CustomPaint(
                    painter: _OilPriceChartPainter(recent),
                    child: const SizedBox.expand(),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  recent.isEmpty
                      ? '--'
                      : DateFormat('MM/dd').format(recent.first.marketDate.toLocal()),
                  style: const TextStyle(color: Color(0xFF6D645B), fontSize: 12),
                ),
              ),
              if (low != null && high != null)
                Text(
                  'Low \$${low.toStringAsFixed(2)}   High \$${high.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF6D645B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              if (recent.isNotEmpty)
                Text(
                  DateFormat('MM/dd').format(recent.last.marketDate.toLocal()),
                  style: const TextStyle(color: Color(0xFF6D645B), fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final recentHistory = _history.reversed.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0D4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '近期樣本',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1B18),
            ),
          ),
          const SizedBox(height: 12),
          if (recentHistory.isEmpty)
            const Text(
              '目前還沒有 Oil Price 歷史資料。',
              style: TextStyle(color: Color(0xFF7E746A)),
            )
          else
            ...recentHistory.map((point) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('yyyy/MM/dd HH:mm').format(point.fetchedAt.toLocal()),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1B18),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy/MM/dd').format(point.marketDate.toLocal()),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7E746A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E5D2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '\$${point.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4E3724),
                        ),
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
          color: const Color(0xFFFBE4DE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7B3A3)),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF6A2A14)),
        ),
      ),
    );
  }
}

class _OilTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _OilTag({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7EFE3),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFA86B39)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF4E3724)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OilPriceChartPainter extends CustomPainter {
  final List<OilPricePoint> history;

  _OilPriceChartPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 16.0;
    const bottomPadding = 28.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final values = history.map((item) => item.price).toList();
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final span = max(maxValue - minValue, 0.01);

    final gridPaint = Paint()
      ..color = const Color(0xFFE9DECF)
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
      final normalized = (history[i].price - minValue) / span;
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
        colors: [Color(0x66C58A50), Color(0x00C58A50)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFFA86B39)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF586455);
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }

    _drawLabels(canvas, size, minValue, maxValue);
  }

  void _drawLabels(Canvas canvas, Size size, double minValue, double maxValue) {
    _paintText(
      canvas,
      text: '\$${maxValue.toStringAsFixed(2)}',
      offset: const Offset(8, 0),
      color: const Color(0xFF7E746A),
    );
    _paintText(
      canvas,
      text: '\$${minValue.toStringAsFixed(2)}',
      offset: Offset(8, size.height - 46),
      color: const Color(0xFF7E746A),
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
  bool shouldRepaint(covariant _OilPriceChartPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
