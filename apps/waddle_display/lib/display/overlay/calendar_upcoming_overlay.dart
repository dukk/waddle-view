import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_calendar_upcoming_settings.dart';

import '../../clock.dart';
import '../dashboard_viewport_scope.dart';
import '../screens/calendar_month/calendar_month_grid.dart';
import '../screens/calendar_month/calendar_month_slide_panel.dart';
import '../screens/calendar_month/calendar_upcoming_events_panel.dart';
import '../screens/calendar_month/calendar_upcoming_layout.dart';
import 'calendar_overlay_stream.dart';
import 'clock_overlay_layout.dart';

/// Renders one or more positioned upcoming-event lists (overlay `calendar_upcoming`).
class CalendarUpcomingOverlay extends StatelessWidget {
  const CalendarUpcomingOverlay({
    super.key,
    required this.db,
    required this.blobs,
    required this.settingsList,
    required this.theme,
    this.clock = const SystemClock(),
  });

  final AppDatabase db;
  final BlobStore blobs;
  final List<CalendarUpcomingOverlaySettings> settingsList;
  final ThemeData theme;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    if (settingsList.isEmpty) {
      return const SizedBox.shrink();
    }
    return CalendarOverlayStreamBuilder(
      db: db,
      blobs: blobs,
      clock: clock,
      builder: (context, snap) {
        final viewportScale = DashboardViewportScope.scaleOf(context);
        final layoutScale = viewportScale > 0 ? viewportScale : 1.0;
        const layoutCompact = true;

        return ClockOverlayLayout(
          placements: settingsList.map((s) => s.placement).toList(),
          childBuilder: (context, index, placement, blockWidth) {
            final settings = settingsList[index];
            final timeOptions = CalendarMonthUpcomingTimeOptions.fromConfig(
              settings.calendarConfigMap(),
            );
            final bundle = snap.bundle == null
                ? null
                : filterCalendarBundleByCategory(
                    snap.bundle!,
                    settings.categoryId,
                  );

            final todayStartZ = TZDateTime(
              snap.displayZone,
              snap.startOfToday.year,
              snap.startOfToday.month,
              snap.startOfToday.day,
            );
            final windowEndDate = snap.startOfToday.add(
              Duration(days: settings.upcomingDays),
            );
            final fromMs = todayStartZ.millisecondsSinceEpoch;
            final toMs = todayStartZ
                .add(Duration(days: settings.upcomingDays))
                .millisecondsSinceEpoch;

            final allEvents = bundle?.events ?? [];
            final filtered = allEvents.where((event) {
              if (event.allDay) {
                return calendarAllDayCivilRangesOverlap(
                  event.startMs,
                  event.endMs,
                  snap.startOfToday,
                  windowEndDate,
                );
              }
              final ms = event.startMs.millisecondsSinceEpoch;
              return ms >= fromMs && ms < toMs;
            }).toList();
            final deduped = dedupeCalendarEventsForDisplay(filtered);
            final rowByEventId = {
              for (final r in bundle?.rows ?? <CalendarSlideEventRow>[])
                r.event.id: r,
            };
            final upcomingRows = deduped
                .map((e) => rowByEventId[e.id])
                .whereType<CalendarSlideEventRow>()
                .toList();
            final listItems = buildCalendarUpcomingListItems(
              rows: upcomingRows,
              todayLocal: snap.startOfToday,
              displayZone: snap.displayZone,
              timeOptions: timeOptions,
            );

            final filteredSnap = AsyncSnapshot<CalendarMonthStreamBundle>.withData(
              snap.streamSnapshot.connectionState,
              bundle ?? const CalendarMonthStreamBundle(events: [], rows: []),
            );

            final panel = CalendarMonthSlidePanel(
              theme: theme,
              layoutScale: layoutScale,
              layoutCompact: layoutCompact,
              child: CalendarUpcomingEventsPanel(
                snapshot: filteredSnap,
                listItems: listItems,
                hasUpcomingRows: upcomingRows.isNotEmpty,
                theme: theme,
                layoutScale: layoutScale,
                layoutCompact: layoutCompact,
                timeColumnWidth: timeOptions.timeWidthCompact * layoutScale,
                forOverlay: true,
              ),
            );

            return SizedBox(
              width: blockWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: blockWidth / layoutScale,
                  child: panel,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
