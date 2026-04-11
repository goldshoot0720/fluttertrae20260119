import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/model/lottery_draw.dart';
import '../data/service/taiwan_lottery_service.dart';

class DrunkenShrimpMarriageReasonScreen extends StatefulWidget {
  const DrunkenShrimpMarriageReasonScreen({super.key});

  @override
  State<DrunkenShrimpMarriageReasonScreen> createState() =>
      _DrunkenShrimpMarriageReasonScreenState();
}

class _DrunkenShrimpMarriageReasonScreenState
    extends State<DrunkenShrimpMarriageReasonScreen> {
  final TaiwanLotteryService _service = TaiwanLotteryService();
  final List<TextEditingController> _controllers =
      List.generate(9, (_) => TextEditingController());
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$', decimalDigits: 0);

  Daily539Mode _mode = Daily539Mode.single;
  int _packIndex = -1;
  String _status = '尚未開始比對';
  bool _isLoading = false;
  bool _isRefreshing = false;
  List<LotteryDraw> _draws = [];
  List<Daily539ResultRow> _results = [];
  Daily539SelectionSummary? _summary;
  MarriageReason _reason = _marriageReasons.first;

  @override
  void initState() {
    super.initState();
    _refreshDraws();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshDraws() async {
    setState(() {
      _isRefreshing = true;
      _status = '正在抓取官方資料...';
    });
    try {
      final draws = await _service.fetchDaily539Draws();
      if (!mounted) return;
      setState(() {
        _draws = draws;
        _isRefreshing = false;
        _status = '已更新 ${draws.length} 期資料';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _status = '更新失敗：$e';
      });
    }
  }

  void _setMode(Daily539Mode mode) {
    setState(() {
      _mode = mode;
      _packIndex = -1;
      if (mode != Daily539Mode.single) {
        for (final controller in _controllers) {
          if (controller.text == '包牌') {
            controller.clear();
          }
        }
      }
    });
  }

  void _togglePackIndex(int index) {
    if (_mode != Daily539Mode.single) return;
    setState(() {
      _packIndex = _packIndex == index ? -1 : index;
      for (var i = 0; i < 5; i++) {
        if (i == _packIndex) {
          _controllers[i].text = '';
        }
      }
    });
  }

  void _shuffleReason() {
    setState(() {
      _reason = (_marriageReasons..shuffle()).first;
    });
  }

  void _applySample() {
    final sample = ['06', '08', '20', '22', '32'];
    _setMode(Daily539Mode.single);
    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].text = i < sample.length ? sample[i] : '';
    }
    _packIndex = -1;
    _analyze();
  }

  void _clearInputs() {
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _results = [];
      _summary = null;
      _status = '已清除號碼';
      _packIndex = -1;
    });
  }

  void _analyze() {
    setState(() => _isLoading = true);
    try {
      final selection = _parseSelection();
      final rows = _buildResults(selection);
      final summary = _buildSummary(rows, selection);
      setState(() {
        _results = rows;
        _summary = summary;
        _status = '比對完成，共 ${rows.length} 期';
      });
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  }

  Daily539Selection _parseSelection() {
    final visibleCount = _visibleCount;
    final rawValues =
        _controllers.take(visibleCount).map((c) => c.text.trim()).toList();

    if (_mode == Daily539Mode.single) {
      if (_packIndex == -1) {
        if (rawValues.any((v) => v.isEmpty)) {
          throw Exception('請輸入 5 個號碼');
        }
        final numbers = _parseNumbers(rawValues);
        _ensureUnique(numbers, 5);
        return Daily539Selection.single(numbers);
      }

      final fixedValues = rawValues
          .asMap()
          .entries
          .where((entry) => entry.key != _packIndex)
          .map((entry) => entry.value)
          .toList();
      if (fixedValues.any((v) => v.isEmpty)) {
        throw Exception('包牌模式請輸入 4 個號碼');
      }
      final numbers = _parseNumbers(fixedValues);
      _ensureUnique(numbers, 4);
      return Daily539Selection.pack(numbers, _packIndex);
    }

    if (rawValues.any((v) => v.isEmpty)) {
      throw Exception('請輸入 $_visibleCount 個號碼');
    }
    final numbers = _parseNumbers(rawValues);
    _ensureUnique(numbers, _visibleCount);
    return Daily539Selection.combo(numbers, _visibleCount);
  }

  List<int> _parseNumbers(List<String> values) {
    final numbers = values.map((value) => int.tryParse(value)).toList();
    if (numbers.any((value) => value == null)) {
      throw Exception('請輸入 1 到 39 的數字');
    }
    final parsed = numbers.cast<int>();
    if (parsed.any((value) => value < 1 || value > 39)) {
      throw Exception('號碼需介於 1 到 39');
    }
    parsed.sort();
    return parsed;
  }

  void _ensureUnique(List<int> numbers, int expected) {
    if (numbers.length != expected) {
      throw Exception('輸入號碼不足');
    }
    if (numbers.toSet().length != numbers.length) {
      throw Exception('號碼不可重複');
    }
  }

  List<Daily539ResultRow> _buildResults(Daily539Selection selection) {
    if (_draws.isEmpty) {
      throw Exception('尚未取得開獎資料');
    }

    final rows = <Daily539ResultRow>[];
    for (final draw in _draws) {
      final numbers = draw.mainNumbers..sort();
      if (selection.mode == Daily539Mode.single && selection.packIndex == -1) {
        final hits = numbers.where(selection.selected.contains).toList()..sort();
        final prize = _prizeTable[hits.length] ?? 0;
        rows.add(
          Daily539ResultRow(
            draw: draw,
            hits: hits,
            prize: prize,
            matchLabel: '對中 ${hits.length} 顆',
            tagLabel: _prizeName(hits.length),
            detail: hits.isEmpty ? '未中獎' : '命中 ${_formatList(hits)}',
          ),
        );
        continue;
      }

      if (selection.mode == Daily539Mode.single && selection.packIndex != -1) {
        final fixedHits = numbers.where(selection.selected.contains).toList()..sort();
        final packCovered =
            numbers.where((value) => !selection.selected.contains(value)).toList()
              ..sort();
        final fixedMatchCount = fixedHits.length;
        final upgradedMatchCount = fixedMatchCount + 1;
        final upgradedTickets = packCovered.length;
        final baseTickets = 35 - upgradedTickets;
        final prize = (upgradedTickets * (_prizeTable[upgradedMatchCount] ?? 0)) +
            (baseTickets * (_prizeTable[fixedMatchCount] ?? 0));
        rows.add(
          Daily539ResultRow(
            draw: draw,
            hits: fixedHits,
            packCovered: packCovered,
            prize: prize,
            matchLabel: '固定中 $fixedMatchCount 顆',
            tagLabel: prize > 0 ? '包牌中獎' : '未中獎',
            detail: prize > 0
                ? '包牌命中 ${_formatList(packCovered)}'
                : '未中獎',
          ),
        );
        continue;
      }

      final selectedSet = selection.selected.toSet();
      final hitCount = numbers.where(selectedSet.contains).length;
      var prize = 0;
      for (var matchCount = 2; matchCount <= min(5, hitCount); matchCount++) {
        final ticketCount = _combination(hitCount, matchCount) *
            _combination(selection.comboSize - hitCount, 5 - matchCount);
        prize += ticketCount * (_prizeTable[matchCount] ?? 0);
      }
      final hits = numbers.where(selectedSet.contains).toList()..sort();
      rows.add(
        Daily539ResultRow(
          draw: draw,
          hits: hits,
          prize: prize,
          matchLabel: '對中 $hitCount 顆',
          tagLabel: prize > 0 ? '${selection.comboSize} 連碰' : '未中獎',
          detail: prize > 0 ? '命中 ${_formatList(hits)}' : '未中獎',
        ),
      );
    }
    return rows;
  }

  Daily539SelectionSummary _buildSummary(
    List<Daily539ResultRow> rows,
    Daily539Selection selection,
  ) {
    final costPerDraw = selection.costPerDraw;
    final totalCost = rows.length * costPerDraw;
    final totalPrize = rows.fold<int>(0, (sum, row) => sum + row.prize);
    final net = totalPrize - totalCost;
    final wins = rows.where((row) => row.prize > 0).length;
    return Daily539SelectionSummary(
      drawCount: rows.length,
      costPerDraw: costPerDraw,
      totalCost: totalCost,
      totalPrize: totalPrize,
      net: net,
      winCount: wins,
    );
  }

  int get _visibleCount {
    switch (_mode) {
      case Daily539Mode.combo6:
        return 6;
      case Daily539Mode.combo7:
        return 7;
      case Daily539Mode.combo8:
        return 8;
      case Daily539Mode.combo9:
        return 9;
      case Daily539Mode.single:
        return 5;
    }
  }

  int _combination(int n, int r) {
    if (r < 0 || r > n) return 0;
    var result = 1.0;
    for (var i = 1; i <= r; i++) {
      result = (result * (n - i + 1)) / i;
    }
    return result.round();
  }

  String _formatList(List<int> numbers) {
    return numbers.map(_formatNumber).join(' ');
  }

  String _prizeName(int matchCount) {
    switch (matchCount) {
      case 5:
        return '頭獎';
      case 4:
        return '貳獎';
      case 3:
        return '參獎';
      case 2:
        return '肆獎';
      default:
        return '未中獎';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E7),
      appBar: AppBar(
        title: const Text(
          '醉蝦結婚理由',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '重新抓取官方資料',
            onPressed: _isRefreshing ? null : _refreshDraws,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildHero(),
          const SizedBox(height: 16),
          _buildMarriageReasonCard(),
          const SizedBox(height: 16),
          _buildInputPanel(),
          const SizedBox(height: 16),
          _buildSummaryPanel(),
          const SizedBox(height: 16),
          _buildResultsPanel(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE6DAC7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB08A4B).withOpacity(0.15),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0D5A1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '官方今彩539結果比對',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B4A15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '輸入一注號碼，看完整連續投注收益',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2C1E0F),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '支援單注、包牌、6 連碰、7 連碰、8 連碰、9 連碰收支試算。',
            style: TextStyle(color: Color(0xFF6F6255)),
          ),
        ],
      ),
    );
  }

  Widget _buildMarriageReasonCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DCC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '醉蝦結婚理由',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C1E0F),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _shuffleReason,
                child: const Text('換一個理由'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _reason.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4B2E10),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _reason.summary,
            style: const TextStyle(color: Color(0xFF6F6255), height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            _reason.punchline,
            style: const TextStyle(
              color: Color(0xFF9A4E14),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reason.tags
                .map(
                  (tag) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4E4CA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFF6B4A15),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    final visibleCount = _visibleCount;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DCC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '輸入號碼',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C1E0F),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeChip('單注 / 包牌', Daily539Mode.single),
              _modeChip('6 連碰', Daily539Mode.combo6),
              _modeChip('7 連碰', Daily539Mode.combo7),
              _modeChip('8 連碰', Daily539Mode.combo8),
              _modeChip('9 連碰', Daily539Mode.combo9),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(visibleCount, (index) {
              final isPack = _mode == Daily539Mode.single && _packIndex == index;
              return SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '號碼 ${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF6F6255),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controllers[index],
                      enabled: !isPack,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: isPack ? '包牌' : '--',
                        filled: true,
                        fillColor: isPack
                            ? const Color(0xFFF6E9D3)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Color(0xFFE6DAC7)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Color(0xFFE6DAC7)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_mode == Daily539Mode.single)
                      TextButton(
                        onPressed: () => _togglePackIndex(index),
                        style: TextButton.styleFrom(
                          backgroundColor: isPack
                              ? const Color(0xFFD9702F)
                              : const Color(0xFFF3E7D1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isPack ? '已包牌' : '包牌',
                          style: TextStyle(
                            color: isPack
                                ? Colors.white
                                : const Color(0xFF6B4A15),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: _isLoading ? null : _analyze,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD9702F),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('開始比對'),
              ),
              OutlinedButton(
                onPressed: _applySample,
                child: const Text('帶入範例號碼'),
              ),
              OutlinedButton(
                onPressed: _clearInputs,
                child: const Text('清除號碼'),
              ),
              OutlinedButton.icon(
                onPressed: _isRefreshing ? null : _refreshDraws,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('重新抓取官方資料'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            style: const TextStyle(color: Color(0xFF6F6255)),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, Daily539Mode mode) {
    final active = _mode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => _setMode(mode),
      selectedColor: const Color(0xFFF3D5A8),
      backgroundColor: const Color(0xFFF7EBDC),
      labelStyle: TextStyle(
        color: active ? const Color(0xFF7A3B00) : const Color(0xFF6F6255),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildSummaryPanel() {
    final summary = _summary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DCC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '投注收益摘要',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C1E0F),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryTile(
                '連續筆數',
                summary?.drawCount.toString() ?? '--',
                '依官方資料更新',
              ),
              _summaryTile(
                '總投注成本',
                summary == null ? 'NT\$0' : _currencyFormat.format(summary.totalCost),
                summary == null ? '尚未比對' : '每期 ${_currencyFormat.format(summary.costPerDraw)}',
              ),
              _summaryTile(
                '總中獎金額',
                summary == null ? 'NT\$0' : _currencyFormat.format(summary.totalPrize),
                summary == null ? '尚未比對' : '中獎 ${summary.winCount} 期',
              ),
              _summaryTile(
                '淨收益',
                summary == null ? 'NT\$0' : _currencyFormat.format(summary.net),
                summary == null
                    ? '尚未比對'
                    : (summary.net >= 0 ? '小賺一點' : '口袋縮水'),
                valueColor: summary == null
                    ? const Color(0xFF2C1E0F)
                    : (summary.net >= 0
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFB91C1C)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(
    String label,
    String value,
    String note, {
    Color? valueColor,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EEDD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6F6255),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF2C1E0F),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(color: Color(0xFF6F6255), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DCC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每期對獎結果',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C1E0F),
            ),
          ),
          const SizedBox(height: 12),
          if (_results.isEmpty)
            const Text(
              '尚未開始比對。',
              style: TextStyle(color: Color(0xFF6F6255)),
            )
          else
            Column(
              children: _results.map(_buildResultRow).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildResultRow(Daily539ResultRow row) {
    final draw = row.draw;
    final numbers = draw.mainNumbers..sort();
    final hitSet = row.hits.toSet();
    final packSet = row.packCovered.toSet();
    final prizeColor =
        row.prize > 0 ? const Color(0xFF0F766E) : const Color(0xFF6F6255);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6DAC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '期別 ${draw.period}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C1E0F),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_formatRoc(draw.lotteryDate)} / ${DateFormat('yyyy/MM/dd').format(draw.lotteryDate)}',
                style: const TextStyle(color: Color(0xFF6F6255)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: prizeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.tagLabel,
                  style: TextStyle(
                    color: prizeColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: numbers.map((number) {
              final hit = hitSet.contains(number);
              final packHit = !hit && packSet.contains(number);
              return _NumberBall(
                value: number,
                backgroundColor: hit
                    ? const Color(0xFF2D8A62)
                    : packHit
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEADAC2),
                foregroundColor: hit || packHit
                    ? Colors.white
                    : const Color(0xFF6B4A15),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.matchLabel,
                  style: const TextStyle(
                    color: Color(0xFF6F6255),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _currencyFormat.format(row.prize),
                style: TextStyle(
                  color: prizeColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            row.detail,
            style: const TextStyle(color: Color(0xFF6F6255)),
          ),
        ],
      ),
    );
  }

  String _formatRoc(DateTime date) {
    final rocYear = date.year - 1911;
    return '$rocYear/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class _NumberBall extends StatelessWidget {
  final int value;
  final Color backgroundColor;
  final Color foregroundColor;

  const _NumberBall({
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _formatNumber(value),
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatNumber(int number) => number.toString().padLeft(2, '0');

class Daily539Selection {
  final Daily539Mode mode;
  final List<int> selected;
  final int packIndex;
  final int comboSize;

  const Daily539Selection({
    required this.mode,
    required this.selected,
    required this.packIndex,
    required this.comboSize,
  });

  factory Daily539Selection.single(List<int> numbers) {
    return Daily539Selection(
      mode: Daily539Mode.single,
      selected: numbers,
      packIndex: -1,
      comboSize: 5,
    );
  }

  factory Daily539Selection.pack(List<int> numbers, int packIndex) {
    return Daily539Selection(
      mode: Daily539Mode.single,
      selected: numbers,
      packIndex: packIndex,
      comboSize: 5,
    );
  }

  factory Daily539Selection.combo(List<int> numbers, int size) {
    return Daily539Selection(
      mode: switch (size) {
        6 => Daily539Mode.combo6,
        7 => Daily539Mode.combo7,
        8 => Daily539Mode.combo8,
        _ => Daily539Mode.combo9,
      },
      selected: numbers,
      packIndex: -1,
      comboSize: size,
    );
  }

  int get costPerDraw {
    if (mode == Daily539Mode.single && packIndex == -1) {
      return 50;
    }
    if (mode == Daily539Mode.single && packIndex != -1) {
      return 50 * 35;
    }
    return _combination(comboSize, 5) * 50;
  }
}

class Daily539ResultRow {
  final LotteryDraw draw;
  final List<int> hits;
  final List<int> packCovered;
  final int prize;
  final String matchLabel;
  final String tagLabel;
  final String detail;

  Daily539ResultRow({
    required this.draw,
    required this.hits,
    required this.prize,
    required this.matchLabel,
    required this.tagLabel,
    required this.detail,
    this.packCovered = const [],
  });
}

class Daily539SelectionSummary {
  final int drawCount;
  final int costPerDraw;
  final int totalCost;
  final int totalPrize;
  final int net;
  final int winCount;

  Daily539SelectionSummary({
    required this.drawCount,
    required this.costPerDraw,
    required this.totalCost,
    required this.totalPrize,
    required this.net,
    required this.winCount,
  });
}

class MarriageReason {
  final String title;
  final String summary;
  final String punchline;
  final List<String> tags;

  const MarriageReason({
    required this.title,
    required this.summary,
    required this.punchline,
    required this.tags,
  });
}

enum Daily539Mode {
  single,
  combo6,
  combo7,
  combo8,
  combo9,
}

const Map<int, int> _prizeTable = {
  5: 8000000,
  4: 20000,
  3: 300,
  2: 50,
  1: 0,
  0: 0,
};

const List<MarriageReason> _marriageReasons = [
  MarriageReason(
    title: '連中三期，命運都開始簽收了',
    summary: '當數據連續出現漂亮的上升曲線，連醉蝦都忍不住說這就是命中注定的範本。',
    punchline: '命運說可以結婚，那就不如現在。',
    tags: ['命中率', '趨勢', '心動'],
  ),
  MarriageReason(
    title: '包牌勇氣值拉滿的那一刻',
    summary: '包牌不是炫耀，是把所有可能性都留在身邊，像把承諾變成穩定的日常。',
    punchline: '每一張票都是一句「我會在」。',
    tags: ['包牌', '穩定', '決心'],
  ),
  MarriageReason(
    title: '連碰組合把緣分算到剛剛好',
    summary: '把 6 到 9 個號碼排列出所有可能，就像把未來都先排列好再慢慢相遇。',
    punchline: '懂得計算的人，也懂得照顧。',
    tags: ['連碰', '排列', '細心'],
  ),
  MarriageReason(
    title: '看著淨收益轉正的瞬間',
    summary: '收益翻正那一刻，像是未來也答應一起努力。',
    punchline: '人生不只要中獎，也要中你。',
    tags: ['收益', '成長', '一起'],
  ),
  MarriageReason(
    title: '每一期都有你，才叫長期投資',
    summary: '一張張投注記錄像是日記，記著每次共同期待。',
    punchline: '把日常變成浪漫，就是結婚的理由。',
    tags: ['長期', '日常', '浪漫'],
  ),
  MarriageReason(
    title: '號碼選對了，心也就對了',
    summary: '號碼都能挑得這麼準，人生選擇自然更準確。',
    punchline: '命中率這麼高，不如命中彼此。',
    tags: ['準確', '信任', '命中'],
  ),
  MarriageReason(
    title: '趨勢圖像我們一起長高',
    summary: '曲線一路向上，像是我們一起努力後的結果。',
    punchline: '既然趨勢向上，結婚就向前。',
    tags: ['成長', '趨勢', '向前'],
  ),
  MarriageReason(
    title: '每一次刷新都在等你好消息',
    summary: '重新抓取官方資料的那一刻，像是等待答案，也像是等待你。',
    punchline: '如果答案是你，那就結婚。',
    tags: ['等待', '好消息', '答案'],
  ),
];

int _combination(int n, int r) {
  if (r < 0 || r > n) return 0;
  var result = 1.0;
  for (var i = 1; i <= r; i++) {
    result = (result * (n - i + 1)) / i;
  }
  return result.round();
}
