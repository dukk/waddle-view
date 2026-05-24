import 'package:test/test.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_shared/display/calendar_screen_config.dart';

void main() {
  group('calendarUpcomingUse12HourFromConfig', () {
    test('uses explicit bool when set', () {
      expect(
        calendarUpcomingUse12HourFromConfig({'upcomingTime12Hour': false}),
        isFalse,
      );
    });

    test('defaults from kv 12h', () {
      expect(
        calendarUpcomingUse12HourFromConfig(
          const {},
          kv: {kControllerTimeFormatKvKey: kControllerTimeFormat12h},
        ),
        isTrue,
      );
    });

    test('defaults from kv 24h', () {
      expect(
        calendarUpcomingUse12HourFromConfig(
          const {},
          kv: {kControllerTimeFormatKvKey: kControllerTimeFormat24h},
        ),
        isFalse,
      );
    });
  });
}
