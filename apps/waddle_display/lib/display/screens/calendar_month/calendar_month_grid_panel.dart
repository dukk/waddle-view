import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'calendar_month_grid.dart';
import 'calendar_upcoming_layout.dart';

/// Minimum height for the Sun–Sat row so [Text] is not clipped by a tight [SizedBox].
///
/// Kept public for layout tests that compare against [TextPainter] metrics.
double calendarWeekdayHeaderRowMinHeight(
  BuildContext context,
  TextStyle? weekdayStyle,
  double layoutScale,
  bool layoutCompact,
) {
  final s = layoutScale;
  final minH = (layoutCompact ? 16.0 : 20.0) * s;
  if (weekdayStyle == null) {
    return minH;
  }
  final fontSize = weekdayStyle.fontSize ?? 12.0;
  final lineFactor = weekdayStyle.height ?? 1.2;
  final scaled = MediaQuery.textScalerOf(context).scale(fontSize);
  final lineBox = scaled * lineFactor;
  return math.max(minH, lineBox + 4 * s);
}

const kCalendarWeekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const kCalendarMonthNamesShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Month title, weekday row, and day grid (calendar_month slide left column).
class CalendarMonthGridPanel extends StatelessWidget {
  const CalendarMonthGridPanel({
    super.key,
    required this.monthTitle,
    required this.cells,
    required this.markersByDay,
    required this.displayTodayDate,
    required this.theme,
    required this.layoutScale,
    required this.layoutCompact,
    this.forOverlay = false,
  });

  final String monthTitle;
  final List<MonthGridCell> cells;
  final Map<int, CalendarMonthDayMarkers> markersByDay;
  final DateTime displayTodayDate;
  final ThemeData theme;
  final double layoutScale;
  final bool layoutCompact;
  final bool forOverlay;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final weekdayStyle =
        (layoutCompact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            );
    final headingStyle =
        (layoutCompact
                ? theme.textTheme.titleLarge
                : theme.textTheme.headlineSmall)
            ?.copyWith(fontWeight: FontWeight.w600);
    final titleGap = (layoutCompact ? 6.0 : 12.0) * s;
    final grid = LayoutBuilder(
      builder: (context, gridConstraints) {
        final rows = math.max(1, cells.length ~/ 7);
        final spacing = 6 * s;
        final weekdayGridGap = (layoutCompact ? 4.0 : 8.0) * s;
        final weekdayRowHeight = calendarWeekdayHeaderRowMinHeight(
          context,
          weekdayStyle,
          s,
          layoutCompact,
        );
        final usableW = gridConstraints.maxWidth;
        final usableH = math.max(
          1.0,
          gridConstraints.maxHeight - weekdayRowHeight - weekdayGridGap,
        );
        final cellW = math.max(1.0, (usableW - 6 * spacing) / 7);
        final cellH = math.max(
          1.0,
          (usableH - (rows - 1) * spacing) / rows,
        );
        final cellSize = math.min(cellW, cellH);
        final gridWidth = cellSize * 7 + 6 * spacing;
        final gridHeight = cellSize * rows + (rows - 1) * spacing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: weekdayRowHeight,
              child: Center(
                child: SizedBox(
                  width: gridWidth,
                  child: Row(
                    children: kCalendarWeekdayLabels
                        .map(
                          (d) => Expanded(
                            child: Text(
                              d,
                              style: weekdayStyle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: weekdayGridGap),
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: 1,
                  ),
                  itemCount: cells.length,
                  itemBuilder: (context, index) {
                    final cell = cells[index];
                    final markers = cell.inCurrentMonth
                        ? (markersByDay[cell.day] ??
                            CalendarMonthDayMarkers.empty)
                        : CalendarMonthDayMarkers.empty;
                    return _CalendarMonthDayCell(
                      key: cell.inCurrentMonth
                          ? calendarMonthInMonthDayCellKey(cell.day)
                          : null,
                      cell: cell,
                      displayTodayDate: displayTodayDate,
                      theme: theme,
                      layoutScale: s,
                      markers: markers,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: forOverlay ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text(
          monthTitle,
          style: headingStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: titleGap),
        if (forOverlay)
          grid
        else
          Expanded(child: grid),
      ],
    );
  }
}

class _CalendarMonthDayCell extends StatelessWidget {
  const _CalendarMonthDayCell({
    super.key,
    required this.cell,
    required this.displayTodayDate,
    required this.theme,
    required this.layoutScale,
    required this.markers,
  });

  final MonthGridCell cell;
  final DateTime displayTodayDate;
  final ThemeData theme;
  final double layoutScale;
  final CalendarMonthDayMarkers markers;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final scheme = theme.colorScheme;
    final fill = calendarMonthDayCellFill(scheme, cell, displayTodayDate);

    final Color dayNumberColor;
    if (!cell.inCurrentMonth) {
      dayNumberColor = scheme.onSurface.withValues(alpha: 0.38);
    } else if (cell.isToday) {
      dayNumberColor = scheme.onSecondaryContainer;
    } else {
      final cellDay = calendarDateOnly(cell.calendarDate);
      final todayDay = calendarDateOnly(displayTodayDate);
      if (cellDay.isBefore(todayDay)) {
        dayNumberColor = scheme.onSurface.withValues(alpha: 0.80);
      } else {
        dayNumberColor = scheme.onSurface;
      }
    }
    final topColors = markers.allDayTopColors;
    final dotColors = markers.timedDotColors;
    final dotSize = math.max(3.0, 4.0 * s);
    final squareSize = math.max(4.0, 5.0 * s);
    final markerGap = 2.0 * s;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8 * s),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2 * s, vertical: 3 * s),
        child: Column(
          children: [
            if (topColors.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 2 * s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < topColors.length && i < 3; i++) ...[
                      if (i > 0) SizedBox(width: markerGap),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: topColors[i],
                          borderRadius: BorderRadius.circular(1 * s),
                        ),
                        child: SizedBox(
                          width: squareSize,
                          height: squareSize,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: Text(
                  '${cell.day}',
                  style:
                      (theme.textTheme.titleMedium ?? theme.textTheme.bodyLarge)
                          ?.copyWith(
                            color: dayNumberColor,
                            fontWeight: cell.isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                ),
              ),
            ),
            if (dotColors.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2 * s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < dotColors.length && i < 5; i++) ...[
                      if (i > 0) SizedBox(width: markerGap),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: dotColors[i],
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: dotSize,
                          height: dotSize,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
