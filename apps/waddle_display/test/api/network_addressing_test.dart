import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/network_addressing.dart';

void main() {
  test('parseCorsAllowedOrigins trims and splits', () {
    expect(parseCorsAllowedOrigins(null), isEmpty);
    expect(parseCorsAllowedOrigins(''), isEmpty);
    expect(
      parseCorsAllowedOrigins(' http://a.test ,http://b.test, '),
      ['http://a.test', 'http://b.test'],
    );
  });
}
