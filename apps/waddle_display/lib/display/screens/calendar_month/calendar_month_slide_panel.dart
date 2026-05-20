import 'package:flutter/material.dart';

/// Surfaced panel padding for calendar month slide and overlay blocks.
class CalendarMonthSlidePanel extends StatelessWidget {
  const CalendarMonthSlidePanel({
    super.key,
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
