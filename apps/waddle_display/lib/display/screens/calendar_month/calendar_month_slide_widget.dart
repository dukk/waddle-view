import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import '../../../clock.dart';
import '../../../config/display_timezone.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:timezone/timezone.dart';
import 'calendar_month_grid.dart';
import 'calendar_upcoming_layout.dart';
import '../../content_category_material_icon.dart';
import '../../dashboard_viewport_scope.dart';

/// ValueKey for an in-current-month day cell on [CalendarMonthSlideWidget] (tests).
Key calendarMonthInMonthDayCellKey(int day) =>
    ValueKey<String>('calendar_month_in_month_$day');

const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _monthNamesShort = [
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

/// Month grid and upcoming events in two surfaced panels with consistent spacing.
class CalendarMonthSlideWidget extends StatefulWidget {
  const CalendarMonthSlideWidget({
    super.key,
    required this.db,
    required this.blobs,
    required this.spec,
    required this.theme,
    this.clock = const SystemClock(),
  });

  final AppDatabase db;
  final BlobStore blobs;
  final ParsedWidgetSpec spec;
  final ThemeData theme;
  final Clock clock;

  @override
  State<CalendarMonthSlideWidget> createState() =>
      _CalendarMonthSlideWidgetState();
}

class _CalendarMonthSlideWidgetState extends State<CalendarMonthSlideWidget> {
  Timer? _boundaryTimer;
  late int _todayMsBoundary;

  Future<void> _refreshDayBoundaryFromDb() async {
    final row = await (widget.db.select(widget.db.configKeyValues)
          ..where((t) => t.key.equals(kDisplayTimezoneKvKey)))
        .getSingleOrNull();
    final zone = resolveDisplayTimeZoneLocation(row?.value);
    final next = startOfTodayInZoneMs(zone, widget.clock.now());
    if (next != _todayMsBoundary && mounted) {
      setState(() => _todayMsBoundary = next);
    }
  }

  @override
  void initState() {
    super.initState();
    _todayMsBoundary = startOfTodayInZoneMs(
      resolveDisplayTimeZoneLocation(''),
      widget.clock.now(),
    );
    unawaited(_refreshDayBoundaryFromDb());
    _boundaryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refreshDayBoundaryFromDb());
    });
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    super.dispose();
  }

  /// Flex for the left column (compact calendar). Config: `leftFlex`.
  int get _calendarFlex {
    final v = widget.spec.config['leftFlex'];
    if (v is int && v > 0) {
      return v;
    }
    if (v is num && v.toInt() > 0) {
      return v.toInt();
    }
    return 1;
  }

  /// Flex for the right column (upcoming events). Config: `rightFlex`.
  int get _eventsFlex {
    final v = widget.spec.config['rightFlex'];
    if (v is int && v > 0) {
      return v;
    }
    if (v is num && v.toInt() > 0) {
      return v.toInt();
    }
    return 1;
  }

  CalendarMonthUpcomingTimeOptions get _upcomingTimeOptions =>
      CalendarMonthUpcomingTimeOptions.fromConfig(widget.spec.config);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = DashboardViewportScope.scaleOf(context);
        final mq = MediaQuery.sizeOf(context);
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mq.height;
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mq.width;
        final height = h.clamp(120.0, 4000.0);
        final layoutCompact = height < 240;

        return SizedBox(
          width: w,
          height: height,
          child: StreamBuilder<String?>(
            stream: watchDisplayTimezoneKv(widget.db),
            builder: (context, tzSnap) {
              final displayZone =
                  resolveDisplayTimeZoneLocation(tzSnap.data);
              final eventStreamStartMs = startOfMonthInZoneMs(
                displayZone,
                widget.clock.now(),
              );

              return StreamBuilder<CalendarMonthStreamBundle>(
                key: ValueKey<String>(
                  '${_todayMsBoundary}_${displayZone.name}',
                ),
                stream:
                    (widget.db.select(widget.db.calendarEvents)
                          ..where(
                            (t) => t.startMs.isBiggerOrEqualValue(
                              DateTime.fromMillisecondsSinceEpoch(
                                eventStreamStartMs,
                                isUtc: true,
                              ),
                            ),
                          )
                          ..orderBy([(t) => OrderingTerm.asc(t.startMs)]))
                        .watch()
                        .asyncMap(
                          (events) => buildCalendarMonthStreamBundle(
                            widget.db,
                            widget.blobs,
                            events,
                          ),
                        ),
                builder: (context, snapshot) {
                  final nowWall =
                      calendarInstantInZone(widget.clock.now(), displayZone);
                  final startOfToday =
                      DateTime(nowWall.year, nowWall.month, nowWall.day);
                  final todayStartZ = TZDateTime(
                    displayZone,
                    startOfToday.year,
                    startOfToday.month,
                    startOfToday.day,
                  );
                  final nextFiveDaysEndZ =
                      todayStartZ.add(const Duration(days: 5));
                  final fromMs = todayStartZ.millisecondsSinceEpoch;
                  final toMs = nextFiveDaysEndZ.millisecondsSinceEpoch;
                  final bundle = snapshot.data;
                  final allEvents = bundle?.events ?? [];
                  final filtered = allEvents
                      .where(
                        (event) {
                          final ms = event.startMs.millisecondsSinceEpoch;
                          return ms >= fromMs && ms < toMs;
                        },
                      )
                      .toList();
                  final deduped = dedupeCalendarEventsForDisplay(filtered);
                  final rowByEventId = {
                    for (final r in bundle?.rows ?? <CalendarSlideEventRow>[])
                      r.event.id: r,
                  };
                  final upcomingRows = deduped
                      .map((e) => rowByEventId[e.id])
                      .whereType<CalendarSlideEventRow>()
                      .toList();
                  final upcomingTime = _upcomingTimeOptions;
                  final listItems = buildCalendarUpcomingListItems(
                    rows: upcomingRows,
                    todayLocal: startOfToday,
                    displayZone: displayZone,
                    timeOptions: upcomingTime,
                  );
                  final monthAnchor =
                      DateTime(nowWall.year, nowWall.month, nowWall.day);
                  final markersByDay = bundle == null
                      ? <int, CalendarMonthDayMarkers>{}
                      : buildCalendarMonthDayMarkersByDay(
                          rows: bundle.rows,
                          displayZone: displayZone,
                          monthAnchor: monthAnchor,
                          colorScheme: widget.theme.colorScheme,
                        );
                  final cells = buildMonthGridCells(monthAnchor, startOfToday);
                  final monthTitle =
                      '${_monthNamesShort[monthAnchor.month - 1]} ${monthAnchor.year}';

                  final gap = (layoutCompact ? 12.0 : 20.0) * s;
                  final outerPad = EdgeInsets.symmetric(
                    horizontal: 24.0 * s,
                    vertical: (layoutCompact ? 8.0 : 16.0) * s,
                  );
                  final usableHeight =
                      math.max(120.0, height - outerPad.vertical);

                  return Padding(
                    padding: outerPad,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: usableHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: _calendarFlex,
                              child: _CalendarSlidePanel(
                                theme: widget.theme,
                                layoutScale: s,
                                layoutCompact: layoutCompact,
                                child: _MonthGridPanel(
                                  monthTitle: monthTitle,
                                  cells: cells,
                                  markersByDay: markersByDay,
                                  displayTodayDate: startOfToday,
                                  theme: widget.theme,
                                  layoutScale: s,
                                  layoutCompact: layoutCompact,
                                ),
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              flex: _eventsFlex,
                              child: _CalendarSlidePanel(
                                theme: widget.theme,
                                layoutScale: s,
                                layoutCompact: layoutCompact,
                                child: _UpcomingEventsPanel(
                                  snapshot: snapshot,
                                  listItems: listItems,
                                  hasUpcomingRows: upcomingRows.isNotEmpty,
                                  theme: widget.theme,
                                  layoutScale: s,
                                  layoutCompact: layoutCompact,
                                  timeColumnWidth: layoutCompact
                                      ? upcomingTime.timeWidthCompact * s
                                      : upcomingTime.timeWidth * s,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _CalendarSlidePanel extends StatelessWidget {
  const _CalendarSlidePanel({
    required this.theme,
    required this.layoutScale,
    required this.layoutCompact,
    required this.child,
  });

  final ThemeData theme;
  final double layoutScale;
  final bool layoutCompact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final pad = (layoutCompact ? 10.0 : 16.0) * s;
    return Padding(padding: EdgeInsets.all(pad), child: child);
  }
}

class _UpcomingEventsPanel extends StatelessWidget {
  const _UpcomingEventsPanel({
    required this.snapshot,
    required this.listItems,
    required this.hasUpcomingRows,
    required this.theme,
    required this.layoutScale,
    required this.layoutCompact,
    required this.timeColumnWidth,
  });

  final AsyncSnapshot<CalendarMonthStreamBundle> snapshot;
  final List<CalendarUpcomingListItem> listItems;
  final bool hasUpcomingRows;
  final ThemeData theme;
  final double layoutScale;
  final bool layoutCompact;
  final double timeColumnWidth;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final iconColor = theme.colorScheme.onSurfaceVariant;
    final headingStyle =
        (layoutCompact
                ? theme.textTheme.titleMedium
                : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w600);
    final headingGap = (layoutCompact ? 6.0 : 12.0) * s;
    final timeWidth = timeColumnWidth;
    final iconCol = 28.0 * s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Upcoming events', style: headingStyle),
        SizedBox(height: headingGap),
        if (snapshot.hasError)
          Expanded(
            child: Center(
              child: Text(
                'Error loading events.',
                style: muted,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (!hasUpcomingRows)
          Expanded(
            child: Center(
              child: Text(
                'No upcoming events.',
                style: muted,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: listItems.length,
              separatorBuilder: (context, index) => SizedBox(height: 12 * s),
              itemBuilder: (context, i) {
                final item = listItems[i];
                if (item is CalendarUpcomingDayHeading) {
                  return Text(
                    item.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }
                final entry = item as CalendarUpcomingEventEntry;
                final slideRow = entry.row;
                final e = slideRow.event;
                final loc = e.location;
                final cat = slideRow.category;
                final hasIcon =
                    slideRow.categoryIconBytes != null ||
                    (cat?.materialIconName?.trim().isNotEmpty ?? false);
                final markerColor =
                    calendarEventMarkerAccent(theme.colorScheme, e);
                final listDotD = math.max(8.0, 11.0 * s);
                final listSq = math.max(9.0, 12.0 * s);
                final markerExtent = e.allDay ? listSq : listDotD;
                final upcomingMarkerCol =
                    math.max(16.0 * s, markerExtent + 3 * s);
                final titleBlockStartPad = upcomingMarkerCol +
                    8 * s +
                    (hasIcon ? iconCol + 8 * s : 0);
                return Padding(
                  padding: EdgeInsets.only(left: 8 * s),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: timeWidth,
                        child: entry.showTimeColumn
                            ? Text(
                                entry.timeLabel,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(width: 10 * s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: upcomingMarkerCol,
                                  child: Center(
                                    child: DecoratedBox(
                                      key: ValueKey<String>(
                                        'calendar_upcoming_marker_${e.id}',
                                      ),
                                      decoration: BoxDecoration(
                                        color: markerColor,
                                        shape: e.allDay
                                            ? BoxShape.rectangle
                                            : BoxShape.circle,
                                        borderRadius: e.allDay
                                            ? BorderRadius.circular(2 * s)
                                            : null,
                                      ),
                                      child: SizedBox(
                                        width: markerExtent,
                                        height: markerExtent,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8 * s),
                                if (hasIcon) ...[
                                  SizedBox(
                                    width: iconCol,
                                    height: iconCol,
                                    child: slideRow.categoryIconBytes != null
                                        ? Image.memory(
                                            slideRow.categoryIconBytes!,
                                            width: iconCol,
                                            height: iconCol,
                                            fit: BoxFit.contain,
                                          )
                                        : Icon(
                                            contentCategoryMaterialIcon(
                                              slideRow.category
                                                  ?.materialIconName,
                                            ),
                                            size: iconCol,
                                            color: iconColor,
                                          ),
                                  ),
                                  SizedBox(width: 8 * s),
                                ],
                                Expanded(
                                  child: Text(
                                    e.title,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            if (loc != null && loc.isNotEmpty) ...[
                              SizedBox(height: 4 * s),
                              Padding(
                                padding:
                                    EdgeInsets.only(left: titleBlockStartPad),
                                child: Text(
                                  loc,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MonthGridPanel extends StatelessWidget {
  const _MonthGridPanel({
    required this.monthTitle,
    required this.cells,
    required this.markersByDay,
    required this.displayTodayDate,
    required this.theme,
    required this.layoutScale,
    required this.layoutCompact,
  });

  final String monthTitle;
  final List<MonthGridCell> cells;
  final Map<int, CalendarMonthDayMarkers> markersByDay;
  final DateTime displayTodayDate;
  final ThemeData theme;
  final double layoutScale;
  final bool layoutCompact;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          monthTitle,
          style: headingStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: titleGap),
        Expanded(
          child: LayoutBuilder(
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
                          children: _weekdayLabels
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
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: gridWidth,
                        height: gridHeight,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                            return _MonthDayCell(
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
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
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
