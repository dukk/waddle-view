import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/data/providers/rss_feed_parsing.dart';

const _miniRss = '''
<?xml version="1.0"?>
<rss version="2.0">
<channel>
<title>Ch</title>
<link>http://ch</link>
<item>
  <title>First</title>
  <link>http://one</link>
  <guid>g1</guid>
  <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
  <enclosure url="http://img/x.png" type="image/png" length="1"/>
</item>
<item>
  <title>Second</title>
  <link>http://two</link>
  <guid>g2</guid>
  <pubDate>Tue, 02 Jan 2024 12:00:00 GMT</pubDate>
</item>
</channel>
</rss>
''';

const _miniAtom = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom source</title>
  <id>urn:test</id>
  <updated>2026-01-03T12:00:00Z</updated>
  <entry>
    <id>tag:test:2</id>
    <title>Atom headline</title>
    <link href="http://atom/item" rel="alternate"/>
    <published>2026-01-02T12:00:00Z</published>
    <summary type="html">&lt;img src="http://atom/img.jpg" /&gt;</summary>
  </entry>
</feed>
''';

const _rssEntitiesInCdata = '''
<?xml version="1.0"?>
<rss version="2.0">
<channel><title>Ch &amp; Co</title><link>http://ch</link>
<item>
  <title><![CDATA[Breaking &amp; bold <b>news</b>]]></title>
  <link>http://one</link>
  <guid>e1</guid>
  <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
</item>
</channel></rss>
''';

void main() {
  test('parseRssOrAtomXml cleans entities and markup in titles', () {
    final p = parseRssOrAtomXml(_rssEntitiesInCdata);
    expect(p.channelTitle, 'Ch & Co');
    expect(p.entries.single.title, 'Breaking & bold news');
  });

  test('parseRssOrAtomXml reads RSS items and image from enclosure', () {
    final p = parseRssOrAtomXml(_miniRss);
    expect(p.channelTitle, 'Ch');
    expect(p.entries.length, 2);
    expect(p.entries[0].stableKey, 'g1');
    expect(p.entries[0].imageUrl, 'http://img/x.png');
    expect(p.entries[1].imageUrl, isNull);
  });

  test('parseRssOrAtomXml reads Atom entry with image in summary', () {
    final p = parseRssOrAtomXml(_miniAtom);
    expect(p.channelTitle, 'Atom source');
    expect(p.entries.length, 1);
    expect(p.entries.single.stableKey, 'tag:test:2');
    expect(p.entries.single.imageUrl, 'http://atom/img.jpg');
  });
}
