import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/theme/tv_overscan.dart';

void main() {
  test('uses minimum inset when surface is tiny', () {
    const o = TvOverscanInsets(minimum: 12, fractionOfShortestSide: 0.1);
    final inset = o.resolve(const Size(50, 50));
    expect(inset.left, 12);
  });

  test('uses fraction when surface is large', () {
    const o = TvOverscanInsets(minimum: 4, fractionOfShortestSide: 0.1);
    final inset = o.resolve(const Size(1000, 800));
    expect(inset.left, 80);
  });
}
