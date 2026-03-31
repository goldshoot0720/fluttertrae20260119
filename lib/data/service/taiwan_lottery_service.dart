import 'dart:convert';
import 'dart:io';

import '../model/lottery_draw.dart';

class TaiwanLotteryService {
  static const String _apiBaseUrl = 'https://api.taiwanlottery.com/TLCAPIWeB';

  static const String superLottoSourceUrl =
      'https://www.taiwanlottery.com/lotto/result/super_lotto638';
  static const String lotto649SourceUrl =
      'https://www.taiwanlottery.com/lotto/result/lotto649';
  static const String daily539SourceUrl =
      'https://www.taiwanlottery.com/lotto/result/daily_cash';

  static const List<LotteryTicketSet> superLottoTickets = [
    LotteryTicketSet(
      label: '第一組',
      mainNumbers: [7, 11, 23, 32, 33, 38],
      specialNumber: 2,
    ),
    LotteryTicketSet(
      label: '第二組',
      mainNumbers: [7, 11, 23, 32, 33, 38],
      specialNumber: 1,
    ),
    LotteryTicketSet(
      label: '第三組',
      mainNumbers: [19, 8, 11, 27, 37, 16],
      specialNumber: 8,
    ),
    LotteryTicketSet(
      label: '第四組',
      mainNumbers: [19, 8, 4, 3, 37, 16],
      specialNumber: 8,
    ),
  ];

  static const List<LotteryTicketSet> lotto649Tickets = [
    LotteryTicketSet(
      label: '第一組',
      mainNumbers: [19, 8, 11, 27, 37, 16],
    ),
    LotteryTicketSet(
      label: '第二組',
      mainNumbers: [19, 8, 4, 3, 37, 16],
    ),
  ];

  static const List<LotteryTicketSet> daily539Tickets = [
    LotteryTicketSet(
      label: '第一組',
      mainNumbers: [19, 8, 11, 27, 37],
    ),
    LotteryTicketSet(
      label: '第二組',
      mainNumbers: [19, 8, 4, 3, 37],
    ),
  ];

  Future<LotteryDashboardData> fetchDashboardData() async {
    final now = DateTime.now();
    final ranges = _buildMonthRanges(now);

    final superLottoDraws = await _fetchDraws(
      endpoint: '/Lottery/SuperLotto638Result',
      listKey: 'superLotto638Res',
      gameType: LotteryGameType.superLotto638,
      ranges: ranges,
    );
    final lotto649Draws = await _fetchDraws(
      endpoint: '/Lottery/Lotto649Result',
      listKey: 'lotto649Res',
      gameType: LotteryGameType.lotto649,
      ranges: ranges,
    );
    final daily539Draws = await _fetchDraws(
      endpoint: '/Lottery/Daily539Result',
      listKey: 'daily539Res',
      gameType: LotteryGameType.daily539,
      ranges: ranges,
    );

    return LotteryDashboardData(
      fetchedAt: now,
      sections: [
        LotteryGameSection(
          gameType: LotteryGameType.superLotto638,
          title: '威力彩',
          sourceUrl: superLottoSourceUrl,
          tickets: superLottoTickets,
          draws: superLottoDraws,
        ),
        LotteryGameSection(
          gameType: LotteryGameType.lotto649,
          title: '大樂透',
          sourceUrl: lotto649SourceUrl,
          tickets: lotto649Tickets,
          draws: lotto649Draws,
        ),
        LotteryGameSection(
          gameType: LotteryGameType.daily539,
          title: '今彩539',
          sourceUrl: daily539SourceUrl,
          tickets: daily539Tickets,
          draws: daily539Draws,
        ),
      ],
    );
  }

  List<LotteryTicketMatch> compareTickets(
    LotteryDraw draw,
    List<LotteryTicketSet> tickets,
  ) {
    return tickets.map((ticket) {
      final matchedMainNumbers = ticket.mainNumbers
          .where(draw.mainNumbers.contains)
          .toList()
        ..sort();
      final specialMatched = ticket.specialNumber != null &&
          draw.specialNumber != null &&
          ticket.specialNumber == draw.specialNumber;

      return LotteryTicketMatch(
        ticket: ticket,
        matchedMainNumbers: matchedMainNumbers,
        specialMatched: specialMatched,
        prizeLabel: _resolvePrizeLabel(
          gameType: draw.gameType,
          matchedCount: matchedMainNumbers.length,
          specialMatched: specialMatched,
        ),
      );
    }).toList();
  }

  Future<List<LotteryDraw>> _fetchDraws({
    required String endpoint,
    required String listKey,
    required LotteryGameType gameType,
    required List<_MonthRange> ranges,
  }) async {
    final draws = <LotteryDraw>[];

    for (final range in ranges) {
      final response = await _getJson(
        endpoint,
        params: {
          'month': range.startMonth,
          'endMonth': range.endMonth,
          'pageNum': '1',
          'pageSize': '200',
        },
      );

      final content = response['content'];
      if (content is! Map<String, dynamic>) {
        continue;
      }

      final rawList = content[listKey];
      if (rawList is! List) {
        continue;
      }

      draws.addAll(
        rawList
            .whereType<Map<String, dynamic>>()
            .map((item) => _mapDraw(item, gameType)),
      );
    }

    final uniqueByPeriod = <String, LotteryDraw>{};
    for (final draw in draws) {
      uniqueByPeriod[draw.period] = draw;
    }

    final sorted = uniqueByPeriod.values.toList()
      ..sort((a, b) => b.lotteryDate.compareTo(a.lotteryDate));
    return sorted;
  }

  LotteryDraw _mapDraw(Map<String, dynamic> json, LotteryGameType gameType) {
    final drawNumbersSize =
        (json['drawNumberSize'] as List? ?? const []).cast<num>().map((n) => n.toInt()).toList();
    final drawNumbersAppear =
        (json['drawNumberAppear'] as List? ?? const []).cast<num>().map((n) => n.toInt()).toList();

    final hasSpecialNumber = switch (gameType) {
      LotteryGameType.superLotto638 => true,
      LotteryGameType.lotto649 => true,
      LotteryGameType.daily539 => false,
    };

    final mainNumbers =
        hasSpecialNumber ? drawNumbersSize.take(drawNumbersSize.length - 1).toList() : drawNumbersSize;
    final specialNumber = hasSpecialNumber && drawNumbersSize.isNotEmpty
        ? drawNumbersSize.last
        : null;

    return LotteryDraw(
      gameType: gameType,
      period: '${json['period'] ?? ''}',
      lotteryDate: DateTime.parse('${json['lotteryDate']}'),
      redeemableDate: DateTime.parse('${json['redeemableDate']}'),
      mainNumbers: mainNumbers,
      drawNumbersByOrder: drawNumbersAppear,
      specialNumber: specialNumber,
      sellAmount: (json['sellAmount'] as num?)?.toInt(),
      totalAmount: (json['totalAmount'] as num?)?.toInt(),
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    final uri = Uri.parse('$_apiBaseUrl$endpoint').replace(
      queryParameters: params,
    );

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    client.userAgent = 'SubscriptionManager/1.0.4 LotteryCompare';

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Unexpected status ${response.statusCode} from $uri',
          uri: uri,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Lottery API returned an unexpected payload.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  List<_MonthRange> _buildMonthRanges(DateTime now) {
    final ranges = <_MonthRange>[];
    var cursor = DateTime(now.year, 1);
    final end = DateTime(now.year, now.month);

    while (!cursor.isAfter(end)) {
      final rangeStart = cursor;
      final rangeEndMonth = cursor.month + 2;
      final cappedEnd = rangeEndMonth > end.month
          ? end
          : DateTime(cursor.year, rangeEndMonth);

      ranges.add(
        _MonthRange(
          startMonth: _formatMonth(rangeStart),
          endMonth: _formatMonth(cappedEnd),
        ),
      );

      cursor = DateTime(cursor.year, cursor.month + 3);
    }

    return ranges;
  }

  String _formatMonth(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  String _resolvePrizeLabel({
    required LotteryGameType gameType,
    required int matchedCount,
    required bool specialMatched,
  }) {
    switch (gameType) {
      case LotteryGameType.superLotto638:
        if (matchedCount == 6 && specialMatched) return '頭獎';
        if (matchedCount == 6) return '貳獎';
        if (matchedCount == 5 && specialMatched) return '參獎';
        if (matchedCount == 5) return '肆獎';
        if (matchedCount == 4 && specialMatched) return '伍獎';
        if (matchedCount == 4) return '陸獎';
        if (matchedCount == 3 && specialMatched) return '柒獎';
        if (matchedCount == 2 && specialMatched) return '捌獎';
        if (matchedCount == 3) return '玖獎';
        if (matchedCount == 1 && specialMatched) return '普獎';
        return '未中獎';
      case LotteryGameType.lotto649:
        if (matchedCount == 6) return '頭獎';
        if (matchedCount == 5 && specialMatched) return '貳獎';
        if (matchedCount == 5) return '參獎';
        if (matchedCount == 4 && specialMatched) return '肆獎';
        if (matchedCount == 4) return '伍獎';
        if (matchedCount == 3 && specialMatched) return '陸獎';
        if (matchedCount == 2 && specialMatched) return '柒獎';
        if (matchedCount == 3) return '普獎';
        return '未中獎';
      case LotteryGameType.daily539:
        if (matchedCount == 5) return '頭獎';
        if (matchedCount == 4) return '貳獎';
        if (matchedCount == 3) return '參獎';
        if (matchedCount == 2) return '肆獎';
        return '未中獎';
    }
  }
}

class _MonthRange {
  final String startMonth;
  final String endMonth;

  const _MonthRange({
    required this.startMonth,
    required this.endMonth,
  });
}
