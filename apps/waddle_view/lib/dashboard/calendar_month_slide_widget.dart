import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../clock.dart';
import '../curator/screen_layout_parse.dart';
import '../persistence/database.dart';
import 'calendar_month_grid.dart';
import 'dashboard_viewport_scope.dart';

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

/// Month grid and upcoming events in two surfaced panels with consistent spacing.
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

  /// Flex for the left column (compact calendar). Config: `leftFlex`.
  int get _calendarFlex {
    final v = widget.spec.config['leftFlex'];
    if (v is int && v > 0) {
      return v;
    }
    if (v is num && v.toInt() > 0) {
      return v.toInt();
    }
    return 2;
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
        final layoutCompact = height < 240;

        return SizedBox(
          width: w,
          height: height,
          child: StreamBuilder<List<CalendarEvent>>(
            key: ValueKey<int>(_startMsBoundary),
            stream: (widget.db.select(widget.db.calendarEvents)
                  ..where(
                    (t) => t.startMs.isBiggerOrEqualValue(
                      DateTime.fromMillisecondsSinceEpoch(_startMsBoundary),
                    ),
                  )
                  ..orderBy([(t) => OrderingTerm.asc(t.startMs)]))
                .watch(),
            builder: (context, snapshot) {
              final events = snapshot.data ?? [];
              final now = widget.clock.now().toLocal();
              final monthAnchor = DateTime(now.year, now.month, now.day);
              final cells = buildMonthGridCells(monthAnchor, now);
              final monthTitle =
                  '${_monthNamesShort[monthAnchor.month - 1]} ${monthAnchor.year}';

              final gap = (layoutCompact ? 12.0 : 20.0) * s;
              final outerPad = EdgeInsets.symmetric(
                horizontal: 24.0 * s,
                vertical: (layoutCompact ? 8.0 : 16.0) * s,
              );

              return Padding(
                padding: outerPad,
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
                          events: events,
                          theme: widget.theme,
                          layoutScale: s,
                          layoutCompact: layoutCompact,
                        ),
                      ),
                    ),
                  ],
                ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12 * s),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: child,
      ),
    );
  }
}

class _UpcomingEventsPanel extends StatelessWidget {
  const _UpcomingEventsPanel({
    required this.snapshot,
    required this.events,
    required this.theme,
    required this.layoutScale,
    required this.layoutCompact,
  });

  final AsyncSnapshot<List<CalendarEvent>> snapshot;
  final List<CalendarEvent> events;
  final ThemeData theme;
  final double layoutScale;
  final bool layoutCompact;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final headingStyle = (layoutCompact
            ? theme.textTheme.titleMedium
            : theme.textTheme.titleLarge)
        ?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final headingGap = (layoutCompact ? 6.0 : 12.0) * s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upcoming events',
          style: headingStyle,
        ),
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
        else if (events.isEmpty)
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
              itemCount: events.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: 12 * s),
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
                    SizedBox(height: 2 * s),
                    Text(
                      e.title,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (loc != null && loc.isNotEmpty) ...[
                      SizedBox(height: 4 * s),
                      Text(
                        loc,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
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
    required this.theme,
    required this.layoutScale,
    required this.layoutCompact,
  });

  final String monthTitle;
  final List<MonthGridCell> cells;
  final ThemeData theme;
  final double layoutScale;
  final bool layoutCompact;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final weekdayStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final headingStyle = (layoutCompact
            ? theme.textTheme.titleMedium
            : theme.textTheme.titleLarge)
        ?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final titleGap = (layoutCompact ? 6.0 : 12.0) * s;
    final weekdayGridGap = (layoutCompact ? 4.0 : 8.0) * s;
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
        Row(
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
        SizedBox(height: weekdayGridGap),
        Expanded(
          child: LayoutBuilder(
            builder: (context, gridConstraints) {
              final rows = math.max(1, cells.length ~/ 7);
              final spacing = 6 * s;
              final usableW = gridConstraints.maxWidth;
              final usableH = gridConstraints.maxHeight;
              final cellW = math.max(
                1.0,
                (usableW - 6 * spacing) / 7,
              );
              final cellH = math.max(
                1.0,
                (usableH - (rows - 1) * spacing) / rows,
              );
              final aspect = cellW / cellH;
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: aspect,
                ),
                itemCount: cells.length,
                itemBuilder: (context, index) {
                  return _MonthDayCell(
                    cell: cells[index],
                    theme: theme,
                    layoutScale: s,
                  );
                },
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
    final muted = theme.colorScheme.onSurface.withValues(
      alpha: cell.inCurrentMonth ? 1 : 0.38,
    );
    final fg = cell.isToday
        ? theme.colorScheme.onPrimaryContainer
        : muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cell.isToday
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
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
          style: theme.textTheme.bodyMedium?.copyWith(
            color: fg,
            fontWeight: cell.isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
