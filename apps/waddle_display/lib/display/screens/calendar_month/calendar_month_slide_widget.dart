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
import 'calendar_month_grid_panel.dart';
import 'calendar_month_slide_panel.dart';
import 'calendar_upcoming_events_panel.dart';
import 'calendar_upcoming_layout.dart';

export 'calendar_month_grid.dart' show calendarMonthInMonthDayCellKey;
export 'calendar_month_grid_panel.dart' show calendarWeekdayHeaderRowMinHeight;
import '../../content_category_slide_header.dart';
import '../../dashboard_viewport_scope.dart';

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

  /// When set, only [CalendarEvent.categoryId] matching this slug are loaded.
  String? get _filterCategoryId {
    final raw = widget.spec.config['categoryId'];
    if (raw is! String) {
      return null;
    }
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final filterCategoryId = _filterCategoryId;
    final body = LayoutBuilder(
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
                  '${_todayMsBoundary}_${displayZone.name}_$filterCategoryId',
                ),
                stream:
                    (widget.db.select(widget.db.calendarEvents)
                          ..where((t) {
                            final start = t.startMs.isBiggerOrEqualValue(
                              DateTime.fromMillisecondsSinceEpoch(
                                eventStreamStartMs,
                                isUtc: true,
                              ),
                            );
                            final cat = filterCategoryId;
                            if (cat == null) {
                              return start;
                            }
                            return start & t.categoryId.equals(cat);
                          })
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
                  final windowEndDate =
                      startOfToday.add(const Duration(days: 5));
                  final bundle = snapshot.data;
                  final allEvents = bundle?.events ?? [];
                  final filtered = allEvents
                      .where(
                        (event) {
                          if (event.allDay) {
                            return calendarAllDayCivilRangesOverlap(
                              event.startMs,
                              event.endMs,
                              startOfToday,
                              windowEndDate,
                            );
                          }
                          final ms =
                              event.startMs.millisecondsSinceEpoch;
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
                      '${kCalendarMonthNamesShort[monthAnchor.month - 1]} ${monthAnchor.year}';

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
                              child: CalendarMonthSlidePanel(
                                theme: widget.theme,
                                layoutScale: s,
                                layoutCompact: layoutCompact,
                                child: CalendarMonthGridPanel(
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
                              child: CalendarMonthSlidePanel(
                                theme: widget.theme,
                                layoutScale: s,
                                layoutCompact: layoutCompact,
                                child: CalendarUpcomingEventsPanel(
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
    if (filterCategoryId == null) {
      return body;
    }
    return Column(
      children: [
        ContentCategorySlideHeader(
          db: widget.db,
          blobs: widget.blobs,
          theme: widget.theme,
          categoryId: filterCategoryId,
        ),
        Expanded(child: body),
      ],
    );
  }
}

