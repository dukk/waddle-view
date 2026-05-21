import 'package:waddle_shared/persistence/tables.dart';

import '../curator/ticker_curation.dart';
import '../curator/ticker_item.dart';
import '../plugins/plugin_ticker_bridge.dart';
import 'ticker_source_registry.dart';

/// Registers built-in and plugin ticker expanders on [registry].
void registerBuiltinTickerSources(TickerSourceRegistry registry) {
  registry.register('time', (def, ctx) {
    return [
      TickerItem(
        kind: 'time',
        body: formatTickerClock(ctx.nowLocal),
        sourceId: 'clock',
      ),
    ];
  });

  registry.register('weather', (def, ctx) {
    final live = ctx.currentWeather?.toTickerBody().trim() ?? '';
    final out = <TickerItem>[];
    if (live.isNotEmpty) {
      out.add(
        TickerItem(
          kind: 'weather',
          body: live,
          sourceId: tapeSourceId(def),
        ),
      );
    }
    for (final a in ctx.weatherGovAlerts) {
      out.add(TickerItem(kind: 'weather', body: a.body, sourceId: a.sourceId));
    }
    return out;
  });

  registry.register('news', (def, ctx) {
    if (ctx.rssItems.isNotEmpty) {
      return ctx.rssItems;
    }
    return const [];
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
    if (ctx.stockRows.isEmpty) {
      return const [];
    }
    return [
      for (final row in ctx.stockRows)
        TickerItem(
          kind: 'stocks',
          body: stockMarqueeBody(row),
          sourceId: row.symbolId,
        ),
    ];
  });

  registry.register('static_text', (def, ctx) {
    final raw = parseTickerTapeStaticText(def.configJson);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return [
      TickerItem(
        kind: 'static_text',
        body: raw,
        sourceId: tapeSourceId(def),
      ),
    ];
  });

  registry.register(kTickerTypePlugin, (def, ctx) {
    return PluginTickerBridge.expand(def);
  });
}
