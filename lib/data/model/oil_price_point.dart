class OilPricePoint {
  final DateTime capturedAt;
  final double price;
  final String publishedLabel;

  const OilPricePoint({
    required this.capturedAt,
    required this.price,
    required this.publishedLabel,
  });

  factory OilPricePoint.fromJson(Map<String, dynamic> json) {
    return OilPricePoint(
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      price: (json['price'] as num).toDouble(),
      publishedLabel: json['publishedLabel'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'capturedAt': capturedAt.toIso8601String(),
      'price': price,
      'publishedLabel': publishedLabel,
    };
  }
}
