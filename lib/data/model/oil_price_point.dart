class OilPricePoint {
  final DateTime marketDate;
  final double price;
  final DateTime fetchedAt;
  final String sourceUrl;

  const OilPricePoint({
    required this.marketDate,
    required this.price,
    required this.fetchedAt,
    required this.sourceUrl,
  });

  factory OilPricePoint.fromJson(Map<String, dynamic> json) {
    return OilPricePoint(
      marketDate: DateTime.parse(json['marketDate'] as String),
      price: (json['price'] as num).toDouble(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      sourceUrl: json['sourceUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'marketDate': marketDate.toIso8601String(),
      'price': price,
      'fetchedAt': fetchedAt.toIso8601String(),
      'sourceUrl': sourceUrl,
    };
  }

  OilPricePoint copyWith({
    DateTime? marketDate,
    double? price,
    DateTime? fetchedAt,
    String? sourceUrl,
  }) {
    return OilPricePoint(
      marketDate: marketDate ?? this.marketDate,
      price: price ?? this.price,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }
}
