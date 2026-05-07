import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/clock/clock_hand_angles.dart';

void main() {
  group('ClockHandAngles.fromLocal', () {
    test('midnight: all hands at twelve', () {
      final a = ClockHandAngles.fromLocal(DateTime(2026, 5, 4, 0, 0, 0));
      expect(a.hour, 0.0);
      expect(a.minute, 0.0);
      expect(a.second, 0.0);
    });

    test('three o clock hour hand points right', () {
      final a = ClockHandAngles.fromLocal(DateTime(2026, 5, 4, 15, 0, 0));
      expect(a.hour, closeTo(math.pi / 2, 1e-9));
      expect(a.minute, 0.0);
      expect(a.second, 0.0);
    });

    test('12 wraps for hour component', () {
      final a = ClockHandAngles.fromLocal(DateTime(2026, 5, 4, 12, 0, 0));
      expect(a.hour, 0.0);
    });

    test('minute hand includes fractional seconds', () {
      final a = ClockHandAngles.fromLocal(DateTime(2026, 5, 4, 0, 0, 30));
      expect(a.minute, closeTo(math.pi / 60.0, 1e-9));
    });

    test('half past: minute hand toward six', () {
      final a = ClockHandAngles.fromLocal(DateTime(2026, 5, 4, 0, 30, 0));
      expect(a.minute, closeTo(math.pi, 1e-9));
    });

    test('equality by radians', () {
      const a = ClockHandAngles(hour: 1, minute: 2, second: 3);
      const b = ClockHandAngles(hour: 1, minute: 2, second: 3);
      const c = ClockHandAngles(hour: 0, minute: 2, second: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
