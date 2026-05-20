import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../../clock.dart';
import '../../config/display_timezone.dart';
import '../screens/calendar_month/calendar_month_grid.dart';
import '../screens/calendar_month/calendar_upcoming_layout.dart';

/// Snapshot for calendar overlay builders (timezone + event bundle stream).
class CalendarOverlayStreamSnapshot {
  const CalendarOverlayStreamSnapshot({
    required this.displayZone,
    required this.startOfToday,
    required this.streamSnapshot,
  });

  final Location displayZone;
  final DateTime startOfToday;
  final AsyncSnapshot<CalendarMonthStreamBundle> streamSnapshot;

  CalendarMonthStreamBundle? get bundle => streamSnapshot.data;
}

/// Watches display timezone and calendar events from the current month onward.
class CalendarOverlayStreamBuilder extends StatefulWidget {
  const CalendarOverlayStreamBuilder({
    super.key,
    required this.db,
    required this.blobs,
    required this.clock,
    required this.builder,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final Clock clock;
  final Widget Function(BuildContext context, CalendarOverlayStreamSnapshot snap)
      builder;

  @override
  State<CalendarOverlayStreamBuilder> createState() =>
      _CalendarOverlayStreamBuilderState();
}

class _CalendarOverlayStreamBuilderState
    extends State<CalendarOverlayStreamBuilder> {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: watchDisplayTimezoneKv(widget.db),
      builder: (context, tzSnap) {
        final displayZone = resolveDisplayTimeZoneLocation(tzSnap.data);
        final eventStreamStartMs = startOfMonthInZoneMs(
          displayZone,
          widget.clock.now(),
        );
        final nowWall = calendarInstantInZone(widget.clock.now(), displayZone);
        final startOfToday =
            DateTime(nowWall.year, nowWall.month, nowWall.day);

        return StreamBuilder<CalendarMonthStreamBundle>(
          key: ValueKey<String>(
            '${_todayMsBoundary}_${displayZone.name}',
          ),
          stream: (widget.db.select(widget.db.calendarEvents)
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
            return widget.builder(
              context,
              CalendarOverlayStreamSnapshot(
                displayZone: displayZone,
                startOfToday: startOfToday,
                streamSnapshot: snapshot,
              ),
            );
          },
        );
      },
    );
  }
}

/// Filters [bundle] rows/events to a single optional [categoryId].
CalendarMonthStreamBundle filterCalendarBundleByCategory(
  CalendarMonthStreamBundle bundle,
  String? categoryId,
) {
  if (categoryId == null || categoryId.isEmpty) {
    return bundle;
  }
  final filteredRows = bundle.rows.where((r) {
    if (r.categories.any((c) => c.id == categoryId)) {
      return true;
    }
    return r.event.categoryId == categoryId;
  }).toList();
  final eventIds = filteredRows.map((r) => r.event.id).toSet();
  final filteredEvents = bundle.events
      .where((e) => eventIds.contains(e.id) || e.categoryId == categoryId)
      .toList();
  return CalendarMonthStreamBundle(
    events: filteredEvents,
    rows: filteredRows,
  );
}
