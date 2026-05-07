import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/api/api_key_constant_time.dart';

void main() {
  test('equal strings match', () {
    expect(constantTimeStringEquals('abc', 'abc'), isTrue);
  });

  test('different lengths never match', () {
    expect(constantTimeStringEquals('a', 'ab'), isFalse);
  });

  test('different same-length strings do not match', () {
    expect(constantTimeStringEquals('ab', 'ac'), isFalse);
  });
}
