import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/sleeper.dart';

void main() {
  test('FakeSleeper records sleeps', () async {
    final s = FakeSleeper();
    await s.sleep(const Duration(seconds: 2));
    await s.sleep(const Duration(seconds: 1));
    expect(s.recorded, [
      const Duration(seconds: 2),
      const Duration(seconds: 1),
    ]);
  });
}
