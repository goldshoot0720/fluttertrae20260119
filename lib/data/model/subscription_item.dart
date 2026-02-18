class SubscriptionItem {
  String id;
  String name;
  String site;
  int price;
  DateTime nextDate;
  String note;
  String account;
  DateTime? createdAt;
  DateTime? updatedAt;

  SubscriptionItem({
    required this.id,
    required this.name,
    required this.site,
    required this.price,
    required this.nextDate,
    required this.note,
    required this.account,
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) {
    // 無日期時使用遠未來日期，避免誤判為今天到期
    final fallbackDate = DateTime(2099, 12, 31);
    DateTime nextDate;
    try {
      nextDate = json['nextdate'] != null
          ? DateTime.parse(json['nextdate'] as String)
          : fallbackDate;
    } catch (_) {
      nextDate = fallbackDate;
    }

    return SubscriptionItem(
      id: (json['\$id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      site: (json['site'] as String?) ?? '',
      price: (json['price'] as int?) ?? 0,
      nextDate: nextDate,
      note: (json['note'] as String?) ?? '',
      account: (json['account'] as String?) ?? '',
      createdAt: json['\$createdAt'] != null ? DateTime.tryParse(json['\$createdAt'] as String) : null,
      updatedAt: json['\$updatedAt'] != null ? DateTime.tryParse(json['\$updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'site': site,
      'price': price,
      'nextdate': nextDate.toIso8601String(),
      'note': note,
      'account': account,
    };
  }
}
