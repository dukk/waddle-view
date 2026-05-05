import 'package:flutter/material.dart';

/// Logical pixels scale for TV dashboard content (from [DisplayViewportLayout.scale]).
///
/// Defaults to `1.0` when no scope is present (e.g. isolated widget tests).
class DashboardViewportScope extends InheritedWidget {
  const DashboardViewportScope({
    super.key,
    required this.scale,
    required super.child,
  });

  final double scale;

  static double scaleOf(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<DashboardViewportScope>();
    return inherited?.scale ?? 1.0;
  }

  @override
  bool updateShouldNotify(DashboardViewportScope oldWidget) {
    return oldWidget.scale != scale;
  }
}
