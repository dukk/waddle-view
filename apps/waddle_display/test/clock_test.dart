import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/clock.dart';

void main() {
  test('SystemClock returns plausible now', () {
    final c = SystemClock();
    final t = c.now();
    expect(t.isBefore(DateTime.now().add(const Duration(seconds: 2))), isTrue);
  });

  test('FakeClock returns fixed instant', () {
    final t = DateTime.utc(2030, 1, 2);
    final c = FakeClock(t);
    expect(c.now(), t);
    c.fixed = DateTime.utc(2031, 1, 1);
    expect(c.now(), DateTime.utc(2031, 1, 1));
  });
}
