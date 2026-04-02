import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/model/oil_price_point.dart';
import '../data/service/oil_price_service.dart';

class OilMonitorScreen extends StatefulWidget {
  const OilMonitorScreen({super.key});

  @override
  State<OilMonitorScreen> createState() => _OilMonitorScreenState();
}

class _OilMonitorScreenState extends State<OilMonitorScreen> {
  final OilPriceService _oilPriceService = OilPriceService();

  List<OilPricePoint> _history = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadData(refresh: true);
  }

  Future<void> _loadData({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (refresh) {
        final result = await _oilPriceService.syncOnAppLaunch();
        _statusMessage = result.message;
      }

      final history = await _oilPriceService.loadHistory();
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

  Future<void> _refreshNow() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final result = await _oilPriceService.sync(
        force: true,
        allowBeforeOnePm: true,
      );
      final history = await _oilPriceService.loadHistory();
      if (!mounted) return;

      setState(() {
        _history = history;
        _statusMessage = result.message;
        _isSyncing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _history.isEmpty ? null : _history.last;
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF4EFE5),
              Color(0xFFEADFCB),
              Color(0xFFF6F2EA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refreshNow,
                  color: const Color(0xFF0F766E),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      _buildTopBar(context),
                      const SizedBox(height: 16),
                      if (_errorMessage != null)
                        _Banner(message: _errorMessage!, error: true),
                      if (_statusMessage != null) _Banner(message: _statusMessage!),
                      if (_errorMessage != null || _statusMessage != null)
                        const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _buildHeroCard(latest)),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: _buildGuideCard()),
                          ],
                        )
                      else ...[
                        _buildHeroCard(latest),
                        const SizedBox(height: 16),
                        _buildGuideCard(),
                      ],
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _buildChartCard()),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: _buildHistoryCard()),
                          ],
                        )
                      else ...[
                        _buildChartCard(),
                        const SizedBox(height: 16),
                        _buildHistoryCard(),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Oil Price Monitor',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E1B18),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '追蹤 OQD Daily Marker Price，快速查看更新狀態與近期走勢。',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: _isSyncing ? null : _refreshNow,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE7F2EF),
            foregroundColor: const Color(0xFF184F49),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: _isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(_isSyncing ? '同步中' : '立即同步'),
        ),
      ],
    );
  }

  Widget _buildHeroCard(OilPricePoint? latest) {
    final marketDate = latest == null
        ? '--'
        : DateFormat('yyyy.MM.dd').format(latest.marketDate);
    final fetchedAt = latest == null
        ? '--'
        : DateFormat('yyyy.MM.dd HH:mm').format(latest.fetchedAt.toLocal());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4A46),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.water_drop_outlined,
                  color: Color(0xFFF4D58D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Daily market signal for fleet and energy tracking.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFEAF2F0),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            latest == null ? '--' : latest.price.toStringAsFixed(2),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DataChip(label: 'Market date $marketDate'),
              _DataChip(label: 'Last synced $fetchedAt'),
              const _DataChip(label: 'Update target 13:00'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EC),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9CFBF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '使用說明',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 14),
          _GuideLine('系統會讀取 OQD Daily Marker Price 的歷史資料。'),
          SizedBox(height: 10),
          _GuideLine('進入頁面時會先嘗試同步，手動按鈕可立即強制更新。'),
          SizedBox(height: 10),
          _GuideLine('如果當天來源尚未更新，畫面會保留最近一次成功抓取結果。'),
          SizedBox(height: 10),
          _GuideLine('下方圖表與列表會協助你快速比對近期波動。'),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EC),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9CFBF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '價格走勢',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${_history.length} points',
                style: const TextStyle(
                  color: Color(0xFF6D645B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: _history.length < 2
                ? const Center(child: Text('資料筆數不足，暫時無法繪製走勢圖。'))
                : CustomPaint(
                    painter: _OilHistoryChartPainter(_history),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final recentHistory = _history.reversed.take(10).toList();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EC),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9CFBF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '近期紀錄',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (recentHistory.isEmpty)
            const Text('目前還沒有歷史資料。')
          else
            ...recentHistory.map((point) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF4),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('yyyy.MM.dd').format(point.marketDate),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        point.price.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final bool error;

  const _Banner({
    required this.message,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFCEAE8) : const Color(0xFFE8F3EF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: error ? const Color(0xFFF0C8C2) : const Color(0xFFB9D9D2),
        ),
      ),
      child: Text(message),
    );
  }
}

class _DataChip extends StatelessWidget {
  final String label;

  const _DataChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE5EFEC),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  final String text;

  const _GuideLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF0F766E),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _OilHistoryChartPainter extends CustomPainter {
  final List<OilPricePoint> history;

  _OilHistoryChartPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    const leftPadding = 14.0;
    const rightPadding = 14.0;
    const topPadding = 16.0;
    const bottomPadding = 28.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final prices = history.map((item) => item.price).toList();
    final minPrice = prices.reduce(min);
    final maxPrice = prices.reduce(max);
    final valueSpan = max(maxPrice - minPrice, 1.0);

    final gridPaint = Paint()
      ..color = const Color(0xFFE1D7C8)
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
      final normalized = (history[i].price - minPrice) / valueSpan;
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
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
      fillPath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    fillPath
      ..lineTo(points.last.dx, size.height - bottomPadding)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x55157A6E), Color(0x00157A6E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = const Color(0xFF0F766E)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = const Color(0xFFCAA75B);

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 4.5, dotPaint);
    }

    _drawLabels(canvas, size, minPrice, maxPrice);
  }

  void _drawLabels(Canvas canvas, Size size, double minPrice, double maxPrice) {
    final firstDate = DateFormat('MM/dd').format(history.first.marketDate);
    final lastDate = DateFormat('MM/dd').format(history.last.marketDate);

    _paintText(
      canvas,
      text: maxPrice.toStringAsFixed(2),
      offset: const Offset(14, 0),
      color: const Color(0xFF6D645B),
    );
    _paintText(
      canvas,
      text: minPrice.toStringAsFixed(2),
      offset: Offset(14, size.height - 48),
      color: const Color(0xFF6D645B),
    );
    _paintText(
      canvas,
      text: firstDate,
      offset: Offset(14, size.height - 24),
      color: const Color(0xFF6D645B),
    );
    _paintText(
      canvas,
      text: lastDate,
      offset: Offset(size.width - 48, size.height - 24),
      color: const Color(0xFF6D645B),
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
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _OilHistoryChartPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
