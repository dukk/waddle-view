import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/display/display_weather_temperature_unit_kv.dart';
import 'package:waddle_shared/display/ticker_tape_config.dart';

import '../clock.dart';
import '../debug/app_debug_log.dart';
import '../display/screens/clock/clock_date_format.dart';
import '../extensions/ticker_source_registry.dart';
import 'curator_read_port.dart';
import 'ticker_item.dart';
import 'ticker_news_candidate.dart';

/// Bound at startup from [registerBuiltinTickerSources].
TickerSourceRegistry? globalTickerSourceRegistry;

/// Pure mapping from dashboard KV + clock to ordered marquee items.
List<TickerItem> buildTickerItemsFromKv({
  required Map<String, String> kv,
  required DateTime nowLocal,
}) {
  final out = <TickerItem>[];
  final seenBodies = <String>{};

  void addIfNew(TickerItem item) {
    final redacted = redactTickerBody(item.body);
    if (redacted.isEmpty) {
      return;
    }
    if (seenBodies.contains(redacted)) {
      return;
    }
    seenBodies.add(redacted);
    final rss = redacted == '[redacted]' ? null : item.rss;
    out.add(
      TickerItem(
        kind: item.kind,
        body: redacted,
        sourceId: item.sourceId,
        rss: rss,
        articleId: item.articleId,
        timeDisplay: item.timeDisplay,
        stockDisplay: item.stockDisplay,
        weatherDisplay: item.weatherDisplay,
      ),
    );
  }

  addIfNew(buildTimeTickerItem(nowLocal: nowLocal, kv: kv));

  return out;
}

String redactTickerBody(String body) {
  final lower = body.toLowerCase();
  if (lower.contains('refresh_token') ||
      lower.contains('password') ||
      lower.contains('bearer ')) {
    return '[redacted]';
  }
  return body;
}

/// Plain-text marquee body for RSS (dedup, REST, width estimate).
String composeTickerNewsBody({
  required bool prefix,
  required String feedName,
  required String title,
  required String summary,
}) {
  final sum = summary.trim();
  if (!prefix) {
    if (sum.isEmpty) {
      return '$title:';
    }
    return '$title: $sum';
  }
  if (sum.isEmpty) {
    return '$feedName $title:';
  }
  return '$feedName $title: $sum';
}

String formatTickerClock(DateTime now, {Map<String, String> kv = const {}}) =>
    formatTickerTimePreset(
      now,
      effectiveTickerTimeFormatPreset(
        kv: kv,
        tape: const TickerTapeTimeConfig(),
      ),
    );

/// Formats [Clock.now] for tests that do not need full curation.
String formatTickerTime(Clock clock, {Map<String, String> kv = const {}}) =>
    formatTickerClock(clock.now().toLocal(), kv: kv);

String _timeTickerStableBody({
  required String timeFormatPreset,
  String? timeZone,
  String? labelPrefix,
}) {
  final parts = <String>[
    'time',
    timeFormatPreset,
    if (timeZone != null && timeZone.isNotEmpty) timeZone,
    if (labelPrefix != null && labelPrefix.isNotEmpty) labelPrefix,
  ];
  return parts.join('|');
}

TickerItem buildTimeTickerItem({
  required DateTime nowLocal,
  TickerTapeForCuration? def,
  String? sourceId,
  Map<String, String> kv = const {},
}) {
  final cfg = def == null
      ? const TickerTapeTimeConfig()
      : parseTickerTapeTimeConfig(def.configJson);
  final preset = effectiveTickerTimeFormatPreset(kv: kv, tape: cfg);
  final prefix = cfg.labelPrefix?.trim() ?? '';
  final stable = _timeTickerStableBody(
    timeFormatPreset: preset,
    timeZone: cfg.timeZone,
    labelPrefix: prefix.isEmpty ? null : prefix,
  );
  final body = prefix.isEmpty ? stable : '$prefix|$stable';
  return TickerItem(
    kind: 'time',
    body: body,
    sourceId: sourceId ?? (def == null ? 'clock' : tapeSourceId(def)),
    timeDisplay: TickerTimeDisplay(
      timeFormatPreset: preset,
      timeZone: cfg.timeZone,
      labelPrefix: prefix.isEmpty ? null : prefix,
    ),
  );
}

String effectiveWeatherTemperatureUnitForTape({
  required String displayUnit,
  TickerTapeWeatherConfig? tape,
}) {
  final override = tape?.temperatureUnit?.trim();
  if (override == 'c' || override == 'f') {
    return override!;
  }
  return displayUnit;
}

CurrentWeatherTickerData? weatherDataForTape(
  Map<String, CurrentWeatherTickerData> byLocationId,
  TickerTapeForCuration def,
) {
  final tapeCfg = parseTickerTapeWeatherConfig(def.configJson);
  final locId = tapeCfg.locationId;
  if (locId != null && locId.isNotEmpty) {
    return byLocationId[locId];
  }
  if (byLocationId.isEmpty) {
    return null;
  }
  return byLocationId.values.first;
}

List<TickerNewsCandidate> filterNewsCandidatesByCategory(
  List<TickerNewsCandidate> candidates,
  String? categoryId,
) {
  final id = categoryId?.trim();
  if (id == null || id.isEmpty) {
    return candidates;
  }
  return [
    for (final c in candidates)
      if (c.categoryId == id) c,
  ];
}

const _defaultNewsScrollBudgetSeconds = 300;
const _defaultNewsPixelsPerSecond = 80;
const _defaultNewsCharWidthPx = 12.0;
const _defaultNewsSeparatorPaddingPx = 30.0;

/// Curator KV tuning for RSS marquee slice (see plan).
@immutable
class CuratorTickerConfig {
  const CuratorTickerConfig({
    required this.newsScrollBudgetSeconds,
    required this.newsPixelsPerSecond,
    required this.newsCharWidthPx,
    required this.newsSeparatorPaddingPx,
    required this.newsPrefixCategory,
  });

  final int newsScrollBudgetSeconds;
  final int newsPixelsPerSecond;
  final double newsCharWidthPx;
  final double newsSeparatorPaddingPx;
  final bool newsPrefixCategory;

  double get newsScrollBudgetPx =>
      newsScrollBudgetSeconds * newsPixelsPerSecond.toDouble();

  static CuratorTickerConfig fromKv(Map<String, String> kv) {
    int parseInt(String key, int def) =>
        int.tryParse(kv[key]?.trim() ?? '') ?? def;
    double parseDouble(String key, double def) =>
        double.tryParse(kv[key]?.trim() ?? '') ?? def;
    bool parseBool(String key, bool def) {
      final v = kv[key]?.toLowerCase().trim();
      if (v == null || v.isEmpty) {
        return def;
      }
      return v == 'true' || v == '1' || v == 'yes';
    }

    return CuratorTickerConfig(
      newsScrollBudgetSeconds: parseInt(
        'curator.ticker.newsScrollBudgetSeconds',
        _defaultNewsScrollBudgetSeconds,
      ),
      newsPixelsPerSecond: parseInt(
        'curator.ticker.newsPixelsPerSecond',
        _defaultNewsPixelsPerSecond,
      ),
      newsCharWidthPx: parseDouble(
        'curator.ticker.newsCharWidthPx',
        _defaultNewsCharWidthPx,
      ),
      newsSeparatorPaddingPx: parseDouble(
        'curator.ticker.newsSeparatorPaddingPx',
        _defaultNewsSeparatorPaddingPx,
      ),
      newsPrefixCategory: parseBool('curator.ticker.newsPrefixCategory', true),
    );
  }
}

/// Round-robin across feeds, avoiding consecutive same [TickerNewsCandidate.feedId]
/// when possible; prefers newer [TickerNewsCandidate.publishedAt] at each step.
List<TickerNewsCandidate> interleaveNewsByFeed(
  List<TickerNewsCandidate> candidates,
) {
  if (candidates.isEmpty) {
    return const [];
  }
  final byFeed = <String, List<TickerNewsCandidate>>{};
  for (final c in candidates) {
    byFeed.putIfAbsent(c.feedId, () => []).add(c);
  }
  final feedIds = byFeed.keys.toList()..sort();
  var lastFeed = '';
  final out = <TickerNewsCandidate>[];
  while (true) {
    TickerNewsCandidate? best;
    String? bestFeed;
    void consider(String fid, {required bool allowSameAsLast}) {
      final q = byFeed[fid];
      if (q == null || q.isEmpty) {
        return;
      }
      if (!allowSameAsLast && fid == lastFeed) {
        return;
      }
      final head = q.first;
      if (best == null || head.publishedAtMs > best!.publishedAtMs) {
        best = head;
        bestFeed = fid;
      }
    }

    for (final fid in feedIds) {
      consider(fid, allowSameAsLast: false);
    }
    if (best == null) {
      for (final fid in feedIds) {
        consider(fid, allowSameAsLast: true);
      }
    }
    if (best == null || bestFeed == null) {
      break;
    }
    byFeed[bestFeed]!.removeAt(0);
    out.add(best!);
    lastFeed = bestFeed!;
  }
  return out;
}

/// Applies horizontal budget (scroll distance ≈ time × pixels/s) to news bodies.
/// When [rejectCtx] is non-null, every news title/summary/source string is
/// passed through [RejectFilterContext.censor] before width budgeting and
/// rendering. Block-action terms have already led to `suppressed = true` rows
/// upstream and are excluded by the curator before reaching this helper.
List<TickerItem> pickNewsTickerItemsByWidthBudget({
  required List<TickerNewsCandidate> interleaved,
  required CuratorTickerConfig config,
  RejectFilterContext? rejectCtx,
  bool? prefixFeedNameOverride,
}) {
  final prefixFeed = prefixFeedNameOverride ?? config.newsPrefixCategory;
  final out = <TickerItem>[];
  final budget = config.newsScrollBudgetPx;
  var used = 0.0;
  final sep = config.newsSeparatorPaddingPx;
  final ctx = rejectCtx ?? const RejectFilterContext.empty();
  for (final c in interleaved) {
    final title = ctx.censor(redactTickerBody(c.title.trim()));
    final summary = ctx.censor(redactTickerBody((c.summary ?? '').trim()));
    final source = ctx.censor(redactTickerBody(c.feedName.trim()));
    if (title.isEmpty && summary.isEmpty) {
      continue;
    }
    final body = composeTickerNewsBody(
      prefix: prefixFeed,
      feedName: source,
      title: title,
      summary: summary,
    );
    if (body.isEmpty) {
      continue;
    }
    final w = body.length * config.newsCharWidthPx + sep;
    if (used + w > budget && out.isNotEmpty) {
      break;
    }
    final item = TickerItem(
      kind: 'news',
      body: body,
      sourceId: c.feedId,
      articleId: c.articleId,
      rss: TickerRssSegments(
        sourceTitle: source,
        sourceIconName: c.categoryIconName,
        articleTitle: title,
        summary: summary,
        showSource: prefixFeed,
      ),
    );
    if (used + w > budget && out.isEmpty) {
      out.add(item);
      break;
    }
    used += w;
    out.add(item);
  }
  return out;
}

/// Reads [TickerTapeForCuration.configJson] `text` for static_text tapes.
String? parseTickerTapeStaticText(String rawConfigJson) {
  final t = rawConfigJson.trim();
  if (t.isEmpty || t == '{}') {
    return null;
  }
  try {
    final decoded = jsonDecode(t);
    if (decoded is! Map) {
      return null;
    }
    final m = decoded.map((k, Object? v) => MapEntry(k.toString(), v));
    final text = m['text'];
    if (text is String && text.trim().isNotEmpty) {
      return text.trim();
    }
    return null;
  } on Object {
    return null;
  }
}

/// Reads plugin tape [fallbackText] when the plugin yields no lines.
String? parseTickerTapePluginFallbackText(String rawConfigJson) {
  final t = rawConfigJson.trim();
  if (t.isEmpty || t == '{}') {
    return null;
  }
  try {
    final decoded = jsonDecode(t);
    if (decoded is! Map) {
      return null;
    }
    final m = decoded.map((k, Object? v) => MapEntry(k.toString(), v));
    final f = m['fallbackText'];
    if (f is String && f.trim().isNotEmpty) {
      return f.trim();
    }
    return null;
  } on Object {
    return null;
  }
}

String tapeSourceId(TickerTapeForCuration def) => 'ticker_tape:${def.id}';

String stockMarqueeBody(StockTickerRowForMarquee row) {
  final label = row.symbol.trim().isEmpty ? row.symbolId : row.symbol.trim();
  final price = row.currentPrice;
  final pct = row.percentChange;
  final priceText = price != null ? '\$${price.toStringAsFixed(2)}' : '\u2014';
  final pctText = pct != null
      ? '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'
      : '\u2014';
  final dn = row.displayName.trim();
  if (dn.isNotEmpty) {
    return '$label ($dn) $priceText $pctText';
  }
  return '$label $priceText $pctText';
}

List<TickerItem> _tickerItemsTimeOnly(
  DateTime nowLocal, {
  Map<String, String> kv = const {},
}) {
  final item = buildTimeTickerItem(nowLocal: nowLocal, kv: kv);
  final redacted = redactTickerBody(item.body);
  if (redacted.isEmpty) {
    return const [];
  }
  return [
    TickerItem(
      kind: item.kind,
      body: redacted,
      sourceId: item.sourceId,
      rss: item.rss,
      articleId: item.articleId,
      timeDisplay: item.timeDisplay,
    ),
  ];
}

void _addTickerIfNew(
  List<TickerItem> out,
  Set<String> seenBodies,
  TickerItem item, {
  RejectFilterContext? rejectCtx,
}) {
  final redacted = redactTickerBody(item.body);
  if (redacted.isEmpty) {
    return;
  }
  final body =
      (rejectCtx == null || rejectCtx.isEmpty || redacted == '[redacted]')
      ? redacted
      : rejectCtx.censor(redacted);
  if (seenBodies.contains(body)) {
    return;
  }
  seenBodies.add(body);
  final rss = redacted == '[redacted]' ? null : item.rss;
  out.add(
    TickerItem(
      kind: item.kind,
      body: body,
      sourceId: item.sourceId,
      rss: rss,
      articleId: item.articleId,
      timeDisplay: item.timeDisplay,
      stockDisplay: item.stockDisplay,
      weatherDisplay: item.weatherDisplay,
    ),
  );
}

void _appendWeatherGovAlertTickerItems(
  List<TickerItem> out,
  Set<String> seenBodies,
  List<WeatherGovAlertTickerItem> alerts, {
  RejectFilterContext? rejectCtx,
}) {
  for (final a in alerts) {
    _addTickerIfNew(
      out,
      seenBodies,
      TickerItem(kind: 'weather', body: a.body, sourceId: a.sourceId),
      rejectCtx: rejectCtx,
    );
  }
}

/// KV + clock + optional RSS: legacy ordering when [definitions] is empty.
List<TickerItem> _buildTickerItemsForMarqueeLegacy({
  required Map<String, String> kv,
  required DateTime nowLocal,
  required List<TickerItem> rssItems,
  required Map<String, CurrentWeatherTickerData> weatherByLocationId,
  required String displayTemperatureUnit,
  List<WeatherGovAlertTickerItem> weatherGovAlerts = const [],
  RejectFilterContext? rejectCtx,
}) {
  final out = <TickerItem>[];
  final seenBodies = <String>{};

  _addTickerIfNew(
    out,
    seenBodies,
    buildTimeTickerItem(nowLocal: nowLocal, kv: kv),
  );

  final currentWeather = weatherByLocationId.isEmpty
      ? null
      : weatherByLocationId.values.first;
  final liveWeatherBody =
      currentWeather
          ?.toTickerBody(temperatureUnit: displayTemperatureUnit)
          .trim() ??
      '';
  if (liveWeatherBody.isNotEmpty) {
    _addTickerIfNew(
      out,
      seenBodies,
      TickerItem(
        kind: 'weather',
        body: liveWeatherBody,
        sourceId: 'weather.live',
        weatherDisplay: currentWeather?.iconCode == null
            ? null
            : TickerWeatherDisplay(iconCode: currentWeather!.iconCode),
      ),
      rejectCtx: rejectCtx,
    );
  }
  _appendWeatherGovAlertTickerItems(
    out,
    seenBodies,
    weatherGovAlerts,
    rejectCtx: rejectCtx,
  );

  if (rssItems.isNotEmpty) {
    for (final it in rssItems) {
      // News items already passed through censor in
      // [pickNewsTickerItemsByWidthBudget].
      _addTickerIfNew(out, seenBodies, it);
    }
  }

  return out;
}

List<TickerItem> _buildTickerItemsForMarqueeFromDefinitions({
  required Map<String, String> kv,
  required DateTime nowLocal,
  required List<TickerNewsCandidate> newsCandidates,
  required Map<String, CurrentWeatherTickerData> weatherByLocationId,
  required String displayTemperatureUnit,
  required List<TickerTapeForCuration> enabledDefinitions,
  required List<StockTickerRowForMarquee> stockRows,
  List<WeatherGovAlertTickerItem> weatherGovAlerts = const [],
  List<TickerItem> quoteTickerItems = const [],
  Map<String, Set<String>> quoteCategoryIdsByQuoteId = const {},
  RejectFilterContext? rejectCtx,
}) {
  final cfg = CuratorTickerConfig.fromKv(kv);

  List<TickerItem> expandTime(TickerTapeForCuration def) => [
    buildTimeTickerItem(nowLocal: nowLocal, def: def, kv: kv),
  ];

  List<TickerItem> expandWeather(TickerTapeForCuration def) {
    final tapeCfg = parseTickerTapeWeatherConfig(def.configJson);
    final unit = effectiveWeatherTemperatureUnitForTape(
      displayUnit: displayTemperatureUnit,
      tape: tapeCfg,
    );
    final data = weatherDataForTape(weatherByLocationId, def);
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
    for (final a in weatherGovAlerts) {
      out.add(TickerItem(kind: 'weather', body: a.body, sourceId: a.sourceId));
    }
    return out;
  }

  List<TickerItem> expandNews(TickerTapeForCuration def) {
    final tapeCfg = parseTickerTapeNewsConfig(def.configJson);
    final filtered = filterNewsCandidatesByCategory(
      newsCandidates,
      tapeCfg.categoryId,
    );
    if (filtered.isEmpty) {
      return const [];
    }
    return pickNewsTickerItemsByWidthBudget(
      interleaved: interleaveNewsByFeed(filtered),
      config: cfg,
      rejectCtx: rejectCtx,
      prefixFeedNameOverride: tapeCfg.prefixFeedName,
    );
  }

  List<TickerItem> expandStocks(TickerTapeForCuration def) {
    final symbolIds = parseTickerTapeStockSymbolIds(def.configJson);
    final rows = symbolIds == null
        ? stockRows
        : [
            for (final row in stockRows)
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
  }

  List<TickerItem> expandStaticText(TickerTapeForCuration def) {
    final raw = parseTickerTapeStaticText(def.configJson);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return [
      TickerItem(kind: 'static_text', body: raw, sourceId: tapeSourceId(def)),
    ];
  }

  List<TickerItem> itemsForDef(TickerTapeForCuration def) {
    final expandCtx = TickerExpandContext(
      kv: kv,
      nowLocal: nowLocal,
      newsCandidates: newsCandidates,
      curatorTickerConfig: cfg,
      quoteTickerItems: quoteTickerItems,
      quoteCategoryIdsByQuoteId: quoteCategoryIdsByQuoteId,
      weatherByLocationId: weatherByLocationId,
      displayTemperatureUnit: displayTemperatureUnit,
      stockRows: stockRows,
      weatherGovAlerts: weatherGovAlerts,
      rejectCtx: rejectCtx,
    );
    final reg = globalTickerSourceRegistry;
    if (reg != null) {
      final custom = reg.lookup(def.tickerType);
      if (custom != null) {
        return custom(def, expandCtx);
      }
    }
    switch (def.tickerType.trim().toLowerCase()) {
      case 'time':
        return expandTime(def);
      case 'weather':
        return expandWeather(def);
      case 'news':
        return expandNews(def);
      case 'stocks':
        return expandStocks(def);
      case 'static_text':
        return expandStaticText(def);
      default:
        return const [];
    }
  }

  final out = <TickerItem>[];
  final seenBodies = <String>{};

  for (final def in enabledDefinitions) {
    final w = def.frequencyWeight < 0 ? 0 : def.frequencyWeight;
    final chunk = itemsForDef(def);
    if (chunk.isEmpty || w == 0) {
      continue;
    }
    final isNews = def.tickerType.trim().toLowerCase() == 'news';
    for (var i = 0; i < w; i++) {
      for (final item in chunk) {
        // News items already passed through reject censor inside
        // [pickNewsTickerItemsByWidthBudget]; everything else (static_text,
        // weather, stocks) is censored here.
        _addTickerIfNew(
          out,
          seenBodies,
          item,
          rejectCtx: isNews ? null : rejectCtx,
        );
      }
    }
  }

  if (out.isEmpty) {
    AppDebugLog.curator(
      'ticker build definitions: expanded to 0 items (empty defs, dedupe, or '
      'zero-weight); using time-only fallback',
    );
    return _tickerItemsTimeOnly(nowLocal, kv: kv);
  }
  return out;
}

/// KV + clock + optional RSS: ordered marquee items for [TickerCuratedRepository].
///
/// When [definitions] is empty, uses legacy ordering (time, live weather, RSS
/// news only). Otherwise uses
/// enabled rows from [TickerTapes] with weighted repeats per
/// [TickerTapeForCuration.frequencyWeight].
///
/// When [rejectCtx] is non-null and non-empty, every body string from
/// user-/feed-supplied sources (news titles/summaries/feed labels, weather,
/// static_text, stock display name) is passed through
/// [RejectFilterContext.censor] before assembly. Block-action terms are
/// already applied at ingest time via `suppressed = true`.
List<TickerItem> buildTickerItemsForMarquee({
  required Map<String, String> kv,
  required DateTime nowLocal,
  required List<TickerNewsCandidate> newsCandidates,
  Map<String, CurrentWeatherTickerData> weatherByLocationId = const {},
  String? displayTemperatureUnit,
  List<TickerTapeForCuration> definitions = const [],
  List<StockTickerRowForMarquee> stockRows = const [],
  List<WeatherGovAlertTickerItem> weatherGovAlerts = const [],
  List<TickerItem> quoteTickerItems = const [],
  Map<String, Set<String>> quoteCategoryIdsByQuoteId = const {},
  RejectFilterContext? rejectCtx,
}) {
  final tempUnit =
      displayTemperatureUnit ?? displayWeatherTemperatureUnitFromKv(kv);
  AppDebugLog.curator(
    'ticker build: inputs definitions=${definitions.length} '
    'newsCandidates=${newsCandidates.length} stocks=${stockRows.length} '
    'govAlerts=${weatherGovAlerts.length} liveWeather=${weatherByLocationId.length} '
    'rejectFilter=${rejectCtx == null || rejectCtx.isEmpty ? "off" : "on"}',
  );
  final cfg = CuratorTickerConfig.fromKv(kv);
  final rssItems = pickNewsTickerItemsByWidthBudget(
    interleaved: interleaveNewsByFeed(newsCandidates),
    config: cfg,
    rejectCtx: rejectCtx,
  );

  if (definitions.isEmpty) {
    final legacy = _buildTickerItemsForMarqueeLegacy(
      kv: kv,
      nowLocal: nowLocal,
      rssItems: rssItems,
      weatherByLocationId: weatherByLocationId,
      displayTemperatureUnit: tempUnit,
      weatherGovAlerts: weatherGovAlerts,
      rejectCtx: rejectCtx,
    );
    AppDebugLog.curator(
      'ticker build: path=legacy (no ticker_tapes rows) items=${legacy.length} '
      'rssMarqueeSlots=${rssItems.length}',
    );
    return legacy;
  }

  final enabled = definitions.toList()
    ..sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      if (c != 0) {
        return c;
      }
      return a.id.compareTo(b.id);
    });

  if (enabled.isEmpty) {
    AppDebugLog.curator(
      'ticker build: path=time_only (all ticker_tapes disabled)',
    );
    return _tickerItemsTimeOnly(nowLocal, kv: kv);
  }

  final fromDefs = _buildTickerItemsForMarqueeFromDefinitions(
    kv: kv,
    nowLocal: nowLocal,
    newsCandidates: newsCandidates,
    weatherByLocationId: weatherByLocationId,
    displayTemperatureUnit: tempUnit,
    enabledDefinitions: enabled,
    stockRows: stockRows,
    weatherGovAlerts: weatherGovAlerts,
    quoteTickerItems: quoteTickerItems,
    quoteCategoryIdsByQuoteId: quoteCategoryIdsByQuoteId,
    rejectCtx: rejectCtx,
  );
  AppDebugLog.curator(
    'ticker build: path=definitions enabledRows=${enabled.length} items=${fromDefs.length}',
  );
  return fromDefs;
}
