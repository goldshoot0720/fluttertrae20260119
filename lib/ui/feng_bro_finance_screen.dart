import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/model/feng_bro_finance_models.dart';
import '../data/service/feng_bro_finance_service.dart';

class FengBroFinanceScreen extends StatefulWidget {
  const FengBroFinanceScreen({super.key});

  @override
  State<FengBroFinanceScreen> createState() => _FengBroFinanceScreenState();
}

class _FengBroFinanceScreenState extends State<FengBroFinanceScreen> {
  final FengBroFinanceService _service = FengBroFinanceService();
  FengBroFinanceSummary? _summary;
  bool _loading = true;
  String _status = '正在讀取 CNBC 金融行情...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = '正在讀取 CNBC 金融行情...';
    });
    try {
      final summary = await _service.fetchQuotes();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _status = '已更新 ${summary.quotes.length} 個金融項目';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = '讀取失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('鋒兄金融'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(summary),
            const SizedBox(height: 14),
            _buildStatus(summary),
            const SizedBox(height: 14),
            if (summary == null && _loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (summary != null)
              ...summary.quotes.map(_buildQuoteCard)
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FengBroFinanceSummary? summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '鋒兄金融',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '追蹤亞股、美股、原油、黃金、債券、VIX、BTC、ETH，並依 CNBC 52 週高低點標註創新高或創新低。',
            style: TextStyle(color: Color(0xFFE0F2FE), height: 1.45),
          ),
          if (summary != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildHeroChip('項目 ${summary.quotes.length}'),
                _buildHeroChip('創新高 ${summary.recordHighCount}'),
                _buildHeroChip('創新低 ${summary.recordLowCount}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStatus(FengBroFinanceSummary? summary) {
    final fetchedAt = summary?.fetchedAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(
            _loading ? Icons.sync_rounded : Icons.check_circle_rounded,
            color: _loading ? const Color(0xFF2563EB) : const Color(0xFF059669),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fetchedAt == null
                  ? _status
                  : '$_status · ${_formatDateTime(fetchedAt)}',
              style: const TextStyle(
                color: Color(0xFF173832),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(FengBroFinanceQuote quote) {
    final signal = quote.signal;
    final accent = _signalColor(signal, quote);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        borderColor: signal == FengBroFinanceSignal.none
            ? const Color(0xFFDCE8E4)
            : accent.withValues(alpha: 0.55),
        background: signal == FengBroFinanceSignal.none
            ? Colors.white
            : accent.withValues(alpha: 0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.show_chart_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          quote.instrument.name,
                          style: const TextStyle(
                            color: Color(0xFF173832),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _buildSymbolChip(quote.instrument.symbol),
                        if (signal != FengBroFinanceSignal.none)
                          _buildSignalChip(signal),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${quote.instrument.category} · ${quote.instrument.unit}',
                      style: const TextStyle(
                        color: Color(0xFF60736D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '開啟 CNBC',
                onPressed: () => _openUrl(quote.instrument.url),
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _formatNumber(quote.last),
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildChangePill(quote),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStat('日高', _formatNumber(quote.dayHigh)),
              _buildStat('日低', _formatNumber(quote.dayLow)),
              _buildStat('52週高', _formatNumber(quote.week52High)),
              _buildStat('52週低', _formatNumber(quote.week52Low)),
            ],
          ),
          if (quote.warning != null) ...[
            const SizedBox(height: 10),
            Text(
              '讀取警告：${quote.warning}',
              style: const TextStyle(color: Color(0xFFB45309)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalChip(FengBroFinanceSignal signal) {
    final isHigh = signal == FengBroFinanceSignal.recordHigh;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isHigh ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isHigh ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        ),
      ),
      child: Text(
        isHigh ? '創新高' : '創新低',
        style: TextStyle(
          color: isHigh ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildSymbolChip(String symbol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        symbol,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildChangePill(FengBroFinanceQuote quote) {
    final color = quote.isPositive
        ? const Color(0xFF059669)
        : quote.isNegative
        ? const Color(0xFFDC2626)
        : const Color(0xFF64748B);
    final change = quote.change;
    final percent = quote.changePercent;
    final text = [
      if (change != null) _formatSigned(change),
      if (percent != null) '${_formatSigned(percent)}%',
    ].join(' / ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.isEmpty ? '--' : text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8E4)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Color(0xFF173832),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: const Text(
        '目前沒有金融行情資料，請稍後重新整理。',
        style: TextStyle(color: Color(0xFF60736D)),
      ),
    );
  }

  BoxDecoration _cardDecoration({
    Color background = Colors.white,
    Color borderColor = const Color(0xFFDCE8E4),
  }) {
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Color _signalColor(FengBroFinanceSignal signal, FengBroFinanceQuote quote) {
    if (signal == FengBroFinanceSignal.recordHigh) {
      return const Color(0xFF059669);
    }
    if (signal == FengBroFinanceSignal.recordLow) {
      return const Color(0xFFDC2626);
    }
    if (quote.isPositive) return const Color(0xFF0F766E);
    if (quote.isNegative) return const Color(0xFFB91C1C);
    return const Color(0xFF2563EB);
  }

  String _formatNumber(double? value) {
    if (value == null) return '--';
    final fixed = value.abs() >= 100
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(4);
    final parts = fixed.split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final decimal = parts.length > 1
        ? parts.last.replaceFirst(RegExp(r'0+$'), '')
        : '';
    return decimal.isEmpty ? integer : '$integer.$decimal';
  }

  String _formatSigned(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_formatNumber(value)}';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
