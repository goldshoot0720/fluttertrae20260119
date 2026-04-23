class PhoneCompareProduct {
  final String id;
  final String brand;
  final String name;
  final int? suggestedPrice;
  final int? landtopPrice;
  final String landtopPriceLabel;
  final String sourceUrl;
  final int? jyesPrice;
  final String? jyesPriceLabel;
  final String? jyesUrl;

  const PhoneCompareProduct({
    required this.id,
    required this.brand,
    required this.name,
    required this.suggestedPrice,
    required this.landtopPrice,
    required this.landtopPriceLabel,
    required this.sourceUrl,
    this.jyesPrice,
    this.jyesPriceLabel,
    this.jyesUrl,
  });

  int? get bestPrice {
    final prices = [landtopPrice, jyesPrice].whereType<int>().toList()..sort();
    return prices.isEmpty ? null : prices.first;
  }

  String? get bestSourceLabel {
    final best = bestPrice;
    if (best == null) return null;
    if (landtopPrice == best) return '地標網通';
    if (jyesPrice == best) return '傑昇通信';
    return null;
  }

  int? get savings {
    final suggested = suggestedPrice;
    final best = bestPrice;
    if (suggested == null || best == null) return null;
    return suggested - best;
  }

  PhoneCompareProduct copyWith({
    int? jyesPrice,
    String? jyesPriceLabel,
    String? jyesUrl,
  }) {
    return PhoneCompareProduct(
      id: id,
      brand: brand,
      name: name,
      suggestedPrice: suggestedPrice,
      landtopPrice: landtopPrice,
      landtopPriceLabel: landtopPriceLabel,
      sourceUrl: sourceUrl,
      jyesPrice: jyesPrice ?? this.jyesPrice,
      jyesPriceLabel: jyesPriceLabel ?? this.jyesPriceLabel,
      jyesUrl: jyesUrl ?? this.jyesUrl,
    );
  }
}

class PhoneCompareResult {
  final String query;
  final DateTime fetchedAt;
  final List<String> sourceUrls;
  final List<String> warnings;
  final List<PhoneCompareProduct> products;

  const PhoneCompareResult({
    required this.query,
    required this.fetchedAt,
    required this.sourceUrls,
    required this.warnings,
    required this.products,
  });
}
