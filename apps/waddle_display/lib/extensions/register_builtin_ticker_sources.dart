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
    final fallback = parseTickerTapeFallbackText(def.configJson) ?? '';
    final primary = live.isNotEmpty ? live : fallback;
    final out = <TickerItem>[];
    if (primary.isNotEmpty) {
      out.add(
        TickerItem(
          kind: 'weather',
          body: primary,
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
    final rawNews = parseTickerTapeFallbackText(def.configJson);
    if (rawNews == null || rawNews.isEmpty) {
      return const [];
    }
    return [
      TickerItem(kind: 'news', body: rawNews, sourceId: tapeSourceId(def)),
    ];
  });

  registry.register('quote', (def, ctx) {
    final rawQuote = parseTickerTapeFallbackText(def.configJson);
    if (rawQuote == null || rawQuote.isEmpty) {
      return const [];
    }
    return [
      TickerItem(kind: 'quote', body: rawQuote, sourceId: tapeSourceId(def)),
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

  registry.register('custom', (def, ctx) {
    final specific = def.configKey?.trim();
    if (specific != null && specific.isNotEmpty) {
      final raw = ctx.kv[specific]?.trim() ?? '';
      if (raw.isEmpty) {
        return const [];
      }
      return [TickerItem(kind: 'custom', body: raw, sourceId: specific)];
    }
    final extraKeys =
        ctx.kv.keys.where((k) => k.startsWith('ticker.marquee.')).toList()
          ..sort();
    final out = <TickerItem>[];
    for (final k in extraKeys) {
      final raw = ctx.kv[k]!.trim();
      if (raw.isEmpty) {
        continue;
      }
      out.add(TickerItem(kind: 'custom', body: raw, sourceId: k));
    }
    return out;
  });

  registry.register(kTickerTypePlugin, (def, ctx) {
    return PluginTickerBridge.expand(def);
  });
}
