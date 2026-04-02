import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/model/lottery_draw.dart';
import '../data/service/taiwan_lottery_service.dart';

class AbsurdMarriageReasonScreen extends StatefulWidget {
  const AbsurdMarriageReasonScreen({super.key});

  @override
  State<AbsurdMarriageReasonScreen> createState() =>
      _AbsurdMarriageReasonScreenState();
}

class _AbsurdMarriageReasonScreenState
    extends State<AbsurdMarriageReasonScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _easterEggController;
  final TaiwanLotteryService _service = TaiwanLotteryService();

  LotteryDashboardData? _data;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _easterEggController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (_isBirthdayEasterEgg) {
      _easterEggController.repeat();
    }
    _load();
  }

  @override
  void dispose() {
    _easterEggController.dispose();
    super.dispose();
  }

  bool get _isBirthdayEasterEgg {
    final now = DateTime.now();
    return now.month == 4 && now.day == 3;
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _errorMessage = null;
      if (_data == null || refresh) {
        _isLoading = true;
      }
    });

    try {
      final data = await _service.fetchDashboardData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    await _load(refresh: true);
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE3),
      appBar: AppBar(
        title: const Text(
          '最瞎結婚理由',
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
              label: const Text('更新'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_isBirthdayEasterEgg) ...[
                    _buildBirthdayBanner(),
                    const SizedBox(height: 16),
                  ],
                  _buildHeroCard(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBanner(_errorMessage!),
                  ],
                  const SizedBox(height: 16),
                  ...?_data?.sections.map(_buildSection),
                ],
              ),
            ),
          if (_isBirthdayEasterEgg)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _easterEggController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _BirthdaySparklePainter(
                        progress: _easterEggController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBirthdayBanner() {
    return AnimatedBuilder(
      animation: _easterEggController,
      builder: (context, child) {
        final pulse = 1 + (_easterEggController.value * 0.08);

        return Transform.scale(
          scale: pulse,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB91C1C),
                  Color(0xFFF97316),
                  Color(0xFFFACC15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33B45309),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '4/3 限定彩蛋',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.cake_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  '塗哥生日快樂',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '今彩539頭獎得主鋒兄',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFF7D6),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _BirthdayChip(label: '今天全站一起幫塗哥慶生'),
                    _BirthdayChip(label: '財運祝福送給鋒兄'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildHeroCard() {
    final fetchedAt = _data == null
        ? '--'
        : DateFormat('yyyy/MM/dd HH:mm').format(_data!.fetchedAt.toLocal());
    final totalDraws = _data?.sections.fold<int>(
          0,
          (sum, section) => sum + section.draws.length,
        ) ??
        0;
    final overallSummary = _data == null ? null : _service.summarizeDashboard(_data!);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1E0B8), Color(0xFFE6CE92), Color(0xFFEADBB9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFD6BD86)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '把台彩官方最近期數全部攤開來看',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF241B08),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '依照台灣彩券結果頁背後使用的官方 API，列出威力彩、大樂透、今彩539 今年到目前為止的各期號碼，並逐期比對你指定的組合。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF5F4E2C),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.confirmation_number_rounded,
                label: '已整理 $totalDraws 期',
              ),
              _InfoPill(
                icon: Icons.schedule_rounded,
                label: '最後更新 $fetchedAt',
              ),
              if (overallSummary != null)
                _InfoPill(
                  icon: Icons.payments_rounded,
                  label: '總投入 ${_formatCurrency(overallSummary.totalCost)}',
                ),
              if (overallSummary != null)
                _InfoPill(
                  icon: Icons.savings_rounded,
                  label: '總獎金 ${_formatCurrency(overallSummary.totalPayout)}',
                ),
              if (overallSummary != null)
                _InfoPill(
                  icon: overallSummary.netProfit >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  label:
                      '淨收益 ${_formatSignedCurrency(overallSummary.netProfit)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1717),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF834545)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFFB3B3)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFD7D7),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(LotteryGameSection section) {
    final winningCount = section.draws
        .expand((draw) => _service.compareTickets(draw, section.tickets))
        .where((match) => match.isWinning)
        .length;
    final summary = _service.summarizeSection(section);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFDCCFB9)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF201B14),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '共 ${section.draws.length} 期，比對後有 $winningCount 筆中獎結果',
                          style: const TextStyle(
                            color: Color(0xFF6E6457),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openSource(section.sourceUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('官方頁面'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: section.tickets
                    .map((ticket) => _TicketDefinitionChip(ticket: ticket))
                    .toList(),
              ),
              const SizedBox(height: 14),
              _FinanceStrip(summary: summary),
              const SizedBox(height: 16),
              ...section.draws.map((draw) => _buildDrawCard(section, draw)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawCard(LotteryGameSection section, LotteryDraw draw) {
    final matches = _service.compareTickets(draw, section.tickets);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6DAC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '第 ${draw.period} 期',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F1A15),
                ),
              ),
              Text(
                DateFormat('yyyy/MM/dd').format(draw.lotteryDate.toLocal()),
                style: const TextStyle(
                  color: Color(0xFF7A7064),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...draw.mainNumbers.map(
                (number) => _NumberBall(
                  value: number,
                  backgroundColor: const Color(0xFF1E6F67),
                  foregroundColor: Colors.white,
                ),
              ),
              if (draw.specialNumber != null)
                _NumberBall(
                  value: draw.specialNumber!,
                  backgroundColor: const Color(0xFFB7791F),
                  foregroundColor: Colors.white,
                  prefix: '特',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4ECDD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: matches
                  .map((match) => _MatchRow(match: match, gameType: section.gameType))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD2BB8B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF5A481A)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4F401A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketDefinitionChip extends StatelessWidget {
  final LotteryTicketSet ticket;

  const _TicketDefinitionChip({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final numbers = ticket.mainNumbers.map(_formatNumber).join(' ');
    final label = ticket.specialNumber == null
        ? '${ticket.label} $numbers'
        : '${ticket.label} $numbers | 特別號 ${_formatNumber(ticket.specialNumber!)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _NumberBall extends StatelessWidget {
  final int value;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? prefix;

  const _NumberBall({
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        prefix == null ? _formatNumber(value) : '$prefix${_formatNumber(value)}',
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: prefix == null ? 16 : 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final LotteryTicketMatch match;
  final LotteryGameType gameType;

  const _MatchRow({
    required this.match,
    required this.gameType,
  });

  @override
  Widget build(BuildContext context) {
    final prizeColor = match.isWinning
        ? const Color(0xFF0F766E)
        : const Color(0xFF7C6F61);
    final specialText = switch (gameType) {
      LotteryGameType.daily539 => null,
      LotteryGameType.superLotto638 || LotteryGameType.lotto649 =>
        '特別號 ${match.specialMatched ? "命中" : "未中"}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE3D7C4)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              match.ticket.label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A241D),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '命中 ${match.matchedCount} 顆: '
                  '${match.matchedMainNumbers.isEmpty ? "無" : match.matchedMainNumbers.map(_formatNumber).join(" ")}',
                  style: const TextStyle(
                    color: Color(0xFF4E453A),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (specialText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    specialText,
                    style: const TextStyle(
                      color: Color(0xFF756A5E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: prizeColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              match.prizeLabel,
              style: TextStyle(
                color: prizeColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatNumber(int number) => number.toString().padLeft(2, '0');

String _formatCurrency(int amount) {
  final formatter = NumberFormat.currency(
    locale: 'zh_TW',
    symbol: r'$',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

String _formatSignedCurrency(int amount) {
  final sign = amount > 0 ? '+' : '';
  return '$sign${_formatCurrency(amount)}';
}

class _FinanceStrip extends StatelessWidget {
  final LotteryFinancialSummary summary;

  const _FinanceStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final netColor = summary.netProfit >= 0
        ? const Color(0xFF0F766E)
        : const Color(0xFF9A3412);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4D4B8)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _FinancePill(
            label: '每注成本',
            value: _formatCurrency(summary.costPerTicket),
          ),
          _FinancePill(
            label: '總投入',
            value: _formatCurrency(summary.totalCost),
          ),
          _FinancePill(
            label: '總獎金',
            value: _formatCurrency(summary.totalPayout),
          ),
          _FinancePill(
            label: '淨收益',
            value: _formatSignedCurrency(summary.netProfit),
            valueColor: netColor,
          ),
          _FinancePill(
            label: '中獎張數',
            value: '${summary.winningTickets}',
          ),
        ],
      ),
    );
  }
}

class _FinancePill extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _FinancePill({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7A7064),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: valueColor ?? const Color(0xFF1F1A15),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayChip extends StatelessWidget {
  final String label;

  const _BirthdayChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BirthdaySparklePainter extends CustomPainter {
  final double progress;

  const _BirthdaySparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()..style = PaintingStyle.fill;
    final dots = [
      (Offset(size.width * 0.14, size.height * (0.10 + progress * 0.05)),
          const Color(0x66F97316), 34.0),
      (Offset(size.width * 0.86, size.height * (0.18 - progress * 0.06)),
          const Color(0x55EAB308), 28.0),
      (Offset(size.width * 0.20, size.height * (0.55 - progress * 0.03)),
          const Color(0x4438BDF8), 22.0),
      (Offset(size.width * 0.78, size.height * (0.68 + progress * 0.04)),
          const Color(0x44EC4899), 26.0),
    ];

    for (final dot in dots) {
      glowPaint.color = dot.$2;
      canvas.drawCircle(dot.$1, dot.$3, glowPaint);
    }

    final starPaint = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final stars = [
      Offset(size.width * 0.10, size.height * 0.28),
      Offset(size.width * 0.89, size.height * 0.33),
      Offset(size.width * 0.16, size.height * 0.82),
      Offset(size.width * 0.92, size.height * 0.78),
    ];

    for (final star in stars) {
      final length = 10 + (progress * 8);
      canvas.drawLine(
        Offset(star.dx - length, star.dy),
        Offset(star.dx + length, star.dy),
        starPaint,
      );
      canvas.drawLine(
        Offset(star.dx, star.dy - length),
        Offset(star.dx, star.dy + length),
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BirthdaySparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
