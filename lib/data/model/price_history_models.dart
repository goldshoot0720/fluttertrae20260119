class PricePoint {
  final int x;
  final int y;

  const PricePoint({
    required this.x,
    required this.y,
  });

  factory PricePoint.fromJson(Map<String, dynamic> json) {
    return PricePoint(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
    );
  }
}

class PriceInterval {
  final int years;
  final int months;
  final int days;

  const PriceInterval({
    required this.years,
    required this.months,
    required this.days,
  });

  factory PriceInterval.fromJson(Map<String, dynamic>? json) {
    return PriceInterval(
      years: (json?['years'] as num?)?.toInt() ?? 0,
      months: (json?['months'] as num?)?.toInt() ?? 0,
      days: (json?['days'] as num?)?.toInt() ?? 0,
    );
  }
}

class PriceStats {
  final int latestPrice;
  final int oldestPrice;
  final int highestPrice;
  final int lowestPrice;
  final double averagePrice;
  final double medianPrice;
  final int latestMinusLowest;
  final PriceInterval interval;

  const PriceStats({
    required this.latestPrice,
    required this.oldestPrice,
    required this.highestPrice,
    required this.lowestPrice,
    required this.averagePrice,
    required this.medianPrice,
    required this.latestMinusLowest,
    required this.interval,
  });

  factory PriceStats.fromJson(Map<String, dynamic>? json) {
    return PriceStats(
      latestPrice: (json?['latest_price'] as num?)?.toInt() ?? 0,
      oldestPrice: (json?['oldest_price'] as num?)?.toInt() ?? 0,
      highestPrice: (json?['highest_price'] as num?)?.toInt() ?? 0,
      lowestPrice: (json?['lowest_price'] as num?)?.toInt() ?? 0,
      averagePrice: (json?['average_price'] as num?)?.toDouble() ?? 0,
      medianPrice: (json?['median_price'] as num?)?.toDouble() ?? 0,
      latestMinusLowest: (json?['latest_minus_lowest'] as num?)?.toInt() ?? 0,
      interval: PriceInterval.fromJson(
        json?['latest_lowest_interval'] as Map<String, dynamic>?,
      ),
    );
  }
}

class RecentPriceUrl {
  final String url;
  final String title;
  final String matchedTitle;

  const RecentPriceUrl({
    required this.url,
    required this.title,
    required this.matchedTitle,
  });

  factory RecentPriceUrl.fromJson(Map<String, dynamic> json) {
    return RecentPriceUrl(
      url: (json['url'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      matchedTitle: (json['matched_title'] as String?) ?? '',
    );
  }
}

class PriceHistoryPayload {
  final String title;
  final String subtitle;
  final String sourceUrl;
  final List<PricePoint> history;
  final List<PricePoint> sampledHistory;
  final Map<String, PricePoint> highlights;
  final PriceStats stats;

  const PriceHistoryPayload({
    required this.title,
    required this.subtitle,
    required this.sourceUrl,
    required this.history,
    required this.sampledHistory,
    required this.highlights,
    required this.stats,
  });

  factory PriceHistoryPayload.fromJson(Map<String, dynamic> json) {
    final history = (json['history'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PricePoint.fromJson)
        .toList();
    final sampled = (json['sampled_history'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PricePoint.fromJson)
        .toList();
    final highlightMap = <String, PricePoint>{};
    final rawHighlights = json['highlights'];
    if (rawHighlights is Map<String, dynamic>) {
      rawHighlights.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          highlightMap[key] = PricePoint.fromJson(value);
        }
      });
    }

    return PriceHistoryPayload(
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      sourceUrl: (json['input_url'] as String?) ?? (json['source_url'] as String?) ?? '',
      history: history,
      sampledHistory: sampled,
      highlights: highlightMap,
      stats: PriceStats.fromJson(json['stats'] as Map<String, dynamic>?),
    );
  }
}
