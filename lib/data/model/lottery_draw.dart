enum LotteryGameType {
  superLotto638,
  lotto649,
  daily539,
}

class LotteryTicketSet {
  final String label;
  final List<int> mainNumbers;
  final int? specialNumber;

  const LotteryTicketSet({
    required this.label,
    required this.mainNumbers,
    this.specialNumber,
  });
}

class LotteryDraw {
  final LotteryGameType gameType;
  final String period;
  final DateTime lotteryDate;
  final DateTime redeemableDate;
  final List<int> mainNumbers;
  final List<int> drawNumbersByOrder;
  final int? specialNumber;
  final int? sellAmount;
  final int? totalAmount;

  const LotteryDraw({
    required this.gameType,
    required this.period,
    required this.lotteryDate,
    required this.redeemableDate,
    required this.mainNumbers,
    required this.drawNumbersByOrder,
    required this.specialNumber,
    required this.sellAmount,
    required this.totalAmount,
  });
}

class LotteryTicketMatch {
  final LotteryTicketSet ticket;
  final List<int> matchedMainNumbers;
  final bool specialMatched;
  final String prizeLabel;

  const LotteryTicketMatch({
    required this.ticket,
    required this.matchedMainNumbers,
    required this.specialMatched,
    required this.prizeLabel,
  });

  int get matchedCount => matchedMainNumbers.length;

  bool get isWinning => prizeLabel != '未中獎';
}

class LotteryGameSection {
  final LotteryGameType gameType;
  final String title;
  final String sourceUrl;
  final List<LotteryTicketSet> tickets;
  final List<LotteryDraw> draws;

  const LotteryGameSection({
    required this.gameType,
    required this.title,
    required this.sourceUrl,
    required this.tickets,
    required this.draws,
  });
}

class LotteryDashboardData {
  final DateTime fetchedAt;
  final List<LotteryGameSection> sections;

  const LotteryDashboardData({
    required this.fetchedAt,
    required this.sections,
  });
}
