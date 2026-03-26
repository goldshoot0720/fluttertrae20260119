class USDebtPoint {
  final DateTime capturedAt;
  final double debt;

  const USDebtPoint({
    required this.capturedAt,
    required this.debt,
  });

  factory USDebtPoint.fromJson(Map<String, dynamic> json) {
    return USDebtPoint(
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      debt: (json['debt'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'capturedAt': capturedAt.toIso8601String(),
      'debt': debt,
    };
  }
}
