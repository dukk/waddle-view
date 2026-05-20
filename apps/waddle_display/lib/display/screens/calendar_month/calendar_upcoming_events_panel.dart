import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content_category_material_icon.dart';
import 'calendar_upcoming_layout.dart';

/// Upcoming events list (calendar_month slide right column and overlay).
class CalendarUpcomingEventsPanel extends StatelessWidget {
  const CalendarUpcomingEventsPanel({
    super.key,
    required this.snapshot,
    required this.listItems,
    required this.hasUpcomingRows,
    required this.theme,
    required this.layoutScale,
    required this.layoutCompact,
    required this.timeColumnWidth,
    this.forOverlay = false,
  });

  final AsyncSnapshot<CalendarMonthStreamBundle> snapshot;
  final List<CalendarUpcomingListItem> listItems;
  final bool hasUpcomingRows;
  final ThemeData theme;
  final double layoutScale;
  final bool layoutCompact;
  final double timeColumnWidth;
  final bool forOverlay;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final headingStyle =
        (layoutCompact
                ? theme.textTheme.titleMedium
                : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w600);
    final headingGap = (layoutCompact ? 6.0 : 12.0) * s;
    final timeWidth = timeColumnWidth;
    final iconCol = 28.0 * s;

    Widget listBody;
    if (snapshot.hasError) {
      listBody = Center(
        child: Text(
          'Error loading events.',
          style: muted,
          textAlign: TextAlign.center,
        ),
      );
    } else if (!hasUpcomingRows) {
      listBody = Center(
        child: Text(
          'No upcoming events.',
          style: muted,
          textAlign: TextAlign.center,
        ),
      );
    } else {
      listBody = ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: forOverlay,
        physics: forOverlay
            ? const NeverScrollableScrollPhysics()
            : null,
        itemCount: listItems.length,
        separatorBuilder: (context, index) => SizedBox(height: 12 * s),
        itemBuilder: (context, i) => _buildListRow(context, i, s, iconCol, timeWidth),
      );
    }

    if (forOverlay) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Upcoming events', style: headingStyle),
          SizedBox(height: headingGap),
          listBody,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Upcoming events', style: headingStyle),
        SizedBox(height: headingGap),
        Expanded(child: listBody),
      ],
    );
  }

  Widget _buildListRow(
    BuildContext context,
    int i,
    double s,
    double iconCol,
    double timeWidth,
  ) {
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
    final cats = slideRow.categories;
    final hasIcon = cats.isNotEmpty &&
        (slideRow.categoryIconBytes.any((b) => b != null) ||
            cats.any(
              (c) => c.materialIconName?.trim().isNotEmpty ?? false,
            ));
    final categoryIconsWidth = hasIcon
        ? iconCol * cats.length.clamp(1, 4) +
            2 * s * (cats.length.clamp(1, 4) - 1)
        : 0.0;
    final markerColor = calendarEventMarkerAccent(
      theme.colorScheme,
      e,
      categoryIds: cats.map((c) => c.id).toList(),
    );
    final listDotD = math.max(8.0, 11.0 * s);
    final listSq = math.max(9.0, 12.0 * s);
    final markerExtent = e.allDay ? listSq : listDotD;
    final upcomingMarkerCol = math.max(16.0 * s, markerExtent + 3 * s);
    final titleBlockStartPad =
        upcomingMarkerCol + 8 * s + (hasIcon ? categoryIconsWidth + 8 * s : 0);
    final iconColor = theme.colorScheme.onSurfaceVariant;
    final row = Row(
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
                        width: categoryIconsWidth,
                        height: iconCol,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var ci = 0; ci < cats.length && ci < 4; ci++) ...[
                              if (ci > 0) SizedBox(width: 2 * s),
                              SizedBox(
                                width: iconCol,
                                height: iconCol,
                                child: slideRow.categoryIconBytes.length > ci &&
                                        slideRow.categoryIconBytes[ci] != null
                                    ? Image.memory(
                                        slideRow.categoryIconBytes[ci]!,
                                        width: iconCol,
                                        height: iconCol,
                                        fit: BoxFit.contain,
                                      )
                                    : Icon(
                                        contentCategoryMaterialIcon(
                                          cats[ci].materialIconName,
                                        ),
                                        size: iconCol,
                                        color: iconColor,
                                      ),
                              ),
                            ],
                          ],
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
                    padding: EdgeInsets.only(left: titleBlockStartPad),
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
      );
    return Padding(
      padding: EdgeInsets.only(left: 8 * s),
      child: forOverlay ? ClipRect(child: row) : row,
    );
  }
}
