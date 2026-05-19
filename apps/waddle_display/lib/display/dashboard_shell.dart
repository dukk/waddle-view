import 'package:flutter/material.dart';

import 'dashboard_viewport_scope.dart';
import 'package:waddle_shared/display/display_viewport_reserve.dart';

import 'display_viewport.dart';
import '../theme/ticker_marquee_style.dart';
import '../theme/tv_overscan.dart';

/// TV shell: flexible body + bottom ticker region.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
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
    return LayoutBuilder(
      builder: (context, c) {
        final outerPadding = overscan.resolve(c.biggest);
        final overscanWidth = c.biggest.width - outerPadding.horizontal;
        final overscanHeight = c.biggest.height - outerPadding.vertical;
        final availableViewport = Size(
          overscanWidth < 0 ? 0 : overscanWidth,
          overscanHeight < 0 ? 0 : overscanHeight,
        );
        final viewport = resolveDisplayViewportLayout(
          availableSize: availableViewport,
          config: viewportConfig,
        );
        final metrics = resolveDashboardShellScaleMetrics(
          viewportScale: viewport.scale,
        );
        final reserveInsets = resolveViewportReserveInsets(
          viewport.viewportSize,
          viewportReserve,
        );
        final innerPadding = EdgeInsets.all(metrics.contentPadding) + reserveInsets;
        return Padding(
          padding: outerPadding,
          child: Padding(
            padding: viewport.viewportInsets,
            child: SizedBox(
              width: viewport.viewportSize.width,
              height: viewport.viewportSize.height,
              child: Padding(
                padding: innerPadding,
                child: Builder(
                  builder: (context) {
                    final parentTheme = Theme.of(context);
                    final scaledText = parentTheme.textTheme.apply(
                      fontSizeFactor: viewport.scale,
                      bodyColor: parentTheme.colorScheme.onSurface,
                      displayColor: parentTheme.colorScheme.onSurface,
                    );
                    final tickerScaled = TickerMarqueeStyle.fromTvTheme(
                      scaledText,
                      parentTheme.colorScheme,
                    );
                    final scaledTheme = parentTheme.copyWith(
                      textTheme: scaledText,
                      extensions: <ThemeExtension<dynamic>>[tickerScaled],
                    );
                    return Theme(
                      data: scaledTheme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: DashboardViewportScope(
                              scale: viewport.scale,
                              child: body,
                            ),
                          ),
                          if (showTicker) ...[
                            SizedBox(height: metrics.gapHeight),
                            SizedBox(
                              height: metrics.tickerHeight,
                              child: DashboardViewportScope(
                                scale: viewport.scale,
                                child: ticker,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
