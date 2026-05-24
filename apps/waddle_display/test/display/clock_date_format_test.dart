import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_display/display/screens/clock/clock_date_format.dart';

void main() {
  group('formatTickerDateMedium', () {
    final t = DateTime(2026, 5, 4, 14, 5, 9);

    test('mdy', () {
      expect(formatTickerDateMedium(t, kControllerDateOrderMdy), 'May 4, 2026');
    });

    test('dmy', () {
      expect(formatTickerDateMedium(t, kControllerDateOrderDmy), '4 May 2026');
    });

    test('ymd', () {
      expect(formatTickerDateMedium(t, kControllerDateOrderYmd), '2026-05-04');
    });
  });

  group('formatTickerDateTimeDisplayStyle', () {
    final t = DateTime(2026, 5, 4, 14, 5, 9);

    test('12h mdy', () {
      expect(
        formatTickerDateTimeDisplayStyle(
          t,
          dateOrder: kControllerDateOrderMdy,
          controllerTimeFormat: kControllerTimeFormat12h,
        ),
        'May 4, 2026, 2:05 PM',
      );
    });

    test('24h dmy', () {
      expect(
        formatTickerDateTimeDisplayStyle(
          t,
          dateOrder: kControllerDateOrderDmy,
          controllerTimeFormat: kControllerTimeFormat24h,
        ),
        '4 May 2026, 14:05',
      );
    });
  });

  group('formatTickerDateTime', () {
    test('combines medium date with preset time', () {
      expect(
        formatTickerDateTime(
          DateTime(2026, 5, 4, 14, 5, 0),
          dateOrder: kControllerDateOrderMdy,
          timeFormatPreset: '12h_hm_tt',
        ),
        'May 4, 2026, 2:05pm',
      );
    });
  });

  group('tickerDateTimeNeedsSecondTimer', () {
    test('false for display default', () {
      expect(tickerDateTimeNeedsSecondTimer(null), isFalse);
    });

    test('true when preset includes seconds', () {
      expect(tickerDateTimeNeedsSecondTimer('24h_hms'), isTrue);
    });
  });
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

  test('formatTickerTimePreset compact 12h', () {
    expect(
      formatTickerTimePreset(DateTime(2026, 5, 4, 14, 5, 0), '12h_hm_tt'),
      '2:05pm',
    );
  });
}
