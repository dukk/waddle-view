import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../clock.dart';
import '../curator/screen_layout_parse.dart';
import '../persistence/database.dart';
import 'calendar_month_grid.dart';
import 'dashboard_viewport_scope.dart';

const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Month grid on the right (today highlighted); upcoming events on the left when present.
class CalendarMonthSlideWidget extends StatefulWidget {
  const CalendarMonthSlideWidget({
    super.key,
    required this.db,
    required this.spec,
    required this.theme,
    this.clock = const SystemClock(),
  });

  final AppDatabase db;
  final ParsedWidgetSpec spec;
  final ThemeData theme;
  final Clock clock;

  @override
  State<CalendarMonthSlideWidget> createState() =>
      _CalendarMonthSlideWidgetState();
}

class _CalendarMonthSlideWidgetState extends State<CalendarMonthSlideWidget> {
  Timer? _boundaryTimer;
  late int _startMsBoundary;

  @override
  void initState() {
    super.initState();
    _startMsBoundary = startOfTodayLocalMs(widget.clock.now());
    _boundaryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = startOfTodayLocalMs(widget.clock.now());
      if (next != _startMsBoundary && mounted) {
        setState(() => _startMsBoundary = next);
      }
    });
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    super.dispose();
  }

  int get _leftFlex {
    final v = widget.spec.config['leftFlex'];
    if (v is int && v > 0) {
      return v;
    }
    if (v is num && v.toInt() > 0) {
      return v.toInt();
    }
    return 2;
  }

  int get _rightFlex {
    final v = widget.spec.config['rightFlex'];
    if (v is int && v > 0) {
      return v;
    }
    if (v is num && v.toInt() > 0) {
      return v.toInt();
    }
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = DashboardViewportScope.scaleOf(context);
        final mq = MediaQuery.sizeOf(context);
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mq.height;
        final w =
            constraints.maxWidth.isFinite ? constraints.maxWidth : mq.width;
        final height = h.clamp(120.0, 4000.0);

        return SizedBox(
          width: w,
          height: height,
          child: StreamBuilder<List<CalendarEvent>>(
            key: ValueKey<int>(_startMsBoundary),
            stream: (widget.db.select(widget.db.calendarEvents)
                  ..where((t) => t.startMs.isBiggerOrEqualValue(_startMsBoundary))
                  ..orderBy([(t) => OrderingTerm.asc(t.startMs)]))
                .watch(),
            builder: (context, snapshot) {
              final events = snapshot.data ?? [];
              final now = widget.clock.now().toLocal();
              final monthAnchor = DateTime(now.year, now.month, now.day);
              final cells = buildMonthGridCells(monthAnchor, now);
              final monthTitle =
                  '${_monthNames[monthAnchor.month - 1]} ${monthAnchor.year}';

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (events.isNotEmpty)
                    Expanded(
                      flex: _leftFlex,
                      child: _UpcomingEventsList(
                        events: events,
                        theme: widget.theme,
                        layoutScale: s,
                      ),
                    ),
                  Expanded(
                    flex: events.isNotEmpty ? _rightFlex : 1,
                    child: _MonthGridPanel(
                      monthTitle: monthTitle,
                      cells: cells,
                      theme: widget.theme,
                      layoutScale: s,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _UpcomingEventsList extends StatelessWidget {
  const _UpcomingEventsList({
    required this.events,
    required this.theme,
    required this.layoutScale,
  });

  final List<CalendarEvent> events;
  final ThemeData theme;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    return ListView.separated(
      padding: EdgeInsets.only(right: 16 * s),
      itemCount: events.length,
      separatorBuilder: (context, index) => SizedBox(height: 10 * s),
      itemBuilder: (context, i) {
        final e = events[i];
        final time =
            formatCalendarEventListTime(e.startMs, e.allDay);
        final loc = e.location;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              e.title,
              style: theme.textTheme.titleMedium,
            ),
            if (loc != null && loc.isNotEmpty)
              Text(
                loc,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        );
      },
    );
  }
}

class _MonthGridPanel extends StatelessWidget {
  const _MonthGridPanel({
    required this.monthTitle,
    required this.cells,
    required this.theme,
    required this.layoutScale,
  });

  final String monthTitle;
  final List<MonthGridCell> cells;
  final ThemeData theme;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          monthTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12 * s),
        Row(
          children: _weekdayLabels
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: 8 * s),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6 * s,
              mainAxisSpacing: 6 * s,
            ),
            itemCount: cells.length,
            itemBuilder: (context, index) {
              return _MonthDayCell(
                cell: cells[index],
                theme: theme,
                layoutScale: s,
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
    required this.cell,
    required this.theme,
    required this.layoutScale,
  });

  final MonthGridCell cell;
  final ThemeData theme;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final fg = cell.isToday
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface.withValues(
            alpha: cell.inCurrentMonth ? 1 : 0.38,
          );
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: cell.isToday
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8 * s),
        border: cell.isToday
            ? Border.all(
                color: theme.colorScheme.primary,
                width: 2 * s,
              )
            : null,
      ),
      child: Center(
        child: Text(
          '${cell.day}',
          style: theme.textTheme.titleSmall?.copyWith(color: fg),
        ),
      ),
    );
    return box;
  }
}
