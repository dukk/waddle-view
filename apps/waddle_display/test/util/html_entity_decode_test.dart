import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/util/html_entity_decode.dart';

void main() {
  test('decodeHtmlEntities decodes rsquo and copy', () {
    expect(decodeHtmlEntities('caf&eacute; &copy;'), 'caf\u00E9 \u00A9');
    expect(decodeHtmlEntities('it&rsquo;s'), 'it\u2019s');
  });

  test('decodeHtmlEntities resolves double-encoded amp entities', () {
    expect(decodeHtmlEntities('&amp;rsquo;'), '\u2019');
    expect(decodeHtmlEntities('&amp;copy;'), '\u00A9');
    expect(decodeHtmlEntities('2 &amp;amp; 2'), '2 & 2');
  });

  test('decodeHtmlEntitiesFromField trims and handles non-strings', () {
    expect(decodeHtmlEntitiesFromField('  &nbsp;x  '), 'x');
    expect(decodeHtmlEntitiesFromField(null), '');
    expect(decodeHtmlEntitiesFromField(1), '');
  });
}
