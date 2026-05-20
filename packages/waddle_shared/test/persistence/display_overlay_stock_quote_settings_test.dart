import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_stock_quote_settings.dart';

void main() {
  test('parse defaults when empty', () {
    expect(
      StockQuoteOverlaySettings.parse(''),
      StockQuoteOverlaySettings.defaults,
    );
  });

  test('parse placement and symbolId', () {
    final s = StockQuoteOverlaySettings.parseMap({
      'symbolId': ' aapl ',
      'x': 0.1,
      'y': 0.2,
      'scale': 0.25,
    });
    expect(s.symbolId, 'aapl');
    expect(s.placement.x, 0.1);
    expect(s.placement.scale, 0.25);
  });

  test('normalize strips enabled and messages', () {
    final norm = normalizeStockQuoteOverlayConfigJsonString(
      '{"enabled":true,"messages":["x"],"symbolId":"msft","x":0.5,"y":0.5}',
    );
    expect(norm, isNotNull);
    final parsed = StockQuoteOverlaySettings.parse(norm!);
    expect(parsed.symbolId, 'msft');
    expect(parsed.placement.x, 0.5);
  });

  test('normalize rejects empty symbolId', () {
    expect(
      normalizeStockQuoteOverlayConfigJsonString('{"symbolId": ""}'),
      isNull,
    );
    expect(
      normalizeStockQuoteOverlayConfigJsonString('{"symbolId": 1}'),
      isNull,
    );
    expect(
      normalizeStockQuoteOverlayConfigJsonString('{}'),
      '{}',
    );
  });
}
