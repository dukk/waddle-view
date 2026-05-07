import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/stock_quote/stock_quote_provider_extra_config.dart';

void main() {
  test('parse(null) yields built-in defaults', () {
    final cfg = StockQuoteProviderExtraConfig.parse(null);
    expect(cfg.maxSymbolsPerCollect, kDefaultStockMaxSymbolsPerCollect);
    expect(cfg.defaultSymbols, kDefaultStockSymbols);
  });

  test('parse empty string yields built-in defaults', () {
    final cfg = StockQuoteProviderExtraConfig.parse('   ');
    expect(cfg.maxSymbolsPerCollect, kDefaultStockMaxSymbolsPerCollect);
    expect(cfg.defaultSymbols, kDefaultStockSymbols);
  });

  test('parse honors maxSymbolsPerCollect override', () {
    final cfg = StockQuoteProviderExtraConfig.parse(
      '{"maxSymbolsPerCollect":5}',
    );
    expect(cfg.maxSymbolsPerCollect, 5);
  });

  test('parse rejects non-positive maxSymbolsPerCollect and falls back', () {
    final cfg = StockQuoteProviderExtraConfig.parse(
      '{"maxSymbolsPerCollect":0}',
    );
    expect(cfg.maxSymbolsPerCollect, kDefaultStockMaxSymbolsPerCollect);
  });

  test('parse reads defaultSymbols list and trims fields', () {
    final cfg = StockQuoteProviderExtraConfig.parse(
      '{"defaultSymbols":[{"symbol":"  aapl  ","displayName":" Apple "},'
      '{"symbol":"MSFT"}]}',
    );
    expect(cfg.defaultSymbols, hasLength(2));
    expect(cfg.defaultSymbols.first.symbol, 'AAPL');
    expect(cfg.defaultSymbols.first.displayName, 'Apple');
    expect(cfg.defaultSymbols.last.symbol, 'MSFT');
    expect(cfg.defaultSymbols.last.displayName, '');
  });

  test('parse skips invalid default-symbol entries', () {
    final cfg = StockQuoteProviderExtraConfig.parse(
      '{"defaultSymbols":[{"symbol":""},{"symbol":"GOOG"},42,{"foo":"bar"}]}',
    );
    expect(cfg.defaultSymbols, hasLength(1));
    expect(cfg.defaultSymbols.single.symbol, 'GOOG');
  });

  test('parse falls back to defaults when JSON is malformed', () {
    final cfg = StockQuoteProviderExtraConfig.parse('not-json');
    expect(cfg.maxSymbolsPerCollect, kDefaultStockMaxSymbolsPerCollect);
    expect(cfg.defaultSymbols, kDefaultStockSymbols);
  });

  test('parse falls back to defaults when JSON is not an object', () {
    final cfg = StockQuoteProviderExtraConfig.parse('[1,2,3]');
    expect(cfg.maxSymbolsPerCollect, kDefaultStockMaxSymbolsPerCollect);
  });
}
