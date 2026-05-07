import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/clock/clock_date_format.dart';

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

  group('formatDigitalClockTime', () {
    test('12h noon and midnight', () {
      expect(
        formatDigitalClockTime(
          DateTime(2026, 5, 4, 0, 3, 0),
          hour24: false,
          showSeconds: false,
        ),
        '12:03 AM',
      );
      expect(
        formatDigitalClockTime(
          DateTime(2026, 5, 4, 12, 0, 0),
          hour24: false,
          showSeconds: false,
        ),
        '12:00 PM',
      );
    });

    test('12h with seconds', () {
      expect(
        formatDigitalClockTime(
          DateTime(2026, 5, 4, 23, 4, 9),
          hour24: false,
          showSeconds: true,
        ),
        '11:04:09 PM',
      );
    });
  });
}
