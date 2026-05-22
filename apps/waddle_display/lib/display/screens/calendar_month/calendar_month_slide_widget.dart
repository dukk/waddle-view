import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import '../../../clock.dart';
import '../../../config/display_timezone.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/content_category_resolve.dart';
import 'package:waddle_shared/persistence/display_overlay_calendar_upcoming_settings.dart';
import 'package:waddle_shared/persistence/tables.dart';
import '../slide_vertical_scroll_timing.dart';
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
    this.onReportDesiredDwell,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final ParsedWidgetSpec spec;
  final ThemeData theme;
  final Clock clock;
  final void Function(int desiredDwellMs)? onReportDesiredDwell;

  @override
  State<CalendarMonthSlideWidget> createState() =>
      _CalendarMonthSlideWidgetState();
}

class _CalendarMonthSlideWidgetState extends State<CalendarMonthSlideWidget> {
  Timer? _boundaryTimer;
  late int _todayMsBoundary;
  final ScrollController _upcomingScroll = ScrollController();
  Timer? _scrollDelayTimer;
  bool _dwellReported = false;
  String? _resolvedFilterCategoryId;

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
    unawaited(_resolveFilterCategory());
    _boundaryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refreshDayBoundaryFromDb());
    });
    _upcomingScroll.addListener(_onUpcomingScrollMetrics);
  }

  Future<void> _resolveFilterCategory() async {
    final id = await resolveCategoryFromConfig(widget.db, widget.spec.config);
    if (mounted) {
      setState(() => _resolvedFilterCategoryId = id);
    }
  }

  int _cfgInt(String key, int def) {
    final v = widget.spec.config[key];
    if (v is int) return v;
    if (v is double) return v.round();
    return def;
  }

  bool _cfgBool(String key, bool def) {
    final v = widget.spec.config[key];
    if (v is bool) return v;
    return def;
  }

  int get _upcomingDays {
    final v = widget.spec.config['upcomingDays'];
    if (v is int) {
      return v.clamp(kCalendarUpcomingOverlayDaysMin, kCalendarUpcomingOverlayDaysMax);
    }
    if (v is double) {
      return v.round().clamp(
        kCalendarUpcomingOverlayDaysMin,
        kCalendarUpcomingOverlayDaysMax,
      );
    }
    return kCalendarUpcomingOverlayDaysDefault;
  }

  bool get _hidePastEvents => _cfgBool('hidePastEvents', false);

  void _onUpcomingScrollMetrics() {
    if (_dwellReported || widget.onReportDesiredDwell == null) return;
    if (!_upcomingScroll.hasClients) return;
    final extent = _upcomingScroll.position.maxScrollExtent;
    if (extent <= 8) return;
    _scheduleUpcomingScrollDwell(extent);
  }

  void _scheduleUpcomingScrollDwell(double maxScrollExtent) {
    if (_dwellReported) return;
    final scrollDelayMs = _cfgInt('upcomingScrollDelayMs', 0);
    final trailingHoldMs = _cfgInt('upcomingTrailingHoldMs', 0);
    final minReadMs = _cfgInt('upcomingMinReadMs', 8000);
    final pps = (widget.spec.config['upcomingScrollPixelsPerSecond'] as num?)
            ?.toDouble() ??
        48.0;
    _scrollDelayTimer?.cancel();
    _scrollDelayTimer = Timer(Duration(milliseconds: scrollDelayMs), () {
      if (!mounted || _dwellReported) return;
      final desired = desiredDwellMsForVerticalScroll(
        baseDwellMs: 0,
        minReadMs: minReadMs,
        scrollable: true,
        scrollDelayMs: scrollDelayMs,
        trailingHoldMs: trailingHoldMs,
        maxScrollExtent: maxScrollExtent,
        scrollPixelsPerSecond: pps,
      );
      _dwellReported = true;
      widget.onReportDesiredDwell!(desired);
      unawaited(
        _upcomingScroll.animateTo(
          maxScrollExtent,
          duration: Duration(
            milliseconds: scrollAnimationDurationMs(
              maxScrollExtent: maxScrollExtent,
              pixelsPerSecond: pps,
            ),
          ),
          curve: Curves.linear,
        ),
      );
    });
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    _scrollDelayTimer?.cancel();
    _upcomingScroll.removeListener(_onUpcomingScrollMetrics);
    _upcomingScroll.dispose();
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

  String? get _filterCategoryId => _resolvedFilterCategoryId;

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
                  final upcomingDays = _upcomingDays;
                  final nextDaysEndZ =
                      todayStartZ.add(Duration(days: upcomingDays));
                  final fromMs = todayStartZ.millisecondsSinceEpoch;
                  final toMs = nextDaysEndZ.millisecondsSinceEpoch;
                  final windowEndDate =
                      startOfToday.add(Duration(days: upcomingDays));
                  final nowWallMs = nowWall.millisecondsSinceEpoch;
                  final bundle = snapshot.data;
                  final allEvents = bundle?.events ?? [];
                  final filtered = allEvents
                      .where(
                        (event) {
                          if (event.allDay) {
                            if (!_calendarAllDayInUpcomingWindow(
                              event,
                              startOfToday,
                              windowEndDate,
                            )) {
                              return false;
                            }
                            if (_hidePastEvents) {
                              return !calendarAllDayCivilRangesOverlap(
                                event.startMs,
                                event.endMs,
                                startOfToday.subtract(const Duration(days: 1)),
                                startOfToday,
                              );
                            }
                            return true;
                          }
                          final ms =
                              event.startMs.millisecondsSinceEpoch;
                          if (ms < fromMs || ms >= toMs) {
                            return false;
                          }
                          if (_hidePastEvents && ms < nowWallMs) {
                            return false;
                          }
                          return true;
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
                                  scrollController: _upcomingScroll,
                                  enableScroll: widget.onReportDesiredDwell != null,
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

bool _calendarAllDayInUpcomingWindow(
  CalendarEvent event,
  DateTime startOfToday,
  DateTime windowEndDate,
) {
  return calendarAllDayCivilRangesOverlap(
    event.startMs,
    event.endMs,
    startOfToday,
    windowEndDate,
  );
}

