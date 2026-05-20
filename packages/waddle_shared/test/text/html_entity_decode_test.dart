import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/text/html_entity_decode.dart';

void main() {
  test('decodeHtmlEntities resolves named and numeric entities', () {
    expect(decodeHtmlEntities('Tom&amp;rsquo;s'), 'Tom\u2019s');
    expect(decodeHtmlEntities('&#169; Waddle'), '\u00A9 Waddle');
    expect(decodeHtmlEntities('&#x2014; dash'), '\u2014 dash');
  });

  test('decodeHtmlEntitiesFromField ignores non-strings', () {
    expect(decodeHtmlEntitiesFromField(null), '');
    expect(decodeHtmlEntitiesFromField(42), '');
    expect(decodeHtmlEntitiesFromField('&amp;lt;'), '<');
  });
}
