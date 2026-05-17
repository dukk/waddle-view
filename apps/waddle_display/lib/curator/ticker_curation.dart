import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';

import '../clock.dart';
import '../debug/app_debug_log.dart';
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
      ),
    );
  }

  addIfNew(
    TickerItem(
      kind: 'time',
      body: formatTickerClock(nowLocal),
      sourceId: 'clock',
    ),
  );

  final extraKeys = kv.keys.where((k) => k.startsWith('ticker.marquee.')).toList()
    ..sort();
  for (final k in extraKeys) {
    final raw = kv[k]!.trim();
    if (raw.isEmpty) {
      continue;
    }
    addIfNew(TickerItem(kind: 'custom', body: raw, sourceId: k));
  }

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

String formatTickerClock(DateTime now) {
  final h = now.hour.toString().padLeft(2, '0');
  final m = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Formats [Clock.now] for tests that do not need full curation.
String formatTickerTime(Clock clock) =>
    formatTickerClock(clock.now().toLocal());

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
      newsPrefixCategory: parseBool(
        'curator.ticker.newsPrefixCategory',
        true,
      ),
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
      if (best == null ||
          head.publishedAtMs > best!.publishedAtMs) {
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
}) {
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
      prefix: config.newsPrefixCategory,
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
        showSource: config.newsPrefixCategory,
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

/// Reads [TickerTapeForCuration.configJson] for a plain-text fallback line.
String? parseTickerTapeFallbackText(String rawConfigJson) {
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
    for (final legacyKey in const [
      'ticker.marquee.weather',
      'ticker.marquee.news',
      'ticker.marquee.quote',
    ]) {
      final v = m[legacyKey];
      if (v is String && v.trim().isNotEmpty) {
        return v.trim();
      }
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

List<TickerItem> _tickerItemsTimeOnly(DateTime nowLocal) {
  final item = TickerItem(
    kind: 'time',
    body: formatTickerClock(nowLocal),
    sourceId: 'clock',
  );
  final redacted = redactTickerBody(item.body);
  if (redacted.isEmpty) {
    return const [];
  }
  return [
    TickerItem(
      kind: item.kind,
      body: redacted,
      sourceId: item.sourceId,
      rss: redacted == '[redacted]' ? null : item.rss,
      articleId: item.articleId,
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
  final body = (rejectCtx == null || rejectCtx.isEmpty || redacted == '[redacted]')
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
  CurrentWeatherTickerData? currentWeather,
  List<WeatherGovAlertTickerItem> weatherGovAlerts = const [],
  RejectFilterContext? rejectCtx,
}) {
  final out = <TickerItem>[];
  final seenBodies = <String>{};

  _addTickerIfNew(
    out,
    seenBodies,
    TickerItem(
      kind: 'time',
      body: formatTickerClock(nowLocal),
      sourceId: 'clock',
    ),
  );

  final liveWeatherBody = currentWeather?.toTickerBody().trim() ?? '';
  if (liveWeatherBody.isNotEmpty) {
    _addTickerIfNew(
      out,
      seenBodies,
      TickerItem(
        kind: 'weather',
        body: liveWeatherBody,
        sourceId: 'weather.live',
      ),
      rejectCtx: rejectCtx,
    );
  }
  _appendWeatherGovAlertTickerItems(out, seenBodies, weatherGovAlerts,
      rejectCtx: rejectCtx);

  if (rssItems.isNotEmpty) {
    for (final it in rssItems) {
      // News items already passed through censor in
      // [pickNewsTickerItemsByWidthBudget].
      _addTickerIfNew(out, seenBodies, it);
    }
  }

  final extraKeys =
      kv.keys.where((k) => k.startsWith('ticker.marquee.')).toList()..sort();
  for (final k in extraKeys) {
    final raw = kv[k]!.trim();
    if (raw.isEmpty) {
      continue;
    }
    _addTickerIfNew(
      out,
      seenBodies,
      TickerItem(kind: 'custom', body: raw, sourceId: k),
      rejectCtx: rejectCtx,
    );
  }

  return out;
}

List<TickerItem> _buildTickerItemsForMarqueeFromDefinitions({
  required Map<String, String> kv,
  required DateTime nowLocal,
  required List<TickerItem> rssItems,
  CurrentWeatherTickerData? currentWeather,
  required List<TickerTapeForCuration> enabledDefinitions,
  required List<StockTickerRowForMarquee> stockRows,
  List<WeatherGovAlertTickerItem> weatherGovAlerts = const [],
  RejectFilterContext? rejectCtx,
}) {
  List<TickerItem> expandTime() => [
    TickerItem(
      kind: 'time',
      body: formatTickerClock(nowLocal),
      sourceId: 'clock',
    ),
  ];

  List<TickerItem> expandWeather(TickerTapeForCuration def) {
    final live = currentWeather?.toTickerBody().trim() ?? '';
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
    for (final a in weatherGovAlerts) {
      out.add(
        TickerItem(kind: 'weather', body: a.body, sourceId: a.sourceId),
      );
    }
    return out;
  }

  List<TickerItem> expandNews(TickerTapeForCuration def) {
    if (rssItems.isNotEmpty) {
      return rssItems;
    }
    final rawNews = parseTickerTapeFallbackText(def.configJson);
    if (rawNews == null || rawNews.isEmpty) {
      return const [];
    }
    return [
      TickerItem(
        kind: 'news',
        body: rawNews,
        sourceId: tapeSourceId(def),
      ),
    ];
  }

  List<TickerItem> expandQuote(TickerTapeForCuration def) {
    final rawQuote = parseTickerTapeFallbackText(def.configJson);
    if (rawQuote == null || rawQuote.isEmpty) {
      return const [];
    }
    return [
      TickerItem(
        kind: 'quote',
        body: rawQuote,
        sourceId: tapeSourceId(def),
      ),
    ];
  }

  List<TickerItem> expandStocks() {
    if (stockRows.isEmpty) {
      return const [];
    }
    return [
      for (final row in stockRows)
        TickerItem(
          kind: 'stocks',
          body: stockMarqueeBody(row),
          sourceId: row.symbolId,
        ),
    ];
  }

  List<TickerItem> expandCustom(TickerTapeForCuration def) {
    final specific = def.configKey?.trim();
    if (specific != null && specific.isNotEmpty) {
      final raw = kv[specific]?.trim() ?? '';
      if (raw.isEmpty) {
        return const [];
      }
      return [
        TickerItem(kind: 'custom', body: raw, sourceId: specific),
      ];
    }
    final extraKeys = kv.keys.where((k) => k.startsWith('ticker.marquee.')).toList()
      ..sort();
    final out = <TickerItem>[];
    for (final k in extraKeys) {
      final raw = kv[k]!.trim();
      if (raw.isEmpty) {
        continue;
      }
      out.add(TickerItem(kind: 'custom', body: raw, sourceId: k));
    }
    return out;
  }

  List<TickerItem> itemsForDef(TickerTapeForCuration def) {
    final expandCtx = TickerExpandContext(
      kv: kv,
      nowLocal: nowLocal,
      rssItems: rssItems,
      currentWeather: currentWeather,
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
        return expandTime();
      case 'weather':
        return expandWeather(def);
      case 'news':
        return expandNews(def);
      case 'quote':
        return expandQuote(def);
      case 'stocks':
        return expandStocks();
      case 'custom':
        return expandCustom(def);
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
        // [pickNewsTickerItemsByWidthBudget]; everything else (custom, quote,
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
    return _tickerItemsTimeOnly(nowLocal);
  }
  return out;
}

/// KV + clock + optional RSS: ordered marquee items for [TickerCuratedRepository].
///
/// When [definitions] is empty, uses legacy ordering (time, live weather, RSS
/// news, then every `ticker.marquee.*` key in [kv] as `custom`). Otherwise uses
/// enabled rows from [TickerTapes] with weighted repeats per
/// [TickerTapeForCuration.frequencyWeight].
///
/// When [rejectCtx] is non-null and non-empty, every body string from
/// user-/feed-supplied sources (news titles/summaries/feed labels, weather,
/// quote, custom marquee KV bodies, stock display name) is passed through
/// [RejectFilterContext.censor] before assembly. Block-action terms are
/// already applied at ingest time via `suppressed = true`.
List<TickerItem> buildTickerItemsForMarquee({
  required Map<String, String> kv,
  required DateTime nowLocal,
  required List<TickerNewsCandidate> newsCandidates,
  CurrentWeatherTickerData? currentWeather,
  List<TickerTapeForCuration> definitions = const [],
  List<StockTickerRowForMarquee> stockRows = const [],
  List<WeatherGovAlertTickerItem> weatherGovAlerts = const [],
  RejectFilterContext? rejectCtx,
}) {
  AppDebugLog.curator(
    'ticker build: inputs definitions=${definitions.length} '
    'newsCandidates=${newsCandidates.length} stocks=${stockRows.length} '
    'govAlerts=${weatherGovAlerts.length} liveWeather=${currentWeather != null} '
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
      currentWeather: currentWeather,
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
    return _tickerItemsTimeOnly(nowLocal);
  }

  final fromDefs = _buildTickerItemsForMarqueeFromDefinitions(
    kv: kv,
    nowLocal: nowLocal,
    rssItems: rssItems,
    currentWeather: currentWeather,
    enabledDefinitions: enabled,
    stockRows: stockRows,
    weatherGovAlerts: weatherGovAlerts,
    rejectCtx: rejectCtx,
  );
  AppDebugLog.curator(
    'ticker build: path=definitions enabledRows=${enabled.length} items=${fromDefs.length}',
  );
  return fromDefs;
}
