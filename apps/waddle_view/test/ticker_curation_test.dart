import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/curator/curator_read_port.dart';
import 'package:waddle_view/curator/ticker_curation.dart';
import 'package:waddle_view/curator/ticker_news_candidate.dart';

void main() {
  test('orders time then known keys then extra keys', () {
    final t = DateTime(2026, 3, 4, 9, 8, 7);
    final items = buildTickerItemsFromKv(
      kv: {
        'ticker.marquee.news': 'N1',
        'ticker.marquee.weather': 'W1',
        'ticker.marquee.quote': 'Q1',
        'ticker.marquee.extra': 'E1',
      },
      nowLocal: t,
    );
    expect(items.map((e) => e.kind).toList(), [
      'time',
      'weather',
      'news',
      'quote',
      'custom',
    ]);
    expect(items[0].body, '09:08:07');
    expect(items[1].body, 'W1');
    expect(items[4].body, 'E1');
  });

  test('dedupes identical bodies', () {
    final items = buildTickerItemsFromKv(
      kv: {
        'ticker.marquee.news': 'Same',
        'ticker.marquee.weather': 'Same',
      },
      nowLocal: DateTime(2020, 1, 1),
    );
    expect(items.where((e) => e.body == 'Same').length, 1);
  });

  test('redacts sensitive substrings', () {
    final items = buildTickerItemsFromKv(
      kv: {'ticker.marquee.news': 'token password=secret'},
      nowLocal: DateTime(2020, 1, 1),
    );
    expect(
      items.any((e) => e.kind == 'news' && e.body == '[redacted]'),
      isTrue,
    );
  });

  test('skips empty marquee values', () {
    final items = buildTickerItemsFromKv(
      kv: {'ticker.marquee.news': '   '},
      nowLocal: DateTime(2020, 1, 1),
    );
    expect(items.where((e) => e.kind == 'news'), isEmpty);
    expect(items.first.kind, 'time');
  });

  test('composeTickerNewsBody covers prefix and summary branches', () {
    expect(
      composeTickerNewsBody(
        prefix: false,
        feedName: 'F',
        title: 'T',
        summary: '',
      ),
      'T:',
    );
    expect(
      composeTickerNewsBody(
        prefix: false,
        feedName: 'F',
        title: 'T',
        summary: ' S ',
      ),
      'T: S',
    );
    expect(
      composeTickerNewsBody(
        prefix: true,
        feedName: 'F',
        title: 'T',
        summary: '',
      ),
      'F T:',
    );
    expect(
      composeTickerNewsBody(
        prefix: true,
        feedName: 'F',
        title: 'T',
        summary: 'S',
      ),
      'F T: S',
    );
  });

  test('redactTickerBody catches bearer substring', () {
    expect(
      redactTickerBody('Authorization: Bearer x'),
      '[redacted]',
    );
  });

  test('buildTickerItemsForMarquee uses current weather when available', () {
    final items = buildTickerItemsForMarquee(
      kv: {
        'ticker.marquee.weather': 'Fallback Weather',
      },
      nowLocal: DateTime(2026, 5, 1, 10, 0, 0),
      newsCandidates: const [],
      currentWeather: const CurrentWeatherTickerData(
        locationName: 'Denver, CO',
        temperatureC: 19.6,
        description: 'sunny',
      ),
    );
    final weather = items.firstWhere((e) => e.kind == 'weather');
    expect(weather.body, 'Denver, CO: 20° · sunny');
  });

  test('buildTickerItemsForMarquee omits types not present in definitions', () {
    final defs = [
      const TickerDefinitionForCuration(
        id: 't1',
        tickerType: 'time',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 0,
      ),
      const TickerDefinitionForCuration(
        id: 't2',
        tickerType: 'news',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 10,
      ),
    ];
    final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    final items = buildTickerItemsForMarquee(
      kv: {
        'ticker.marquee.weather': 'W',
        'ticker.marquee.news': 'KV',
        'curator.ticker.newsScrollBudgetSeconds': '10000',
        'curator.ticker.newsCharWidthPx': '1',
        'curator.ticker.newsSeparatorPaddingPx': '0',
      },
      nowLocal: DateTime(2026, 3, 4, 9, 8, 7),
      newsCandidates: [
        TickerNewsCandidate(
          feedId: 'fx',
          feedName: 'F',
          title: 'RSS',
          publishedAtMs: ms,
        ),
      ],
      definitions: defs,
    );
    expect(items.map((e) => e.kind).toList(), ['time', 'news']);
    expect(items.any((e) => e.kind == 'weather'), isFalse);
  });

  test('buildTickerItemsForMarquee uses definition sort_order', () {
    final defs = [
      const TickerDefinitionForCuration(
        id: 'n',
        tickerType: 'news',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 20,
      ),
      const TickerDefinitionForCuration(
        id: 'q',
        tickerType: 'quote',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 10,
      ),
      const TickerDefinitionForCuration(
        id: 't',
        tickerType: 'time',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 0,
      ),
    ];
    final items = buildTickerItemsForMarquee(
      kv: {
        'ticker.marquee.news': 'N',
        'ticker.marquee.quote': 'Q',
      },
      nowLocal: DateTime(2026, 3, 4, 9, 8, 7),
      newsCandidates: const [],
      definitions: defs,
    );
    expect(items.map((e) => e.kind).toList(), ['time', 'quote', 'news']);
  });

  test('buildTickerItemsForMarquee falls back to time when all definitions disabled', () {
    final defs = [
      const TickerDefinitionForCuration(
        id: 'x',
        tickerType: 'news',
        enabled: false,
        frequencyWeight: 1,
        sortOrder: 0,
      ),
    ];
    final items = buildTickerItemsForMarquee(
      kv: {'ticker.marquee.news': 'Headline'},
      nowLocal: DateTime(2026, 3, 4, 9, 8, 7),
      newsCandidates: const [],
      definitions: defs,
    );
    expect(items.map((e) => e.kind).toList(), ['time']);
  });

  test('buildTickerItemsForMarquee applies frequency_weight for distinct news bodies', () {
    final defs = [
      const TickerDefinitionForCuration(
        id: 'n',
        tickerType: 'news',
        enabled: true,
        frequencyWeight: 2,
        sortOrder: 0,
      ),
    ];
    final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    final items = buildTickerItemsForMarquee(
      kv: {
        'curator.ticker.newsScrollBudgetSeconds': '10000',
        'curator.ticker.newsCharWidthPx': '1',
        'curator.ticker.newsSeparatorPaddingPx': '0',
        'curator.ticker.newsPrefixCategory': 'false',
      },
      nowLocal: DateTime(2026, 3, 4, 9, 8, 7),
      newsCandidates: [
        TickerNewsCandidate(
          feedId: 'a',
          feedName: 'A',
          title: 'One',
          publishedAtMs: ms + 2,
        ),
        TickerNewsCandidate(
          feedId: 'b',
          feedName: 'B',
          title: 'Two',
          publishedAtMs: ms + 1,
        ),
      ],
      definitions: defs,
    );
    expect(items.where((e) => e.kind == 'news').length, 2);
  });
}
