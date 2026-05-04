import 'package:flutter/material.dart';

import '../theme/tv_overscan.dart';
import 'dashboard_slot_descriptor.dart';

/// TV shell: header + flexible body + bottom ticker region.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.overscan,
    required this.slots,
    required this.header,
    required this.body,
    required this.ticker,
  });

  final TvOverscanInsets overscan;
  final List<DashboardSlotDescriptor> slots;
  final Widget header;
  final Widget body;
  final Widget ticker;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = overscan.resolve(c.biggest);
        return Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 12),
              Expanded(child: body),
              const SizedBox(height: 8),
              SizedBox(height: 96, child: ticker),
              if (slots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    slots.map((e) => e.label).join(' · '),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.white54),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
