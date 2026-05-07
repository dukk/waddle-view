import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/data/providers/rss_news/rss_text_sanitize.dart';

void main() {
  test('sanitizeRssDisplayText decodes common entities', () {
    expect(sanitizeRssDisplayText('A &amp; B'), 'A & B');
    expect(sanitizeRssDisplayText('2 &lt; 4'), '2 < 4');
    expect(sanitizeRssDisplayText('&quot;x&quot;'), '"x"');
  });

  test('sanitizeRssDisplayText decodes numeric entities', () {
    expect(sanitizeRssDisplayText('&#39;Hi&#39;'), "'Hi'");
    expect(sanitizeRssDisplayText('&#x2019;'), '\u2019');
    expect(sanitizeRssDisplayText('&#x1F600;'), '😀');
  });

  test('sanitizeRssDisplayText treats nbsp as space', () {
    expect(sanitizeRssDisplayText('a&nbsp;b'), 'a b');
    expect(sanitizeRssDisplayText('x\u00A0y'), 'x y');
  });

  test('sanitizeRssDisplayText strips HTML tags', () {
    expect(
      sanitizeRssDisplayText('<b>Bold</b> &amp; plain'),
      'Bold & plain',
    );
    expect(sanitizeRssDisplayText('Flash <i>news</i> here'), 'Flash news here');
  });

  test('sanitizeRssDisplayText removes zero-width and controls', () {
    expect(
      sanitizeRssDisplayText('A\u200BB\uFEFF'),
      'AB',
    );
    expect(sanitizeRssDisplayText('x\u0000y'), 'xy');
  });

  test('sanitizeRssDisplayText collapses whitespace', () {
    expect(sanitizeRssDisplayText('  a  \n\t b  '), 'a b');
  });

  test('sanitizeRssOptional returns null for empty', () {
    expect(sanitizeRssOptional(null), isNull);
    expect(sanitizeRssOptional('  '), isNull);
    expect(sanitizeRssOptional('&nbsp;'), isNull);
  });

  test('sanitizeRssLink trims and strips invisible, preserves query ampersands', () {
    expect(
      sanitizeRssLink(' http://x.test/q?a=1&b=2\u200B '),
      'http://x.test/q?a=1&b=2',
    );
  });
}
