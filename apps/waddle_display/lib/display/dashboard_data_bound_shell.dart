import 'package:flutter/material.dart';

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
  });

  final TvOverscanInsets overscan;
  final DisplayViewportConfig viewportConfig;
  final Widget body;
  final Widget ticker;

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      overscan: overscan,
      viewportConfig: viewportConfig,
      body: body,
      ticker: ticker,
    );
  }
}
