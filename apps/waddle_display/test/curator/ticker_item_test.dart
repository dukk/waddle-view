import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/ticker_item.dart';

void main() {
  group('TickerRssSegments', () {
    test('equality and hashCode', () {
      const a = TickerRssSegments(
        sourceTitle: 'Src',
        articleTitle: 'Art',
        summary: 'Sum',
        showSource: true,
        sourceIconName: 'rss',
      );
      const b = TickerRssSegments(
        sourceTitle: 'Src',
        articleTitle: 'Art',
        summary: 'Sum',
        showSource: true,
        sourceIconName: 'rss',
      );
      const c = TickerRssSegments(
        sourceTitle: 'Src',
        articleTitle: 'Art',
        summary: 'Sum',
        showSource: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a == Object(), isFalse);
    });
  });

  group('TickerItem', () {
    test('equality includes rss segment', () {
      const rss = TickerRssSegments(
        sourceTitle: 'S',
        articleTitle: 'T',
        summary: 'U',
        showSource: false,
      );
      const a = TickerItem(kind: 'news', body: 'plain', rss: rss, articleId: 'x');
      const b = TickerItem(kind: 'news', body: 'plain', rss: rss, articleId: 'x');
      const c = TickerItem(kind: 'news', body: 'plain', rss: rss, articleId: 'y');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a == Object(), isFalse);
    });
  });
}
