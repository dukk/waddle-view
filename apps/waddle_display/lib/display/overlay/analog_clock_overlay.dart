import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/display_overlay_analog_clock_settings.dart';

import '../../clock.dart';
import '../dashboard_viewport_scope.dart';
import '../screens/clock/analog_clock_slide_widget.dart';
import 'clock_overlay_layout.dart';

/// Renders one or more positioned analog clocks (overlay type `analog_clock`).
class AnalogClockOverlay extends StatelessWidget {
  const AnalogClockOverlay({
    super.key,
    required this.settingsList,
    required this.theme,
    this.clock = const SystemClock(),
  });

  final List<AnalogClockOverlaySettings> settingsList;
  final ThemeData theme;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    if (settingsList.isEmpty) {
      return const SizedBox.shrink();
    }
    final viewportScale = DashboardViewportScope.scaleOf(context);
    return ClockOverlayLayout(
      placements: settingsList.map((s) => s.placement).toList(),
      childBuilder: (context, index, placement, blockWidth) {
        final settings = settingsList[index];
        final dialSize = viewportScale > 0
            ? blockWidth / viewportScale
            : blockWidth;
        final spec = ParsedWidgetSpec(
          type: 'analog_clock',
          slot: 'main',
          config: settings.clockConfigMap(),
        );
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: AnalogClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: clock,
            dialSize: dialSize,
          ),
        );
      },
    );
  }
}
