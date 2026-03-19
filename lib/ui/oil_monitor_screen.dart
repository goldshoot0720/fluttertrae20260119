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
      if (!mounted) {
        return;
      }

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }

      setState(() {
        _history = history;
        _statusMessage = result.message;
        _isSyncing = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSyncing = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _history.isEmpty ? null : _history.last;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D20),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '石油監控',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _isSyncing ? null : _refreshNow,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16213E),
                foregroundColor: Colors.white,
              ),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.oil_barrel_rounded, size: 18),
              label: const Text('立即抓取'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshNow,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
                  if (_statusMessage != null) _buildStatusBanner(_statusMessage!),
                  _buildHeroCard(latest),
                  const SizedBox(height: 16),
                  _buildGuideCard(),
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
    final marketDate = latest == null
        ? '--'
        : DateFormat('yyyy/MM/dd').format(latest.marketDate);
    final fetchedAt = latest == null
        ? '--'
        : DateFormat('yyyy/MM/dd HH:mm').format(latest.fetchedAt.toLocal());

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
                  Icons.show_chart_rounded,
                  color: Color(0xFF80DEEA),
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
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            latest == null ? '--' : latest.price.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Market date: $marketDate',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB9C8DE),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last synced: $fetchedAt',
            style: const TextStyle(fontSize: 13, color: Color(0xFF92A5C6)),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OilTag(
                icon: Icons.schedule_rounded,
                label: '13:00 自動抓取',
              ),
              _OilTag(
                icon: Icons.mobile_friendly_rounded,
                label: '開啟 App 自動更新',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171B32),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2C3358)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '使用引導',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12),
          Text('1. 系統會在開啟 App 時先同步一次 GME 首頁上的 OQD Daily Marker Price。'),
          SizedBox(height: 8),
          Text('2. App 在前景執行時，會持續檢查下午 1 點後的每日資料並自動寫入歷史紀錄。'),
          SizedBox(height: 8),
          Text('3. Android 背景排程也會每小時喚醒一次，13:00 後若當日尚未抓取就會補抓。'),
          SizedBox(height: 8),
          Text('4. 圖表會依歷史資料顯示趨勢；資料來源為 https://www.gulfmerc.com/ 首頁。'),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
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
                '價格圖表',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${_history.length} points',
                style: const TextStyle(color: Color(0xFF8EA1C4)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _history.length < 2
                ? const Center(
                    child: Text(
                      '抓到兩筆以上資料後，這裡會顯示趨勢圖。',
                      style: TextStyle(color: Color(0xFF8EA1C4)),
                    ),
                  )
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
            '最近紀錄',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (recentHistory.isEmpty)
            const Text(
              '目前還沒有油價資料，請先按「立即抓取」或重新開啟 App。',
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
                        DateFormat('yyyy/MM/dd').format(point.marketDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      point.price.toStringAsFixed(2),
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

  Widget _buildStatusBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF173B38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4DD0E1)),
        ),
        child: Text(message),
      ),
    );
  }
}

class _OilTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OilTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF80DEEA)),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _OilHistoryChartPainter extends CustomPainter {
  final List<OilPricePoint> history;

  _OilHistoryChartPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) {
      return;
    }

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 16.0;
    const bottomPadding = 28.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final prices = history.map((item) => item.price).toList();
    final minPrice = prices.reduce(min);
    final maxPrice = prices.reduce(max);
    final valueSpan = max(maxPrice - minPrice, 1.0);

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

    _drawLabels(canvas, size, minPrice, maxPrice);
  }

  void _drawLabels(Canvas canvas, Size size, double minPrice, double maxPrice) {
    final firstDate = DateFormat('MM/dd').format(history.first.marketDate);
    final lastDate = DateFormat('MM/dd').format(history.last.marketDate);

    _paintText(
      canvas,
      text: maxPrice.toStringAsFixed(2),
      offset: const Offset(8, 0),
      color: const Color(0xFF8EA1C4),
    );
    _paintText(
      canvas,
      text: minPrice.toStringAsFixed(2),
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
  bool shouldRepaint(covariant _OilHistoryChartPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
