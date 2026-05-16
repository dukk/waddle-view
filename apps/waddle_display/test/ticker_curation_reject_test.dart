import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/curator/curator_read_port.dart';
import 'package:waddle_display/curator/ticker_curation.dart';
import 'package:waddle_display/curator/ticker_news_candidate.dart';
import 'package:waddle_shared/curation/reject_filter.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/persistence/tables.dart';

RejectFilterContext _ctx({
  Iterable<({String term, String action})> entries = const [],
  CensorFormat format = CensorFormat.asterisksFull,
}) {
  return RejectFilterContext(
    terms: [
      for (final e in entries)
        RejectFilterTerm(term: e.term, action: e.action),
    ],
    format: format,
  );
}

void main() {
  test('news items censored: title and summary masked', () {
    final ctx = _ctx(entries: [(term: 'damn', action: kRejectTermActionCensor)]);
    final items = buildTickerItemsForMarquee(
      kv: const {},
      nowLocal: DateTime(2026, 1, 1, 12, 0, 0),
      newsCandidates: [
        TickerNewsCandidate(
          feedId: 'f1',
          feedName: 'Source',
          title: 'Today a damn dam broke',
          summary: 'It is really damn loud',
          publishedAtMs: 100,
          articleId: 'rej1',
        ),
      ],
      rejectCtx: ctx,
    );
    final news = items.where((e) => e.kind == 'news').single;
    expect(news.body.contains('damn'), isFalse);
    expect(news.body.contains('****'), isTrue);
    expect(news.rss?.articleTitle.contains('damn'), isFalse);
    expect(news.rss?.summary.contains('damn'), isFalse);
  });

  test('custom KV marquee body censored when custom tape enabled', () {
    final ctx = _ctx(
      entries: [(term: 'damn', action: kRejectTermActionCensor)],
    );
    final items = buildTickerItemsForMarquee(
      kv: const {
        'ticker.marquee.custom1': 'damn good day',
      },
      nowLocal: DateTime(2026, 1, 1, 12, 0, 0),
      newsCandidates: const [],
      rejectCtx: ctx,
      definitions: const [
        TickerTapeForCuration(
          id: 'q',
          tickerType: 'quote',
          enabled: true,
          frequencyWeight: 1,
          sortOrder: 0,
          configJson: '{"fallbackText":"That was so damn fast."}',
        ),
        TickerTapeForCuration(
          id: 'c',
          tickerType: 'custom',
          enabled: true,
          frequencyWeight: 1,
          sortOrder: 10,
        ),
      ],
    );
    final quote = items.firstWhere((e) => e.kind == 'quote');
    final custom = items.firstWhere((e) => e.kind == 'custom');
    expect(quote.body.contains('damn'), isFalse);
    expect(custom.body.contains('damn'), isFalse);
  });

  test('empty reject context preserves bodies unchanged', () {
    final items = buildTickerItemsForMarquee(
      kv: const {},
      nowLocal: DateTime(2026, 1, 1, 12, 0, 0),
      newsCandidates: const [],
      rejectCtx: const RejectFilterContext.empty(),
      definitions: const [
        TickerTapeForCuration(
          id: 'q',
          tickerType: 'quote',
          enabled: true,
          frequencyWeight: 1,
          sortOrder: 0,
          configJson: '{"fallbackText":"A damn quote"}',
        ),
      ],
    );
    final quote = items.firstWhere((e) => e.kind == 'quote');
    expect(quote.body, 'A damn quote');
  });

  test('bracketed_token format applied to news segments', () {
    final ctx = _ctx(
      entries: [(term: 'damn', action: kRejectTermActionCensor)],
      format: CensorFormat.bracketedToken,
    );
    final items = buildTickerItemsForMarquee(
      kv: const {},
      nowLocal: DateTime(2026, 1, 1, 12, 0, 0),
      newsCandidates: [
        TickerNewsCandidate(
          feedId: 'f1',
          feedName: 'Source',
          title: 'A damn story',
          summary: 'damn details',
          publishedAtMs: 100,
          articleId: 'rej2',
        ),
      ],
      rejectCtx: ctx,
    );
    final news = items.firstWhere((e) => e.kind == 'news');
    expect(news.body.contains('[censored]'), isTrue);
  });
}
