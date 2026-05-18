import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/stock_finnhub/stock_quote_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _FinnhubClient extends http.BaseClient {
  _FinnhubClient(this.onRequest);

  final http.Response Function(Uri uri) onRequest;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends += 1;
    final response = onRequest(request.url);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class _ThrowingFinnhubClient extends http.BaseClient {
  _ThrowingFinnhubClient(this.error);

  final Object error;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends += 1;
    throw error;
  }
}

String _quotePayload({
  required double current,
  double change = 0.5,
  double percent = 0.4,
  double high = 0,
  double low = 0,
  double open = 0,
  double previousClose = 0,
  int t = 1714960000,
}) {
  return jsonEncode({
    'c': current,
    'd': change,
    'dp': percent,
    'h': high,
    'l': low,
    'o': open,
    'pc': previousClose,
    't': t,
  });
}

Future<DataWriteContextImpl> _ctx(
  AppDatabase db,
  InMemorySecretStore secrets, {
  String? apiKey,
}) async {
  if (apiKey != null) {
    await secrets.write(providerAccessTokenSecretKey(kDefaultStockFinnhubIntegrationId), apiKey);
  }
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

Future<void> _seedProviderRow(
  AppDatabase db, {
  bool enabled = true,
  String? configJson,
}) async {
  await db.into(db.integrations).insert(
        IntegrationsCompanion.insert(
          id: kDefaultStockFinnhubIntegrationId,
          integrationType: kStockProviderId,
          pollSeconds: const Value(60),
          enabled: Value(enabled),
          baseUrl: const Value(kDefaultFinnhubBaseUrl),
          configJson: Value(configJson),
        ),
      );
}

void main() {
  test('collect skips when access token missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets);
    final client = _FinnhubClient(
      (_) => http.Response(_quotePayload(current: 100), 200),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 0);
    expect(await db.select(db.stockQuotes).get(), isEmpty);
    await db.close();
  });

  test('collect skips when provider row is disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db, enabled: false);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _FinnhubClient(
      (_) => http.Response(_quotePayload(current: 100), 200),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 0);
    expect(await db.select(db.stockQuotes).get(), isEmpty);
    await db.close();
  });

  test('collect writes one row per enabled symbol', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'aapl',
            symbol: 'AAPL',
            displayName: const Value('Apple'),
          ),
        );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'msft',
            symbol: 'MSFT',
            displayName: const Value('Microsoft'),
          ),
        );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'goog',
            symbol: 'GOOG',
            enabled: const Value(false),
          ),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final seenSymbols = <String>[];
    final client = _FinnhubClient((uri) {
      final symbol = uri.queryParameters['symbol']!;
      seenSymbols.add(symbol);
      return http.Response(
        _quotePayload(
          current: symbol == 'AAPL' ? 261.74 : 412.5,
          change: 0.11,
          percent: 0.042,
          high: symbol == 'AAPL' ? 263.31 : 414.0,
          low: symbol == 'AAPL' ? 260.68 : 410.0,
          open: 261.0,
          previousClose: 261.63,
          t: 1714960000,
        ),
        200,
      );
    });
    final provider = StockQuoteDataProvider(
      httpClient: client,
      nowMs: () => 7000,
    );

    await provider.collect(ctx);

    expect(client.sends, 2);
    expect(seenSymbols.toSet(), {'AAPL', 'MSFT'});
    final rows = await db.select(db.stockQuotes).get();
    expect(rows, hasLength(2));
    final aapl = rows.firstWhere((r) => r.symbolId == 'aapl');
    expect(aapl.currentPrice, closeTo(261.74, 0.001));
    expect(aapl.changeAmount, closeTo(0.11, 0.001));
    expect(aapl.percentChange, closeTo(0.042, 0.001));
    expect(aapl.highOfDay, closeTo(263.31, 0.001));
    expect(aapl.lowOfDay, closeTo(260.68, 0.001));
    expect(aapl.openPrice, closeTo(261.0, 0.001));
    expect(aapl.previousClose, closeTo(261.63, 0.001));
    expect(aapl.observedAtMs, DateTime.fromMillisecondsSinceEpoch(7000));
    expect(aapl.quotedAtMs, DateTime.fromMillisecondsSinceEpoch(1714960000000));
    await db.close();
  });

  test('collect token sent in query parameter, not symbol id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    Uri? observed;
    final client = _FinnhubClient((uri) {
      observed = uri;
      return http.Response(_quotePayload(current: 50), 200);
    });
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(observed, isNotNull);
    expect(observed!.path, '/api/v1/quote');
    expect(observed!.queryParameters['symbol'], 'AAPL');
    expect(observed!.queryParameters['token'], 'finnhub-key');
    await db.close();
  });

  test('collect falls back to defaultSymbols when interests_stock_symbols empty', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(
      db,
      configJson: jsonEncode({
        'maxSymbolsPerCollect': 10,
        'defaultSymbols': [
          {'symbol': 'TSLA', 'displayName': 'Tesla'},
          {'symbol': 'NFLX', 'displayName': 'Netflix'},
        ],
      }),
    );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _FinnhubClient(
      (_) => http.Response(_quotePayload(current: 50), 200),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 2);
    final symbols = await db.select(db.interestsStockSymbols).get();
    expect(symbols.map((r) => r.symbol).toSet(), {'TSLA', 'NFLX'});
    final quotes = await db.select(db.stockQuotes).get();
    expect(quotes, hasLength(2));
    await db.close();
  });

  test('collect honors maxSymbolsPerCollect ceiling', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(
      db,
      configJson: jsonEncode({'maxSymbolsPerCollect': 1}),
    );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'msft', symbol: 'MSFT'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _FinnhubClient(
      (_) => http.Response(_quotePayload(current: 99), 200),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    expect(await db.select(db.stockQuotes).get(), hasLength(1));
    await db.close();
  });

  test('collect skips Finnhub unknown-symbol sentinel (c=0,t=0)', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'good', symbol: 'GOOD'),
        );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'bad', symbol: 'BAD'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _FinnhubClient((uri) {
      final s = uri.queryParameters['symbol'];
      if (s == 'BAD') {
        return http.Response(_quotePayload(current: 0, t: 0), 200);
      }
      return http.Response(_quotePayload(current: 10), 200);
    });
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    final rows = await db.select(db.stockQuotes).get();
    expect(rows, hasLength(1));
    expect(rows.single.symbolId, 'good');
    await db.close();
  });

  test('collect skips non-200 responses', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _FinnhubClient(
      (_) => http.Response('rate limited', 429),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    expect(await db.select(db.stockQuotes).get(), isEmpty);
    await db.close();
  });

  test('collect tolerates malformed quote bodies', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _FinnhubClient(
      (_) => http.Response('not-json', 200),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(await db.select(db.stockQuotes).get(), isEmpty);
    await db.close();
  });

  test('collect swallows ClientException safely', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _ThrowingFinnhubClient(
      http.ClientException(
        'boom',
        Uri.parse('https://finnhub.io/api/v1/quote'),
      ),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    expect(await db.select(db.stockQuotes).get(), isEmpty);
    await db.close();
  });

  test('collect swallows SocketException safely', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _ThrowingFinnhubClient(
      const SocketException('no network'),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    expect(await db.select(db.stockQuotes).get(), isEmpty);
    await db.close();
  });

  test('collect swallows unexpected errors safely', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _ThrowingFinnhubClient(StateError('unexpected'));
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    expect(await db.select(db.stockQuotes).get(), isEmpty);
    await db.close();
  });

  test('collect swallows per-symbol upsert failures and continues', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'first', symbol: 'FIRST'),
        );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'second', symbol: 'SECOND'),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _FinnhubClient((uri) {
      final s = uri.queryParameters['symbol'];
      if (s == 'FIRST') {
        // Drop the symbol mid-flight so the FK-bound upsert fails for FIRST
        // but the loop must keep going and finish SECOND successfully.
        db.customStatement('DELETE FROM interests_stock_symbols WHERE id = ?', ['first']);
      }
      return http.Response(_quotePayload(current: 50), 200);
    });
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    final rows = await db.select(db.stockQuotes).get();
    expect(rows, hasLength(1));
    expect(rows.single.symbolId, 'second');
    await db.close();
  });

  test('collect persists symbol rows for default symbols on first run', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProviderRow(db);
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'finnhub-key');
    final client = _FinnhubClient(
      (_) => http.Response(_quotePayload(current: 50), 200),
    );
    final provider = StockQuoteDataProvider(httpClient: client);

    await provider.collect(ctx);

    final symbols = await db.select(db.interestsStockSymbols).get();
    expect(symbols, isNotEmpty);
    for (final s in symbols) {
      expect(s.enabled, isTrue);
    }
    await db.close();
  });
}
