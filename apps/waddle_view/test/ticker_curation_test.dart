import 'package:flutter_test/flutter_test.dart';

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
}
