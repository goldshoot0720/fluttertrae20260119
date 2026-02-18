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
    return SubscriptionItem(
      id: json['\$id'] ?? '',
      name: json['name'] ?? '',
      site: json['site'] ?? '',
      price: json['price'] ?? 0,
      nextDate: DateTime.parse(json['nextdate']),
      note: json['note'] ?? '',
      account: json['account'] ?? '',
      createdAt: json['\$createdAt'] != null ? DateTime.parse(json['\$createdAt']) : null,
      updatedAt: json['\$updatedAt'] != null ? DateTime.parse(json['\$updatedAt']) : null,
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
