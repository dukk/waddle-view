import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_shared/display/ticker_tape_config.dart';

/// When [config]['upcomingTime12Hour'] is a bool, returns it; otherwise uses
/// display [controller.time_format] from [kv] (`12h` → true, `24h` → false).
bool calendarUpcomingUse12HourFromConfig(
  Map<String, dynamic> config, {
  Map<String, String>? kv,
}) {
  final twelve = config['upcomingTime12Hour'];
  if (twelve is bool) {
    return twelve;
  }
  return controllerTimeFormatFromKv(kv ?? const {}) != kControllerTimeFormat24h;
}
