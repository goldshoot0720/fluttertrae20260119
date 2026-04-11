import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/model/price_history_models.dart';
import '../data/service/price_history_service.dart';

class PriceHistoryScreen extends StatefulWidget {
  const PriceHistoryScreen({super.key});

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  final PriceHistoryService _service = PriceHistoryService();
  final TextEditingController _urlController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final NumberFormat _decimalFormat = NumberFormat('0.00');

  PriceHistoryPayload? _payload;
  List<RecentPriceUrl> _recent = [];
  bool _isLoading = false;
  bool _isLoadingRecent = false;
  String _status = '等待查詢';
  int _days = 3650;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    setState(() => _isLoadingRecent = true);
    try {
      final recent = await _service.fetchRecent();
      if (!mounted) return;
      setState(() {
        _recent = recent;
        _isLoadingRecent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecent = false;
        _status = '讀取最近連結失敗：$e';
      });
    }
  }

  Future<void> _resolve() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _status = '請先輸入商品連結');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = '查詢中，請稍候...';
    });
    try {
      final payload = await _service.resolve(url, _days);
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _isLoading = false;
        _status = '完成';
      });
      await _loadRecent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = '查詢失敗：$e';
      });
    }
  }

  Future<void> _pasteClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      if (data?.text == null || data!.text!.trim().isEmpty) {
        setState(() => _status = '剪貼簿沒有內容');
        return;
      }
      _urlController.text = data.text!.trim();
      setState(() => _status = '已貼上剪貼簿內容');
    } catch (_) {
      setState(() => _status = '目前無法讀取剪貼簿');
    }
  }

  void _clearAll() {
    _urlController.clear();
    setState(() {
      _payload = null;
      _status = '已清空';
      _days = 3650;
    });
  }

  Future<void> _deleteRecent(int index) async {
    try {
      await _service.deleteRecent(index + 1);
      await _loadRecent();
      if (!mounted) return;
      setState(() => _status = '已刪除最近連結');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '刪除失敗：$e');
    }
  }

  Future<void> _openSourceUrl() async {
    final sourceUrl = _payload?.sourceUrl.trim();
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return;
    }
    final uri = Uri.parse(sourceUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EA),
      appBar: AppBar(
        title: const Text(
          '鋒兄比價',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _isLoading ? null : _loadRecent,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildInputCard(),
          const SizedBox(height: 16),
          _buildChartCard(),
          const SizedBox(height: 16),
          _buildStatsCard(),
          const SizedBox(height: 16),
          _buildRecentCard(),
          const SizedBox(height: 16),
          _buildHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE4DDD0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E351A).withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D8A62),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.query_stats_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '商品歷史價格追蹤',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24323D),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '貼上 PChome 或 momo 商品連結，直接抓出歷史價錢走勢與統計。',
                  style: TextStyle(color: Color(0xFF61717D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DDD0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '商品連結',
            style: TextStyle(
              color: Color(0xFF61717D),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: '貼上 PChome / momo 商品連結',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE4DDD0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE4DDD0)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                '查詢天數',
                style: TextStyle(
                  color: Color(0xFF61717D),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _days,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 90, child: Text('90 天')),
                  DropdownMenuItem(value: 180, child: Text('180 天')),
                  DropdownMenuItem(value: 365, child: Text('365 天')),
                  DropdownMenuItem(value: 730, child: Text('2 年')),
                  DropdownMenuItem(value: 1095, child: Text('3 年')),
                  DropdownMenuItem(value: 3650, child: Text('最長 5 年')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _days = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: _isLoading ? null : _resolve,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD9702F),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('產生圖表'),
              ),
              OutlinedButton(
                onPressed: _pasteClipboard,
                child: const Text('貼上剪貼簿'),
              ),
              OutlinedButton(
                onPressed: _clearAll,
                child: const Text('清空'),
              ),
              OutlinedButton.icon(
                onPressed: _payload == null ? null : _openSourceUrl,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('開啟來源'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            style: const TextStyle(color: Color(0xFF61717D)),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DDD0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _payload?.title.isNotEmpty == true ? _payload!.title : '尚未產生圖表',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24323D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _payload?.subtitle.isNotEmpty == true
                ? _payload!.subtitle
                : '輸入商品連結後，會在頁面內直接繪製平滑走勢。',
            style: const TextStyle(color: Color(0xFF61717D)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: CustomPaint(
              painter: _PriceHistoryChartPainter(_payload),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _payload?.stats;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DDD0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '價格統計',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24323D),
            ),
          ),
          const SizedBox(height: 12),
          if (stats == null)
            const Text(
              '查詢完成後，這裡會顯示最新、最高、最低、平均、中位數與差額資訊。',
              style: TextStyle(color: Color(0xFF61717D)),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildStat('最新價格', _currencyFormat.format(stats.latestPrice)),
                _buildStat('最舊價格', _currencyFormat.format(stats.oldestPrice)),
                _buildStat('最高價格', _currencyFormat.format(stats.highestPrice)),
                _buildStat('最低價格', _currencyFormat.format(stats.lowestPrice)),
                _buildStat('平均價格', _decimalFormat.format(stats.averagePrice)),
                _buildStat('中位數價格', _decimalFormat.format(stats.medianPrice)),
                _buildStat('最新減最低', _currencyFormat.format(stats.latestMinusLowest)),
                _buildStat(
                  '最新與最低間隔',
                  '${stats.interval.years} 年 ${stats.interval.months} 個月 ${stats.interval.days} 天',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4DDD0)),
        color: const Color(0xFFF6EFE3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF61717D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF24323D),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DDD0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近連結',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24323D),
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingRecent)
            const Center(child: CircularProgressIndicator())
          else if (_recent.isEmpty)
            const Text(
              '目前還沒有最近連結。',
              style: TextStyle(color: Color(0xFF61717D)),
            )
          else
            Column(
              children: _recent.asMap().entries.map((entry) {
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      _urlController.text = item.url;
                      setState(() => _status = '已帶入最近連結');
                    },
                    onLongPress: () => _deleteRecent(entry.key),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4DDD0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.matchedTitle.isNotEmpty ? item.matchedTitle : item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF24323D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.url,
                            style: const TextStyle(
                              color: Color(0xFF61717D),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final history = _payload?.history ?? [];
    final viewHistory = history.length > 30 ? history.sublist(history.length - 30) : history;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DDD0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '歷史資料',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24323D),
            ),
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Text(
              '尚未載入歷史資料。',
              style: TextStyle(color: Color(0xFF61717D)),
            )
          else
            Column(
              children: viewHistory.map((point) {
                final time = DateTime.fromMillisecondsSinceEpoch(point.x, isUtc: true)
                    .toLocal();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('yyyy/MM/dd HH:mm').format(time),
                          style: const TextStyle(
                            color: Color(0xFF24323D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _currencyFormat.format(point.y),
                        style: const TextStyle(
                          color: Color(0xFFD9702F),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _PriceHistoryChartPainter extends CustomPainter {
  final PriceHistoryPayload? payload;

  _PriceHistoryChartPainter(this.payload);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    paint.color = const Color(0xFFF8F3EA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      paint,
    );

    if (payload == null || payload!.history.length < 2) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '尚未產生圖表',
          style: TextStyle(
            color: Color(0xFF61717D),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, const Offset(16, 16));
      return;
    }

    final history = payload!.sampledHistory.isNotEmpty
        ? payload!.sampledHistory
        : payload!.history;
    final sorted = [...history]..sort((a, b) => a.x.compareTo(b.x));
    final minX = sorted.first.x.toDouble();
    final maxX = sorted.last.x.toDouble();
    final ys = sorted.map((p) => p.y.toDouble()).toList();
    var minY = ys.reduce(min);
    var maxY = ys.reduce(max);
    final pad = max(30, (maxY - minY) * 0.15);
    minY -= pad;
    maxY += pad;

    const left = 40.0;
    const right = 16.0;
    const top = 24.0;
    const bottom = 24.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;

    double sx(double value) =>
        left + ((value - minX) / max(1, maxX - minX)) * width;
    double sy(double value) =>
        top + ((maxY - value) / max(1, maxY - minY)) * height;

    final gridPaint = Paint()
      ..color = const Color(0xFFE4DDD0)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + (height / 4) * i;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < sorted.length; i++) {
      final point = sorted[i];
      final x = sx(point.x.toDouble());
      final y = sy(point.y.toDouble());
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prev = sorted[i - 1];
        final prevX = sx(prev.x.toDouble());
        final prevY = sy(prev.y.toDouble());
        final cx = (prevX + x) / 2;
        path.quadraticBezierTo(prevX, prevY, cx, (prevY + y) / 2);
        path.quadraticBezierTo(x, y, x, y);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFD9702F);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF2D8A62);
    for (final point in sorted) {
      final x = sx(point.x.toDouble());
      final y = sy(point.y.toDouble());
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PriceHistoryChartPainter oldDelegate) {
    return oldDelegate.payload != payload;
  }
}
