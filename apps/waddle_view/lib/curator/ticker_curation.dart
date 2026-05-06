import 'package:flutter/foundation.dart';

import '../clock.dart';
import 'curator_read_port.dart';
import 'ticker_item.dart';
import 'ticker_news_candidate.dart';

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
      ),
    );
  }

  addIfNew(
    TickerItem(
      kind: 'time',
      body: _formatClock(nowLocal),
      sourceId: 'clock',
    ),
  );

  for (final e in _orderedMarqueeKeysToKind.entries) {
    final raw = kv[e.key];
    if (raw == null || raw.trim().isEmpty) {
      continue;
    }
    addIfNew(TickerItem(kind: e.value, body: raw.trim(), sourceId: e.key));
  }

  final extraKeys = kv.keys.where((k) {
    return k.startsWith('ticker.marquee.') &&
        !_orderedMarqueeKeysToKind.containsKey(k);
  }).toList()
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

String _formatClock(DateTime now) {
  final h = now.hour.toString().padLeft(2, '0');
  final m = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Formats [Clock.now] for tests that do not need full curation.
String formatTickerTime(Clock clock) =>
    _formatClock(clock.now().toLocal());

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
List<TickerItem> pickNewsTickerItemsByWidthBudget({
  required List<TickerNewsCandidate> interleaved,
  required CuratorTickerConfig config,
}) {
  final out = <TickerItem>[];
  final budget = config.newsScrollBudgetPx;
  var used = 0.0;
  final sep = config.newsSeparatorPaddingPx;
  for (final c in interleaved) {
    final title = redactTickerBody(c.title.trim());
    final summary = redactTickerBody((c.summary ?? '').trim());
    final source = redactTickerBody(c.feedName.trim());
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

const _orderedMarqueeKeysToKind = <String, String>{
  'ticker.marquee.weather': 'weather',
  'ticker.marquee.news': 'news',
  'ticker.marquee.quote': 'quote',
};

List<TickerItem> _tickerItemsTimeOnly(DateTime nowLocal) {
  final item = TickerItem(
    kind: 'time',
    body: _formatClock(nowLocal),
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
    ),
  ];
}

void _addTickerIfNew(
  List<TickerItem> out,
  Set<String> seenBodies,
  TickerItem item,
) {
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
    ),
  );
}

/// KV + clock + optional RSS: legacy ordering when [definitions] is empty.
List<TickerItem> _buildTickerItemsForMarqueeLegacy({
  required Map<String, String> kv,
  required DateTime nowLocal,
  required List<TickerItem> rssItems,
  CurrentWeatherTickerData? currentWeather,
}) {
  final out = <TickerItem>[];
  final seenBodies = <String>{};

  _addTickerIfNew(
    out,
    seenBodies,
    TickerItem(
      kind: 'time',
      body: _formatClock(nowLocal),
      sourceId: 'clock',
    ),
  );

  final liveWeatherBody = currentWeather?.toTickerBody().trim() ?? '';
  final rawWeather = liveWeatherBody.isNotEmpty
      ? liveWeatherBody
      : (kv['ticker.marquee.weather']?.trim() ?? '');
  if (rawWeather.isNotEmpty) {
    _addTickerIfNew(
      out,
      seenBodies,
      TickerItem(
        kind: 'weather',
        body: rawWeather,
        sourceId: 'ticker.marquee.weather',
      ),
    );
  }

  if (rssItems.isNotEmpty) {
    for (final it in rssItems) {
      _addTickerIfNew(out, seenBodies, it);
    }
  } else {
    final rawNews = kv['ticker.marquee.news'];
    if (rawNews != null && rawNews.trim().isNotEmpty) {
      _addTickerIfNew(
        out,
        seenBodies,
        TickerItem(
          kind: 'news',
          body: rawNews.trim(),
          sourceId: 'ticker.marquee.news',
        ),
      );
    }
  }

  final rawQuote = kv['ticker.marquee.quote'];
  if (rawQuote != null && rawQuote.trim().isNotEmpty) {
    _addTickerIfNew(
      out,
      seenBodies,
      TickerItem(
        kind: 'quote',
        body: rawQuote.trim(),
        sourceId: 'ticker.marquee.quote',
      ),
    );
  }

  final extraKeys = kv.keys.where((k) {
    return k.startsWith('ticker.marquee.') &&
        !_orderedMarqueeKeysToKind.containsKey(k);
  }).toList()
    ..sort();
  for (final k in extraKeys) {
    final raw = kv[k]!.trim();
    if (raw.isEmpty) {
      continue;
    }
    _addTickerIfNew(
      out,
      seenBodies,
      TickerItem(kind: 'custom', body: raw, sourceId: k),
    );
  }

  return out;
}

List<TickerItem> _buildTickerItemsForMarqueeFromDefinitions({
  required Map<String, String> kv,
  required DateTime nowLocal,
  required List<TickerItem> rssItems,
  CurrentWeatherTickerData? currentWeather,
  required List<TickerDefinitionForCuration> enabledDefinitions,
  required List<StockTickerRowForMarquee> stockRows,
}) {
  String stockMarqueeBody(StockTickerRowForMarquee row) {
    final label = row.symbol.trim().isEmpty ? row.symbolId : row.symbol.trim();
    final price = row.currentPrice;
    final pct = row.percentChange;
    final priceText =
        price != null ? '\$${price.toStringAsFixed(2)}' : '\u2014';
    final pctText = pct != null
        ? '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'
        : '\u2014';
    final dn = row.displayName.trim();
    if (dn.isNotEmpty) {
      return '$label ($dn) $priceText $pctText';
    }
    return '$label $priceText $pctText';
  }

  final liveWeatherBody = currentWeather?.toTickerBody().trim() ?? '';
  final rawWeather = liveWeatherBody.isNotEmpty
      ? liveWeatherBody
      : (kv['ticker.marquee.weather']?.trim() ?? '');

  List<TickerItem> expandTime() => [
    TickerItem(
      kind: 'time',
      body: _formatClock(nowLocal),
      sourceId: 'clock',
    ),
  ];

  List<TickerItem> expandWeather() {
    if (rawWeather.isEmpty) {
      return const [];
    }
    return [
      TickerItem(
        kind: 'weather',
        body: rawWeather,
        sourceId: 'ticker.marquee.weather',
      ),
    ];
  }

  List<TickerItem> expandNews() {
    if (rssItems.isNotEmpty) {
      return rssItems;
    }
    final rawNews = kv['ticker.marquee.news'];
    if (rawNews == null || rawNews.trim().isEmpty) {
      return const [];
    }
    return [
      TickerItem(
        kind: 'news',
        body: rawNews.trim(),
        sourceId: 'ticker.marquee.news',
      ),
    ];
  }

  List<TickerItem> expandQuote() {
    final rawQuote = kv['ticker.marquee.quote'];
    if (rawQuote == null || rawQuote.trim().isEmpty) {
      return const [];
    }
    return [
      TickerItem(
        kind: 'quote',
        body: rawQuote.trim(),
        sourceId: 'ticker.marquee.quote',
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

  List<TickerItem> expandCustom(TickerDefinitionForCuration def) {
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
    final extraKeys = kv.keys.where((k) {
      return k.startsWith('ticker.marquee.') &&
          !_orderedMarqueeKeysToKind.containsKey(k);
    }).toList()
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

  List<TickerItem> itemsForDef(TickerDefinitionForCuration def) {
    switch (def.tickerType.trim().toLowerCase()) {
      case 'time':
        return expandTime();
      case 'weather':
        return expandWeather();
      case 'news':
        return expandNews();
      case 'quote':
        return expandQuote();
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
    for (var i = 0; i < w; i++) {
      for (final item in chunk) {
        _addTickerIfNew(out, seenBodies, item);
      }
    }
  }

  if (out.isEmpty) {
    return _tickerItemsTimeOnly(nowLocal);
  }
  return out;
}

/// KV + clock + optional RSS: ordered marquee items for [TickerCuratedRepository].
///
/// When [definitions] is empty, uses legacy ordering (KV + RSS). Otherwise uses
/// enabled rows from [TickerDefinitions] with weighted repeats per
/// [TickerDefinitionForCuration.frequencyWeight].
List<TickerItem> buildTickerItemsForMarquee({
  required Map<String, String> kv,
  required DateTime nowLocal,
  required List<TickerNewsCandidate> newsCandidates,
  CurrentWeatherTickerData? currentWeather,
  List<TickerDefinitionForCuration> definitions = const [],
  List<StockTickerRowForMarquee> stockRows = const [],
}) {
  final cfg = CuratorTickerConfig.fromKv(kv);
  final rssItems = pickNewsTickerItemsByWidthBudget(
    interleaved: interleaveNewsByFeed(newsCandidates),
    config: cfg,
  );

  if (definitions.isEmpty) {
    return _buildTickerItemsForMarqueeLegacy(
      kv: kv,
      nowLocal: nowLocal,
      rssItems: rssItems,
      currentWeather: currentWeather,
    );
  }

  final enabled = definitions.where((d) => d.enabled).toList()
    ..sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      if (c != 0) {
        return c;
      }
      return a.id.compareTo(b.id);
    });

  if (enabled.isEmpty) {
    return _tickerItemsTimeOnly(nowLocal);
  }

  return _buildTickerItemsForMarqueeFromDefinitions(
    kv: kv,
    nowLocal: nowLocal,
    rssItems: rssItems,
    currentWeather: currentWeather,
    enabledDefinitions: enabled,
    stockRows: stockRows,
  );
}
