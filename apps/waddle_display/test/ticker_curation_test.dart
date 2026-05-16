import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/clock.dart';
import 'package:waddle_display/curator/curator_read_port.dart';
import 'package:waddle_display/curator/ticker_curation.dart';
import 'package:waddle_display/curator/ticker_news_candidate.dart';

void main() {
  test('formatTickerTime formats clock local time', () {
    expect(
      formatTickerTime(FakeClock(DateTime(2026, 6, 1, 14, 5, 9))),
      '14:05:09',
    );
  });

  test('CurrentWeatherTickerData toTickerBody is location when no temp or description', () {
    expect(
      const CurrentWeatherTickerData(locationName: 'Paris').toTickerBody(),
      'Paris',
    );
  });

  test('TickerNewsCandidate publishedAt is UTC from epoch ms', () {
    final c = TickerNewsCandidate(
      feedId: 'f',
      feedName: 'F',
      title: 'T',
      publishedAtMs: 0,
      articleId: 'art0',
    );
    expect(c.publishedAt.isUtc, isTrue);
    expect(c.publishedAt.millisecondsSinceEpoch, 0);
  });

  test('parseTickerTapeFallbackText reads fallbackText and legacy keys', () {
    expect(
      parseTickerTapeFallbackText(jsonEncode({'fallbackText': '  x '})),
      'x',
    );
    expect(
      parseTickerTapeFallbackText(jsonEncode({'ticker.marquee.quote': 'y'})),
      'y',
    );
    expect(parseTickerTapeFallbackText(''), isNull);
    expect(parseTickerTapeFallbackText('not json'), isNull);
  });

  test('buildTickerItemsForMarquee quote tape uses config_json fallback', () {
    final items = buildTickerItemsForMarquee(
      kv: const {},
      nowLocal: DateTime(2026, 1, 1, 12, 0, 0),
      newsCandidates: const [],
      definitions: const [
        TickerTapeForCuration(
          id: 'q',
          tickerType: 'quote',
          enabled: true,
          frequencyWeight: 1,
          sortOrder: 0,
          configJson: '{"fallbackText":"Inspiration"}',
        ),
      ],
    );
    final q = items.singleWhere((e) => e.kind == 'quote');
    expect(q.body, 'Inspiration');
    expect(q.sourceId, 'ticker_tape:q');
  });

  test('buildTickerItemsFromKv orders time then sorted ticker.marquee keys as custom', () {
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
      'custom',
      'custom',
      'custom',
      'custom',
    ]);
    expect(items[0].body, '09:08:07');
    expect(items.map((e) => e.body).toList(), [
      '09:08:07',
      'E1',
      'N1',
      'Q1',
      'W1',
    ]);
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
      items.any((e) => e.kind == 'custom' && e.body == '[redacted]'),
      isTrue,
    );
  });

  test('skips empty marquee values', () {
    final items = buildTickerItemsFromKv(
      kv: {'ticker.marquee.news': '   '},
      nowLocal: DateTime(2020, 1, 1),
    );
    expect(items.where((e) => e.kind == 'custom'), isEmpty);
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
      kv: const {},
      nowLocal: DateTime(2026, 5, 1, 10, 0, 0),
      newsCandidates: const [],
      currentWeather: const CurrentWeatherTickerData(
        locationName: 'Denver, CO',
        temperatureC: 19.6,
        description: 'sunny',
      ),
      definitions: const [
        TickerTapeForCuration(
          id: 'w',
          tickerType: 'weather',
          enabled: true,
          frequencyWeight: 1,
          sortOrder: 0,
          configJson: '{"fallbackText":"Fallback Weather"}',
        ),
      ],
    );
    final weather = items.firstWhere((e) => e.kind == 'weather');
    expect(weather.body, 'Denver, CO: 20° · sunny');
    expect(weather.sourceId, 'ticker_tape:w');
  });

  test('buildTickerItemsForMarquee appends NWS alert lines after live weather', () {
    final items = buildTickerItemsForMarquee(
      kv: const {},
      nowLocal: DateTime(2026, 5, 1, 10, 0, 0),
      newsCandidates: const [],
      currentWeather: const CurrentWeatherTickerData(
        locationName: 'Denver, CO',
        temperatureC: 20,
        description: 'sunny',
      ),
      weatherGovAlerts: const [
        WeatherGovAlertTickerItem(
          body: 'Denver, CO — Heat Advisory — Hot',
          sourceId: 'nws.alert.urn:test',
        ),
      ],
      definitions: const [
        TickerTapeForCuration(
          id: 'w',
          tickerType: 'weather',
          enabled: true,
          frequencyWeight: 1,
          sortOrder: 0,
        ),
      ],
    );
    final weatherItems = items.where((e) => e.kind == 'weather').toList();
    expect(weatherItems, hasLength(2));
    expect(weatherItems[0].body, 'Denver, CO: 20° · sunny');
    expect(weatherItems[1].body, contains('Heat Advisory'));
    expect(weatherItems[1].sourceId, 'nws.alert.urn:test');
  });

  test('buildTickerItemsForMarquee omits types not present in definitions', () {
    final defs = [
      const TickerTapeForCuration(
        id: 't1',
        tickerType: 'time',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 0,
      ),
      TickerTapeForCuration(
        id: 't2',
        tickerType: 'news',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 10,
        configJson: jsonEncode({'fallbackText': 'KV'}),
      ),
    ];
    final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    final items = buildTickerItemsForMarquee(
      kv: {
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
          articleId: 'art-rss',
        ),
      ],
      definitions: defs,
    );
    expect(items.map((e) => e.kind).toList(), ['time', 'news']);
    expect(items.any((e) => e.kind == 'weather'), isFalse);
  });

  test('buildTickerItemsForMarquee uses definition sort_order', () {
    final defs = [
      const TickerTapeForCuration(
        id: 'n',
        tickerType: 'news',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 20,
        configJson: '{"fallbackText":"N"}',
      ),
      TickerTapeForCuration(
        id: 'q',
        tickerType: 'quote',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 10,
        configJson: '{"fallbackText":"Q"}',
      ),
      const TickerTapeForCuration(
        id: 't',
        tickerType: 'time',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 0,
      ),
    ];
    final items = buildTickerItemsForMarquee(
      kv: {
        'curator.ticker.newsScrollBudgetSeconds': '10000',
        'curator.ticker.newsCharWidthPx': '1',
        'curator.ticker.newsSeparatorPaddingPx': '0',
      },
      nowLocal: DateTime(2026, 3, 4, 9, 8, 7),
      newsCandidates: const [],
      definitions: defs,
    );
    expect(items.map((e) => e.kind).toList(), ['time', 'quote', 'news']);
  });

  test('buildTickerItemsForMarquee falls back to time when all definitions disabled', () {
    final defs = [
      const TickerTapeForCuration(
        id: 'x',
        tickerType: 'news',
        enabled: false,
        frequencyWeight: 1,
        sortOrder: 0,
      ),
    ];
    final items = buildTickerItemsForMarquee(
      kv: const {},
      nowLocal: DateTime(2026, 3, 4, 9, 8, 7),
      newsCandidates: const [],
      definitions: defs,
    );
    expect(items.map((e) => e.kind).toList(), ['time']);
  });

  test('buildTickerItemsForMarquee includes stocks from stockRows when definition enabled', () {
    final defs = [
      const TickerTapeForCuration(
        id: 's',
        tickerType: 'stocks',
        enabled: true,
        frequencyWeight: 1,
        sortOrder: 0,
      ),
    ];
    final items = buildTickerItemsForMarquee(
      kv: const {},
      nowLocal: DateTime(2026, 3, 4, 9, 8, 7),
      newsCandidates: const [],
      definitions: defs,
      stockRows: [
        (
          symbolId: 'aapl',
          symbol: 'AAPL',
          displayName: 'Apple',
          currentPrice: 261.74,
          percentChange: 1.23,
        ),
        (
          symbolId: 'zz',
          symbol: 'ZZ',
          displayName: '',
          currentPrice: null,
          percentChange: null,
        ),
        (
          symbolId: 'fallback-id',
          symbol: '   ',
          displayName: '',
          currentPrice: 1,
          percentChange: -2,
        ),
      ],
    );
    expect(items.map((e) => e.kind).toList(), ['stocks', 'stocks', 'stocks']);
    expect(items[0].body, r'AAPL (Apple) $261.74 +1.23%');
    expect(items[0].sourceId, 'aapl');
    expect(items[1].body, 'ZZ \u2014 \u2014');
    expect(items[2].body, r'fallback-id $1.00 -2.00%');
  });

  test('buildTickerItemsForMarquee applies frequency_weight for distinct news bodies', () {
    final defs = [
      const TickerTapeForCuration(
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
          articleId: 'art-one',
        ),
        TickerNewsCandidate(
          feedId: 'b',
          feedName: 'B',
          title: 'Two',
          publishedAtMs: ms + 1,
          articleId: 'art-two',
        ),
      ],
      definitions: defs,
    );
    expect(items.where((e) => e.kind == 'news').length, 2);
  });
}
