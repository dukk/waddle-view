import 'package:waddle_shared/net/http_debug_uri.dart';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:http/http.dart' as http;

import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'stock_quote_provider_extra_config.dart';

const String kStockProviderId = 'stock_finnhub';
const String kDefaultFinnhubBaseUrl = 'https://finnhub.io';

class _ResolvedSymbol {
  const _ResolvedSymbol({required this.id, required this.symbol});

  final String id;
  final String symbol;
}

/// Collects current stock quotes from [Finnhub /api/v1/quote](https://finnhub.io/docs/api/quote)
/// for every enabled row in `interests_stock_symbols` (or the seeded `defaultSymbols`
/// when none are present), and upserts one row per symbol into `stock_quotes`.
class StockQuoteDataProvider implements IDataProvider {
  StockQuoteDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kStockProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final settings = await enabledIntegrationsForType(ctx.db, id);
    if (settings.isEmpty) {
      ctx.diagnostics.provider('stocks: skip (disabled)');
      return;
    }
    final setting = settings.first;
    final config = await ctx.resolveConfig(setting.id);
    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      ctx.diagnostics.provider('stocks: skip (no API token)');
      return;
    }
    final extra = StockQuoteProviderExtraConfig.parse(config.configJson);
    final baseUrl = (config.baseUrl != null && config.baseUrl!.trim().isNotEmpty)
        ? config.baseUrl!.trim()
        : kDefaultFinnhubBaseUrl;

    final symbols = await _resolveSymbols(ctx.db, extra);
    final now = _nowMs();
    ctx.diagnostics.provider(
      'stocks: collect symbols=${symbols.length} base=${safeHttpUriForLog(Uri.parse(baseUrl))}',
    );
    for (final symbol in symbols) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/quote').replace(
          queryParameters: {
            'symbol': symbol.symbol,
            'token': token,
          },
        );
        ctx.diagnostics.provider(
          'stocks: GET quote symbol=${symbol.symbol} ${safeHttpUriForLog(uri)}',
        );
        final res = await _safeGet(uri, symbol: symbol.symbol, diagnostics: ctx.diagnostics);
        if (res == null) {
          continue;
        }
        if (res.statusCode != 200) {
          ctx.diagnostics.provider(
            'stocks: quote status=${res.statusCode} symbol=${symbol.symbol}',
          );
          continue;
        }
        final parsed = _normalizeQuotePayload(res.body);
        if (parsed == null) {
          ctx.diagnostics.provider(
            'stocks: quote empty/invalid payload symbol=${symbol.symbol}',
          );
          continue;
        }
        ctx.diagnostics.provider(
          'stocks: upsert quote symbol=${symbol.symbol} price=${parsed.currentPrice}',
        );
        await ctx.db.into(ctx.db.stockQuotes).insertOnConflictUpdate(
              StockQuotesCompanion.insert(
                symbolId: symbol.id,
                currentPrice: Value(parsed.currentPrice),
                changeAmount: Value(parsed.changeAmount),
                percentChange: Value(parsed.percentChange),
                highOfDay: Value(parsed.highOfDay),
                lowOfDay: Value(parsed.lowOfDay),
                openPrice: Value(parsed.openPrice),
                previousClose: Value(parsed.previousClose),
                quotedAtMs: Value(parsed.quotedAtMs),
                observedAtMs: DateTime.fromMillisecondsSinceEpoch(now),
              ),
            );
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail(
          'stocks: collect symbol=${symbol.symbol}',
          e,
          st,
        );
      }
    }
  }

  Future<List<_ResolvedSymbol>> _resolveSymbols(
    AppDatabase db,
    StockQuoteProviderExtraConfig extra,
  ) async {
    final rows = await (db.select(db.interestsStockSymbols)
          ..where((t) => t.enabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    if (rows.isNotEmpty) {
      return rows
          .take(extra.maxSymbolsPerCollect)
          .map((r) => _ResolvedSymbol(id: r.id, symbol: r.symbol))
          .toList();
    }
    final out = <_ResolvedSymbol>[];
    for (final entry in extra.defaultSymbols.take(extra.maxSymbolsPerCollect)) {
      final id = entry.symbol.toLowerCase();
      await db.into(db.interestsStockSymbols).insertOnConflictUpdate(
            InterestsStockSymbolsCompanion.insert(
              id: id,
              symbol: entry.symbol,
              displayName: Value(entry.displayName),
              enabled: const Value(true),
            ),
          );
      out.add(_ResolvedSymbol(id: id, symbol: entry.symbol));
    }
    return out;
  }

  _ParsedQuote? _normalizeQuotePayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final current = (decoded['c'] as num?)?.toDouble();
      final tSec = (decoded['t'] as num?)?.toInt() ?? 0;
      // Finnhub returns `{ c: 0, t: 0, ... }` for unknown / unsupported symbols.
      if ((current == null || current == 0) && tSec == 0) {
        return null;
      }
      return _ParsedQuote(
        currentPrice: current,
        changeAmount: (decoded['d'] as num?)?.toDouble(),
        percentChange: (decoded['dp'] as num?)?.toDouble(),
        highOfDay: (decoded['h'] as num?)?.toDouble(),
        lowOfDay: (decoded['l'] as num?)?.toDouble(),
        openPrice: (decoded['o'] as num?)?.toDouble(),
        previousClose: (decoded['pc'] as num?)?.toDouble(),
        quotedAtMs: tSec > 0
            ? DateTime.fromMillisecondsSinceEpoch(tSec * 1000)
            : null,
      );
    } on Object {
      return null;
    }
  }

  Future<http.Response?> _safeGet(
    Uri uri, {
    required String symbol,
    required CollectDiagnostics diagnostics,
  }) async {
    try {
      return await _http.get(uri);
    } on http.ClientException catch (e, st) {
      diagnostics.providerFail(
        'stocks: request failed symbol=$symbol',
        e,
        st,
      );
      return null;
    } on SocketException catch (e, st) {
      diagnostics.providerFail(
        'stocks: socket failed symbol=$symbol',
        e,
        st,
      );
      return null;
    } on Object catch (e, st) {
      diagnostics.providerFail(
        'stocks: unexpected error symbol=$symbol',
        e,
        st,
      );
      return null;
    }
  }
}

class _ParsedQuote {
  const _ParsedQuote({
    required this.currentPrice,
    required this.changeAmount,
    required this.percentChange,
    required this.highOfDay,
    required this.lowOfDay,
    required this.openPrice,
    required this.previousClose,
    required this.quotedAtMs,
  });

  final double? currentPrice;
  final double? changeAmount;
  final double? percentChange;
  final double? highOfDay;
  final double? lowOfDay;
  final double? openPrice;
  final double? previousClose;
  final DateTime? quotedAtMs;
}
