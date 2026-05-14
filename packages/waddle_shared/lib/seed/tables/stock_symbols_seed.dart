import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/database.dart';

/// Idempotent default symbol list (AAPL/MSFT enabled, the rest disabled to
/// limit API hits). Operators can toggle [StockSymbols.enabled] from the admin
/// surface without touching the provider config.
Future<void> ensureStockSymbolsSeed(AppDatabase db) async {
  Future<void> ensure(
    String id,
    String symbol,
    String displayName, {
    required bool enabled,
  }) async {
    final existing = await (db.select(db.stockSymbols)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
            id: id,
            symbol: symbol,
            displayName: Value(displayName),
            enabled: Value(enabled),
          ),
        );
  }

  await ensure('aapl', 'AAPL', 'Apple', enabled: true);
  await ensure('msft', 'MSFT', 'Microsoft', enabled: true);
  await ensure('goog', 'GOOG', 'Alphabet', enabled: true);
  await ensure('nvda', 'NVDA', 'NVIDIA', enabled: true);
  await ensure('amzn', 'AMZN', 'Amazon', enabled: false);
  await ensure('tsla', 'TSLA', 'Tesla', enabled: false);
  await ensure('meta', 'META', 'Meta', enabled: false);
  await ensure('nflx', 'NFLX', 'Netflix', enabled: false);
  await ensure('dis', 'DIS', 'Disney', enabled: false);
  await ensure('ibm', 'IBM', 'IBM', enabled: false);
  await ensure('csco', 'CSCO', 'Cisco', enabled: false);
  await ensure('intc', 'INTC', 'Intel', enabled: false);
  await ensure('orcl', 'ORCL', 'Oracle', enabled: false);
  await ensure('voo', 'VOO', 'Vanguard S&P 500 ETF', enabled: true);
  await ensure('spy', 'SPY', 'SPDR S&P 500 ETF', enabled: true);
  await ensure('qqq', 'QQQ', 'Invesco QQQ Trust', enabled: false);
  await ensure('iwm', 'IWM', 'iShares Russell 2000 ETF', enabled: false);
}
