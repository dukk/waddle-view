import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_display/data/providers/rss_news/rss_http_response_body_decode.dart';

void main() {
  test('decodeRssHttpResponseBody uses UTF-8 when charset is omitted (rss+xml)',
      () {
    const inner = 'It\u2019s headlines';
    final bytes = utf8.encode(
      '<?xml version="1.0"?><rss version="2.0"><channel><title>$inner'
      '</title></channel></rss>',
    );
    final res = http.Response.bytes(
      bytes,
      200,
      headers: {'content-type': 'application/rss+xml'},
    );
    expect(res.body, contains('\u00E2'),
        reason: 'package:http uses latin1 without charset — mojibake');
    expect(decodeRssHttpResponseBody(res), contains('\u2019'));
  });

  test('decodeRssHttpResponseBody honors Content-Type charset', () {
    final bytes = latin1.encode('<?xml version="1.0"?><t>Caf\xe9</t>');
    final res = http.Response.bytes(
      bytes,
      200,
      headers: {'content-type': 'application/rss+xml; charset=ISO-8859-1'},
    );
    expect(decodeRssHttpResponseBody(res), contains('Café'));
  });

  test('decodeRssHttpResponseBody honors XML encoding without HTTP charset',
      () {
    final inner = 'Caf\xe9';
    final bytes = latin1.encode(
      '<?xml version="1.0" encoding="ISO-8859-1"?><rss version="2.0">'
      '<channel><title>$inner</title></channel></rss>',
    );
    final res = http.Response.bytes(
      bytes,
      200,
      headers: {'content-type': 'application/rss+xml'},
    );
    expect(decodeRssHttpResponseBody(res), contains('Café'));
  });

  test('decodeRssHttpResponseBody skips UTF-8 BOM before declaration scan', () {
    const inner = 'Hi\u2019';
    final payload = utf8.encode(
      '<?xml version="1.0"?><rss version="2.0"><channel><title>$inner'
      '</title></channel></rss>',
    );
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...payload];
    final res = http.Response.bytes(
      bytes,
      200,
      headers: {'content-type': 'application/rss+xml'},
    );
    expect(decodeRssHttpResponseBody(res), contains('\u2019'));
  });
}
