import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/dashboard/clock_date_format.dart';

void main() {
  group('formatClockDate', () {
    test('formats weekday month day year in English', () {
      final t = DateTime(2026, 5, 4);
      expect(formatClockDate(t), 'Monday, May 4, 2026');
    });

    test('Sunday maps correctly', () {
      final t = DateTime(2026, 5, 3);
      expect(formatClockDate(t), 'Sunday, May 3, 2026');
    });
  });

  group('formatClockTime24', () {
    test('zero-pads hour minute second', () {
      final t = DateTime(2026, 5, 4, 9, 5, 7);
      expect(formatClockTime24(t), '09:05:07');
    });

    test('midnight', () {
      final t = DateTime(2026, 5, 4, 0, 0, 0);
      expect(formatClockTime24(t), '00:00:00');
    });
  });
}
