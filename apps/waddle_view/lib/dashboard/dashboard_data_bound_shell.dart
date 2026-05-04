import 'package:flutter/material.dart';

import '../theme/tv_overscan.dart';
import 'dashboard_data_access.dart';
import 'dashboard_shell.dart';
import 'dashboard_slot_descriptor.dart';

/// [DashboardShell] whose header title is driven by [DashboardDataAccess].
class DashboardDataBoundShell extends StatelessWidget {
  const DashboardDataBoundShell({
    super.key,
    required this.data,
    required this.overscan,
    required this.slots,
    required this.body,
    required this.ticker,
    this.headerFallback = 'Waddle View',
  });

  final DashboardDataAccess data;
  final TvOverscanInsets overscan;
  final List<DashboardSlotDescriptor> slots;
  final Widget body;
  final Widget ticker;
  final String headerFallback;

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      overscan: overscan,
      slots: slots,
      header: StreamBuilder<String?>(
        stream: data.watchHeaderTitle(),
        builder: (context, snap) {
          return Text(
            snap.data ?? headerFallback,
            style: Theme.of(context).textTheme.headlineMedium,
          );
        },
      ),
      body: body,
      ticker: ticker,
    );
  }
}
