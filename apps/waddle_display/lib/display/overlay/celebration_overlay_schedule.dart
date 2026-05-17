import 'package:waddle_shared/curation/overlay_calendar_match.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';

export 'package:waddle_shared/curation/overlay_calendar_match.dart'
    show nthWeekdayOccurrenceInMonth;

bool matchesCelebrationOverlay(
  DisplayOverlayScheduleRow row,
  DateTime localNow,
) {
  return matchesOverlayCalendar(
    OverlayCalendarFields(
      repeatAnnually: row.repeatAnnually,
      yearExact: row.yearExact,
      startMonth: row.startMonth,
      startDay: row.startDay,
      endMonth: row.endMonth,
      endDay: row.endDay,
      nthWeekOfMonth: row.nthWeekOfMonth,
      nthWeekday: row.nthWeekday,
    ),
    localNow,
  );
}
