import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertrae20260119/data/service/oil_price_service.dart';

void main() {
  group('OilPriceService parser', () {
    test('parses top banner format', () {
      const html = '''
      <html>
        <body>
          <div>OQD Marker Price March 19, 2026 is 166.96</div>
        </body>
      </html>
      ''';

      final point = OilPriceService.parseMarkerPriceFromHtml(html);

      expect(point.price, 166.96);
      expect(point.marketDate.year, 2026);
      expect(point.marketDate.month, 3);
      expect(point.marketDate.day, 19);
    });

    test('parses market summary format', () {
      const html = '''
      <html>
        <body>
          <section>
            <h2>OQD Daily Marker Price</h2>
            <div>166.96</div>
            <div>19 Mar-2026</div>
          </section>
        </body>
      </html>
      ''';

      final point = OilPriceService.parseMarkerPriceFromHtml(html);

      expect(point.price, 166.96);
      expect(point.marketDate.year, 2026);
      expect(point.marketDate.month, 3);
      expect(point.marketDate.day, 19);
    });
  });
}
