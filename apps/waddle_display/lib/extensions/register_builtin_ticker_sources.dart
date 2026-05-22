import 'package:waddle_shared/display/ticker_tape_config.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../curator/ticker_curation.dart';
import '../curator/ticker_item.dart';
import '../plugins/plugin_ticker_bridge.dart';
import 'ticker_source_registry.dart';

/// Registers built-in and plugin ticker expanders on [registry].
void registerBuiltinTickerSources(TickerSourceRegistry registry) {
  registry.register('time', (def, ctx) {
    return [buildTimeTickerItem(nowLocal: ctx.nowLocal, def: def, kv: ctx.kv)];
  });

  registry.register('weather', (def, ctx) {
    final tapeCfg = parseTickerTapeWeatherConfig(def.configJson);
    final unit = effectiveWeatherTemperatureUnitForTape(
      displayUnit: ctx.displayTemperatureUnit,
      tape: tapeCfg,
    );
    final data = weatherDataForTape(ctx.weatherByLocationId, def);
    final out = <TickerItem>[];
    final live = data?.toTickerBody(temperatureUnit: unit).trim() ?? '';
    if (live.isNotEmpty) {
      out.add(
        TickerItem(
          kind: 'weather',
          body: live,
          sourceId: tapeSourceId(def),
          weatherDisplay: data?.iconCode == null
              ? null
              : TickerWeatherDisplay(iconCode: data!.iconCode),
        ),
      );
    }
    for (final a in ctx.weatherGovAlerts) {
      out.add(TickerItem(kind: 'weather', body: a.body, sourceId: a.sourceId));
    }
    return out;
  });

  registry.register('news', (def, ctx) {
    final tapeCfg = parseTickerTapeNewsConfig(def.configJson);
    final filtered = filterNewsCandidatesByCategory(
      ctx.newsCandidates,
      tapeCfg.categoryId,
    );
    if (filtered.isEmpty) {
      return const [];
    }
    return pickNewsTickerItemsByWidthBudget(
      interleaved: interleaveNewsByFeed(filtered),
      config: ctx.curatorTickerConfig,
      rejectCtx: ctx.rejectCtx,
      prefixFeedNameOverride: tapeCfg.prefixFeedName,
    );
  });

  registry.register('quote', (def, ctx) {
    final categoryId = parseTickerTapeCategoryId(def.configJson);
    if (categoryId == null || categoryId.isEmpty) {
      return ctx.quoteTickerItems;
    }
    final byQuote = ctx.quoteCategoryIdsByQuoteId;
    return [
      for (final item in ctx.quoteTickerItems)
        if (byQuote[item.sourceId ?? '']?.contains(categoryId) ?? false) item,
    ];
  });

  registry.register('stocks', (def, ctx) {
    final symbolIds = parseTickerTapeStockSymbolIds(def.configJson);
    final rows = symbolIds == null
        ? ctx.stockRows
        : [
            for (final row in ctx.stockRows)
              if (symbolIds.contains(row.symbolId)) row,
          ];
    if (rows.isEmpty) {
      return const [];
    }
    return [
      for (final row in rows)
        TickerItem(
          kind: 'stocks',
          body: stockMarqueeBody(row),
          sourceId: row.symbolId,
          stockDisplay: TickerStockDisplay(
            symbol: row.symbol.trim().isEmpty
                ? row.symbolId
                : row.symbol.trim(),
            displayName: row.displayName,
            currentPrice: row.currentPrice,
            percentChange: row.percentChange,
          ),
        ),
    ];
  });

  registry.register('static_text', (def, ctx) {
    final raw = parseTickerTapeStaticText(def.configJson);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return [
      TickerItem(kind: 'static_text', body: raw, sourceId: tapeSourceId(def)),
    ];
  });

  registry.register(kTickerTypePlugin, (def, ctx) {
    return PluginTickerBridge.expand(def);
  });
}
