import 'package:flutter/material.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_calendar_month_settings.dart';

import '../../clock.dart';
import '../dashboard_viewport_scope.dart';
import '../screens/calendar_month/calendar_month_grid.dart';
import '../screens/calendar_month/calendar_month_grid_panel.dart';
import '../screens/calendar_month/calendar_month_slide_panel.dart';
import '../screens/calendar_month/calendar_upcoming_layout.dart';
import 'calendar_overlay_stream.dart';
import 'clock_overlay_layout.dart';

/// Renders one or more positioned month grids (overlay type `calendar_month`).
class CalendarMonthOverlay extends StatelessWidget {
  const CalendarMonthOverlay({
    super.key,
    required this.db,
    required this.blobs,
    required this.settingsList,
    required this.theme,
    this.clock = const SystemClock(),
  });

  final AppDatabase db;
  final BlobStore blobs;
  final List<CalendarMonthOverlaySettings> settingsList;
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
            final bundle = snap.bundle == null
                ? null
                : filterCalendarBundleByCategory(
                    snap.bundle!,
                    settings.categoryId,
                  );

            final nowWall = calendarInstantInZone(
              clock.now(),
              snap.displayZone,
            );
            final monthAnchor =
                DateTime(nowWall.year, nowWall.month, nowWall.day);
            final markersByDay = bundle == null
                ? <int, CalendarMonthDayMarkers>{}
                : buildCalendarMonthDayMarkersByDay(
                    rows: bundle.rows,
                    displayZone: snap.displayZone,
                    monthAnchor: monthAnchor,
                    colorScheme: theme.colorScheme,
                  );
            final cells = buildMonthGridCells(monthAnchor, snap.startOfToday);
            final monthTitle =
                '${kCalendarMonthNamesShort[monthAnchor.month - 1]} ${monthAnchor.year}';

            final panel = CalendarMonthSlidePanel(
              theme: theme,
              layoutScale: layoutScale,
              layoutCompact: layoutCompact,
              child: CalendarMonthGridPanel(
                monthTitle: monthTitle,
                cells: cells,
                markersByDay: markersByDay,
                displayTodayDate: snap.startOfToday,
                theme: theme,
                layoutScale: layoutScale,
                layoutCompact: layoutCompact,
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
