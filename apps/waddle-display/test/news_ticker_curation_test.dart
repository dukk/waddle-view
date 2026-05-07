import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/curator/ticker_curation.dart';
import 'package:waddle_display/curator/ticker_news_candidate.dart';

void main() {
  test('interleaveNewsByFeed returns empty for empty input', () {
    expect(interleaveNewsByFeed(const []), isEmpty);
  });

  test('interleaveNewsByFeed avoids adjacent same feed when possible', () {
    final a = DateTime.utc(2026, 1, 4).millisecondsSinceEpoch;
    final b = DateTime.utc(2026, 1, 3).millisecondsSinceEpoch;
    final c = DateTime.utc(2026, 1, 2).millisecondsSinceEpoch;
    final d = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    final candidates = [
      TickerNewsCandidate(
        feedId: 'f1',
        feedName: 'Local',
        title: 'f1 newest',
        publishedAtMs: a,
      ),
      TickerNewsCandidate(
        feedId: 'f1',
        feedName: 'Local',
        title: 'f1 old',
        publishedAtMs: d,
      ),
      TickerNewsCandidate(
        feedId: 'f2',
        feedName: 'World',
        title: 'f2 mid',
        publishedAtMs: b,
      ),
      TickerNewsCandidate(
        feedId: 'f2',
        feedName: 'World',
        title: 'f2 old',
        publishedAtMs: c,
      ),
    ];
    final x = interleaveNewsByFeed(candidates);
    expect(x.map((e) => e.feedId).toList(), ['f1', 'f2', 'f1', 'f2']);
  });

  test('pickNewsTickerItemsByWidthBudget adds one oversized headline when budget tiny', () {
    final cfg = CuratorTickerConfig(
      newsScrollBudgetSeconds: 1,
      newsPixelsPerSecond: 50,
      newsCharWidthPx: 10,
      newsSeparatorPaddingPx: 0,
      newsPrefixCategory: false,
    );
    final items = pickNewsTickerItemsByWidthBudget(
      interleaved: [
        const TickerNewsCandidate(
          feedId: 'a',
          feedName: 'x',
          title: '012345678901234567890',
          publishedAtMs: 1,
        ),
      ],
      config: cfg,
    );
    expect(items.length, 1);
  });

  test('pickNewsTickerItemsByWidthBudget stops when over px budget', () {
    final cfg = CuratorTickerConfig(
      newsScrollBudgetSeconds: 1,
      newsPixelsPerSecond: 200,
      newsCharWidthPx: 10,
      newsSeparatorPaddingPx: 0,
      newsPrefixCategory: false,
    );
    final interleaved = [
      const TickerNewsCandidate(
        feedId: 'a',
        feedName: 'x',
        title: '0123456789',
        publishedAtMs: 1,
      ),
      const TickerNewsCandidate(
        feedId: 'b',
        feedName: 'y',
        title: '0123456789',
        publishedAtMs: 2,
      ),
      const TickerNewsCandidate(
        feedId: 'a',
        feedName: 'x',
        title: '0123456789',
        publishedAtMs: 3,
      ),
    ];
    final items = pickNewsTickerItemsByWidthBudget(
      interleaved: interleaved,
      config: cfg,
    );
    expect(items.length, 2);
  });

  test('buildTickerItemsForMarquee uses KV news when RSS empty', () {
    final t = DateTime(2026, 3, 4, 9, 8, 7);
    final items = buildTickerItemsForMarquee(
      kv: {
        'ticker.marquee.news': 'KV headline',
        'ticker.marquee.weather': 'W',
      },
      nowLocal: t,
      newsCandidates: const [],
    );
    expect(items.map((e) => e.kind).toList(), ['time', 'weather', 'news']);
    expect(items[2].body, 'KV headline');
  });

  test('buildTickerItemsForMarquee prefers RSS over KV news', () {
    final t = DateTime(2026, 3, 4, 9, 8, 7);
    final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    final items = buildTickerItemsForMarquee(
      kv: {
        'ticker.marquee.news': 'KV headline',
        'curator.ticker.newsScrollBudgetSeconds': '10000',
        'curator.ticker.newsCharWidthPx': '1',
        'curator.ticker.newsSeparatorPaddingPx': '0',
        'curator.ticker.newsPrefixCategory': 'true',
      },
      nowLocal: t,
      newsCandidates: [
        TickerNewsCandidate(
          feedId: 'fx',
          feedName: 'Reuters',
          title: 'RSS title',
          publishedAtMs: ms,
        ),
      ],
    );
    expect(items.any((e) => e.body == 'KV headline'), isFalse);
    final news = items.firstWhere((e) => e.body.contains('RSS title'));
    expect(news.body, 'Reuters RSS title:');
    expect(news.rss, isNotNull);
    expect(news.rss!.showSource, isTrue);
    expect(news.rss!.sourceTitle, 'Reuters');
    expect(news.rss!.articleTitle, 'RSS title');
    expect(news.rss!.summary, '');
  });

  test('buildTickerItemsForMarquee appends sorted custom marquee keys', () {
    final t = DateTime(2026, 3, 4, 9, 8, 7);
    final ms = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    final items = buildTickerItemsForMarquee(
      kv: {
        'ticker.marquee.weather': 'W',
        'ticker.marquee.extra_z': 'Z',
        'ticker.marquee.extra_a': 'A',
        'ticker.marquee.extra_blank': '   ',
        'curator.ticker.newsScrollBudgetSeconds': '10000',
        'curator.ticker.newsCharWidthPx': '1',
        'curator.ticker.newsSeparatorPaddingPx': '0',
      },
      nowLocal: t,
      newsCandidates: [
        TickerNewsCandidate(
          feedId: 'fx',
          feedName: 'F',
          title: 'T',
          publishedAtMs: ms,
        ),
      ],
    );
    final customs =
        items.where((e) => e.kind == 'custom').map((e) => e.body).toList();
    expect(customs, ['A', 'Z']);
  });

  test('pickNewsTickerItemsByWidthBudget attaches summary to body and rss', () {
    final cfg = CuratorTickerConfig(
      newsScrollBudgetSeconds: 10000,
      newsPixelsPerSecond: 80,
      newsCharWidthPx: 1,
      newsSeparatorPaddingPx: 0,
      newsPrefixCategory: true,
    );
    final items = pickNewsTickerItemsByWidthBudget(
      interleaved: [
        const TickerNewsCandidate(
          feedId: 'a',
          feedName: 'BBC World',
          title: 'Headline',
          summary: 'The deck.',
          publishedAtMs: 1,
        ),
      ],
      config: cfg,
    );
    expect(items.single.body, 'BBC World Headline: The deck.');
    expect(items.single.rss!.summary, 'The deck.');
  });

  test('pickNewsTickerItemsByWidthBudget prefixes with feedName for brackets', () {
    final cfg = CuratorTickerConfig(
      newsScrollBudgetSeconds: 10000,
      newsPixelsPerSecond: 80,
      newsCharWidthPx: 1,
      newsSeparatorPaddingPx: 0,
      newsPrefixCategory: true,
    );
    final items = pickNewsTickerItemsByWidthBudget(
      interleaved: [
        const TickerNewsCandidate(
          feedId: 'a',
          feedName: 'BBC World',
          title: 'Headline',
          publishedAtMs: 1,
        ),
      ],
      config: cfg,
    );
    expect(items.single.body, 'BBC World Headline:');
    expect(items.single.rss!.sourceIconName, isNull);
  });

  test('pickNewsTickerItemsByWidthBudget carries category icon into rss segments', () {
    final cfg = CuratorTickerConfig(
      newsScrollBudgetSeconds: 10000,
      newsPixelsPerSecond: 80,
      newsCharWidthPx: 1,
      newsSeparatorPaddingPx: 0,
      newsPrefixCategory: true,
    );
    final items = pickNewsTickerItemsByWidthBudget(
      interleaved: [
        const TickerNewsCandidate(
          feedId: 'a',
          feedName: 'BBC World',
          title: 'Headline',
          categoryIconName: 'public',
          publishedAtMs: 1,
        ),
      ],
      config: cfg,
    );
    expect(items.single.rss!.sourceIconName, 'public');
  });

  test('CuratorTickerConfig.fromKv parses numeric and bool overrides', () {
    final c = CuratorTickerConfig.fromKv({
      'curator.ticker.newsScrollBudgetSeconds': ' 400 ',
      'curator.ticker.newsPixelsPerSecond': '92',
      'curator.ticker.newsCharWidthPx': '11.25',
      'curator.ticker.newsSeparatorPaddingPx': '18',
      'curator.ticker.newsPrefixCategory': '0',
    });
    expect(c.newsScrollBudgetSeconds, 400);
    expect(c.newsPixelsPerSecond, 92);
    expect(c.newsCharWidthPx, 11.25);
    expect(c.newsSeparatorPaddingPx, 18);
    expect(c.newsPrefixCategory, isFalse);
    expect(c.newsScrollBudgetPx, 400 * 92.0);
  });
}
