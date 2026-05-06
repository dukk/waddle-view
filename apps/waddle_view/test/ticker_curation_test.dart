import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/curator/curator_read_port.dart';
import 'package:waddle_view/curator/ticker_curation.dart';

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
}
