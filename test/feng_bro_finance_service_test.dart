import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertrae20260119/data/model/feng_bro_finance_models.dart';
import 'package:fluttertrae20260119/data/service/feng_bro_finance_service.dart';

void main() {
  group('FengBroFinanceService parser', () {
    test('parses CNBC quote text and detects record high', () {
      const instrument = FengBroFinanceInstrument(
        id: 'sample',
        name: 'Sample Index',
        symbol: '.SAMPLE',
        url: 'https://www.cnbc.com/quotes/.SAMPLE',
        category: 'Index',
        unit: 'USD',
      );
      const html = '''
        <h1>Sample Index</h1>
        <div>Last | 3:45 PM EDT</div>
        <div>70,000.00<span>+125.50 (+0.18%)</span></div>
        <div>52 week range</div>
        <dl>
          <dt>Day High</dt><dd>70,000.00</dd>
          <dt>Day Low</dt><dd>69,200.20</dd>
          <dt>52 Week High</dt><dd>70,000.00</dd>
          <dt>52 Week Low</dt><dd>49,500.00</dd>
        </dl>
      ''';

      final quote = FengBroFinanceService.parseCnbcQuoteFromHtml(
        instrument,
        html,
        DateTime(2026, 5, 6),
      );

      expect(quote.last, 70000);
      expect(quote.change, 125.50);
      expect(quote.changePercent, 0.18);
      expect(quote.dayHigh, 70000);
      expect(quote.week52High, 70000);
      expect(quote.week52Low, 49500);
      expect(quote.signal, FengBroFinanceSignal.recordHigh);
    });

    test('detects record low from 52 week low', () {
      const instrument = FengBroFinanceInstrument(
        id: 'sample-low',
        name: 'Sample Low',
        symbol: 'LOW',
        url: 'https://www.cnbc.com/quotes/LOW',
        category: 'Index',
        unit: 'USD',
      );
      const html = '''
        Last | 4:00 PM EDT
        18.25 Image: quote price arrow down -1.00 (-5.19%)
        52 Week High 40.00
        52 Week Low 18.25
      ''';

      final quote = FengBroFinanceService.parseCnbcQuoteFromHtml(
        instrument,
        html,
        DateTime(2026, 5, 6),
      );

      expect(quote.last, 18.25);
      expect(quote.signal, FengBroFinanceSignal.recordLow);
    });

    test('parses Yahoo Taiwan quote text and detects record high wording', () {
      const instrument = FengBroFinanceInstrument(
        id: 'tsmc',
        name: '台積電',
        symbol: '2330.TW',
        url: 'https://tw.stock.yahoo.com/quote/2330.TW',
        category: 'Taiwan Stock',
        unit: 'TWD',
      );
      const html = '''
        <h1>台積電即時行情</h1>
        <ul>
          <li>成交2,080</li>
          <li>開盤2,065</li>
          <li>最高2,100</li>
          <li>最低2,060</li>
          <li>漲跌幅1.22%</li>
          <li>漲跌25.00</li>
        </ul>
        <p>台積電終場市值達53.94兆元再創新高。</p>
      ''';

      final quote = FengBroFinanceService.parseYahooQuoteFromHtml(
        instrument,
        html,
        DateTime(2026, 5, 6),
      );

      expect(quote.last, 2080);
      expect(quote.dayHigh, 2100);
      expect(quote.dayLow, 2060);
      expect(quote.change, 25);
      expect(quote.changePercent, 1.22);
      expect(quote.signal, FengBroFinanceSignal.recordHigh);
    });
  });
}
