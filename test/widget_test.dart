import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertrae20260119/data/model/subscription_item.dart';

void main() {
  group('SubscriptionItem', () {
    test('fromJson parses valid date', () {
      final json = {
        '\$id': 'abc123',
        'name': 'Netflix',
        'site': 'netflix.com',
        'price': 390,
        'nextdate': '2026-03-01T00:00:00.000Z',
        'note': '',
        'account': 'user@example.com',
      };
      final item = SubscriptionItem.fromJson(json);
      expect(item.name, 'Netflix');
      expect(item.price, 390);
      expect(item.nextDate.year, 2026);
    });

    test('fromJson uses fallback date when nextdate is null', () {
      final json = {
        '\$id': 'xyz',
        'name': 'Test',
        'site': '',
        'price': 0,
        'nextdate': null,
        'note': '',
        'account': '',
      };
      final item = SubscriptionItem.fromJson(json);
      expect(item.nextDate, DateTime(2099, 12, 31));
    });

    test('toJson contains expected keys', () {
      final item = SubscriptionItem(
        id: '1',
        name: 'Spotify',
        site: 'spotify.com',
        price: 149,
        nextDate: DateTime(2026, 4, 1),
        note: '',
        account: 'me@test.com',
      );
      final json = item.toJson();
      expect(json['name'], 'Spotify');
      expect(json['price'], 149);
      expect(json.containsKey('nextdate'), true);
    });
  });
}
