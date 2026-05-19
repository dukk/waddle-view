import 'package:flutter/material.dart';

import 'package:waddle_shared/display/display_viewport_reserve.dart';

import 'display_viewport.dart';
import '../theme/tv_overscan.dart';
import 'dashboard_shell.dart';

/// [DashboardShell] composition used by the app root.
class DashboardDataBoundShell extends StatelessWidget {
  const DashboardDataBoundShell({
    super.key,
    required this.overscan,
    this.viewportConfig = const DisplayViewportConfig(),
    required this.body,
    required this.ticker,
    this.showTicker = true,
    this.viewportReserve = DisplayViewportReservePct.zero,
  });

  final TvOverscanInsets overscan;
  final DisplayViewportConfig viewportConfig;
  final Widget body;
  final Widget ticker;
  final bool showTicker;
  final DisplayViewportReservePct viewportReserve;

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      overscan: overscan,
      viewportConfig: viewportConfig,
      body: body,
      ticker: ticker,
      showTicker: showTicker,
      viewportReserve: viewportReserve,
    );
  }
}
