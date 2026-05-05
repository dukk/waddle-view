import 'package:flutter/material.dart';

import '../theme/tv_overscan.dart';

/// TV shell: flexible body + bottom ticker region.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.overscan,
    required this.body,
    required this.ticker,
  });

  final TvOverscanInsets overscan;
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
              Expanded(child: body),
              const SizedBox(height: 8),
              SizedBox(height: 96, child: ticker),
            ],
          ),
        );
      },
    );
  }
}
