import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertrae20260119/data/model/subscription_item.dart';

void main() {
  test('SubscriptionItem.fromDocument maps Appwrite metadata', () {
    final item = SubscriptionItem.fromDocument(
      id: 'doc-123',
      createdAt: '2026-03-19T10:00:00.000Z',
      updatedAt: '2026-03-20T11:30:00.000Z',
      data: {
        'name': 'Netflix',
        'site': 'netflix.com',
        'price': 15,
        'nextdate': '2026-03-25T00:00:00.000Z',
        'note': 'family',
        'account': 'demo@example.com',
      },
    );

    expect(item.id, 'doc-123');
    expect(item.name, 'Netflix');
    expect(item.site, 'netflix.com');
    expect(item.price, 15);
    expect(item.nextDate, DateTime.parse('2026-03-25T00:00:00.000Z'));
    expect(item.note, 'family');
    expect(item.account, 'demo@example.com');
    expect(item.createdAt, DateTime.parse('2026-03-19T10:00:00.000Z'));
    expect(item.updatedAt, DateTime.parse('2026-03-20T11:30:00.000Z'));
  });
}
