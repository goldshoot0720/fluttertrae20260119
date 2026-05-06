enum FengBroFinanceSignal { none, recordHigh, recordLow }

class FengBroFinanceInstrument {
  final String id;
  final String name;
  final String symbol;
  final String url;
  final String category;
  final String unit;

  const FengBroFinanceInstrument({
    required this.id,
    required this.name,
    required this.symbol,
    required this.url,
    required this.category,
    required this.unit,
  });
}

class FengBroFinanceQuote {
  final FengBroFinanceInstrument instrument;
  final double? last;
  final double? change;
  final double? changePercent;
  final double? dayHigh;
  final double? dayLow;
  final double? week52High;
  final double? week52Low;
  final DateTime fetchedAt;
  final FengBroFinanceSignal? signalOverride;
  final String? warning;

  const FengBroFinanceQuote({
    required this.instrument,
    required this.last,
    required this.change,
    required this.changePercent,
    required this.dayHigh,
    required this.dayLow,
    required this.week52High,
    required this.week52Low,
    required this.fetchedAt,
    this.signalOverride,
    this.warning,
  });

  FengBroFinanceSignal get signal {
    final override = signalOverride;
    if (override != null && override != FengBroFinanceSignal.none) {
      return override;
    }
    final price = last;
    if (price == null) return FengBroFinanceSignal.none;
    final high = week52High;
    final low = week52Low;
    if (high != null && price >= high) {
      return FengBroFinanceSignal.recordHigh;
    }
    if (low != null && price <= low) {
      return FengBroFinanceSignal.recordLow;
    }
    return FengBroFinanceSignal.none;
  }

  bool get isPositive => (change ?? 0) > 0 || (changePercent ?? 0) > 0;
  bool get isNegative => (change ?? 0) < 0 || (changePercent ?? 0) < 0;
}

class FengBroFinanceSummary {
  final DateTime fetchedAt;
  final List<FengBroFinanceQuote> quotes;

  const FengBroFinanceSummary({required this.fetchedAt, required this.quotes});

  int get recordHighCount => quotes
      .where((quote) => quote.signal == FengBroFinanceSignal.recordHigh)
      .length;

  int get recordLowCount => quotes
      .where((quote) => quote.signal == FengBroFinanceSignal.recordLow)
      .length;
}
