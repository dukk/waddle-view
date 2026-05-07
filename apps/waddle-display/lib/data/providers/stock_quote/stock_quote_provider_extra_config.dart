import 'dart:convert';

const int kDefaultStockMaxSymbolsPerCollect = 25;

/// Symbol entries used by [StockQuoteDataProvider] when `stock_symbols` has
/// no enabled rows. Mirrors the [WeatherProviderExtraConfig.defaultLocation]
/// pattern but as a list, since stocks are inherently multi-instrument.
const List<StockSymbolDefault> kDefaultStockSymbols = <StockSymbolDefault>[
  StockSymbolDefault(symbol: 'AAPL', displayName: 'Apple'),
  StockSymbolDefault(symbol: 'MSFT', displayName: 'Microsoft'),
  StockSymbolDefault(symbol: 'GOOG', displayName: 'Alphabet'),
  StockSymbolDefault(symbol: 'NVDA', displayName: 'NVIDIA'),
  StockSymbolDefault(symbol: 'AMZN', displayName: 'Amazon'),
];

class StockSymbolDefault {
  const StockSymbolDefault({required this.symbol, required this.displayName});

  final String symbol;
  final String displayName;
}

class StockQuoteProviderExtraConfig {
  const StockQuoteProviderExtraConfig({
    required this.maxSymbolsPerCollect,
    required this.defaultSymbols,
  });

  final int maxSymbolsPerCollect;
  final List<StockSymbolDefault> defaultSymbols;

  static StockQuoteProviderExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const StockQuoteProviderExtraConfig(
        maxSymbolsPerCollect: kDefaultStockMaxSymbolsPerCollect,
        defaultSymbols: kDefaultStockSymbols,
      );
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return parse(null);
      }
      final m = Map<String, dynamic>.from(decoded);
      final maxRaw = m['maxSymbolsPerCollect'];
      final max = (maxRaw is num && maxRaw.toInt() >= 1)
          ? maxRaw.toInt()
          : kDefaultStockMaxSymbolsPerCollect;
      final symbols = _parseSymbols(m['defaultSymbols']);
      return StockQuoteProviderExtraConfig(
        maxSymbolsPerCollect: max,
        defaultSymbols:
            symbols.isNotEmpty ? List.unmodifiable(symbols) : kDefaultStockSymbols,
      );
    } on Object {
      return parse(null);
    }
  }

  static List<StockSymbolDefault> _parseSymbols(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final out = <StockSymbolDefault>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final m = Map<String, dynamic>.from(entry);
      final sym = (m['symbol'] as String?)?.trim();
      if (sym == null || sym.isEmpty) {
        continue;
      }
      final name = (m['displayName'] as String?)?.trim() ?? '';
      out.add(StockSymbolDefault(
        symbol: sym.toUpperCase(),
        displayName: name,
      ));
    }
    return out;
  }
}
