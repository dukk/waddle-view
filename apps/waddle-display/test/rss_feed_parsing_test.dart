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

  test('parseRssOrAtomXml skips RSS items with no stable key', () {
    const xml = '''
<?xml version="1.0"?>
<rss version="2.0"><channel><title>X</title><link>http://c</link>
<item><title>orphan</title></item>
<item><guid>ok</guid><title>T</title><link>http://u</link>
<pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate></item>
</channel></rss>''';
    final p = parseRssOrAtomXml(xml);
    expect(p.entries.length, 1);
    expect(p.entries.single.stableKey, 'ok');
  });

  test('parseRssOrAtomXml uses link when RSS guid missing', () {
    const xml = '''
<?xml version="1.0"?>
<rss version="2.0"><channel><title>X</title><link>http://c</link>
<item><title>Head</title><link>http://item</link>
<pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate></item>
</channel></rss>''';
    final p = parseRssOrAtomXml(xml);
    expect(p.entries.single.stableKey, 'http://item');
    expect(p.entries.single.link, 'http://item');
  });

  test('parseRssOrAtomXml falls back from RSS to Atom on invalid RSS', () {
    const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Only Atom</title>
  <id>urn:only</id>
  <updated>2026-01-03T12:00:00Z</updated>
  <entry>
    <id>e1</id>
    <title>Atom only item</title>
    <link href="http://atom/only" rel="alternate"/>
    <published>2026-01-02T12:00:00Z</published>
  </entry>
</feed>''';
    final p = parseRssOrAtomXml(xml);
    expect(p.channelTitle, 'Only Atom');
    expect(p.entries.single.title, 'Atom only item');
    expect(p.entries.single.stableKey, 'e1');
  });

  test('parseRssOrAtomXml uses Atom updated when published absent', () {
    const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Upd</title>
  <id>urn:u</id>
  <updated>2026-01-03T12:00:00Z</updated>
  <entry>
    <id>e-upd</id>
    <title>Only updated</title>
    <link href="http://u/item" rel="alternate"/>
    <updated>2026-01-04T15:30:00Z</updated>
  </entry>
</feed>''';
    final p = parseRssOrAtomXml(xml);
    expect(p.entries.single.publishedAtMs, greaterThan(0));
    expect(p.entries.single.stableKey, 'e-upd');
  });

  test(
    'parseRssOrAtomXml RSS image from description when enclosure is not image',
    () {
      const xml = '''
<?xml version="1.0"?>
<rss version="2.0"><channel><title>X</title><link>http://c</link>
<item>
  <title></title>
  <link>http://item</link>
  <guid>g-img</guid>
  <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
  <enclosure url="http://vid/m.mp4" type="video/mp4" length="1"/>
  <description><![CDATA[<p>Hi</p><img src="http://desc/pic.png" />]]></description>
</item>
</channel></rss>''';
      final p = parseRssOrAtomXml(xml);
      expect(p.entries.single.title, 'http://item');
      expect(p.entries.single.imageUrl, 'http://desc/pic.png');
    },
  );

  test('parseRssOrAtomXml skips Atom entries without usable href', () {
    const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Feed</title>
  <id>urn:f</id>
  <updated>2026-01-03T12:00:00Z</updated>
  <entry>
    <id>skip-me</id>
    <title>No link</title>
  </entry>
  <entry>
    <id>keep</id>
    <title>Has link</title>
    <link href="http://ok" rel="alternate"/>
    <published>2026-01-02T12:00:00Z</published>
  </entry>
</feed>''';
    final p = parseRssOrAtomXml(xml);
    expect(p.entries.length, 1);
    expect(p.entries.single.stableKey, 'keep');
  });
}

