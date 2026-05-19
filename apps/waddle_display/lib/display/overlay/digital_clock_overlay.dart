import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/display_overlay_digital_clock_settings.dart';

import '../../clock.dart';
import '../screens/clock/digital_clock_slide_widget.dart';
import 'clock_overlay_layout.dart';

/// Renders one or more positioned digital clocks (overlay type `digital_clock`).
class DigitalClockOverlay extends StatelessWidget {
  const DigitalClockOverlay({
    super.key,
    required this.settingsList,
    required this.theme,
    this.clock = const SystemClock(),
  });

  final List<DigitalClockOverlaySettings> settingsList;
  final ThemeData theme;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    if (settingsList.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClockOverlayLayout(
      placements: settingsList.map((s) => s.placement).toList(),
      childBuilder: (context, index, placement, blockWidth) {
        final settings = settingsList[index];
        final spec = ParsedWidgetSpec(
          type: 'digital_clock',
          slot: 'main',
          config: settings.clockConfigMap(),
        );
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: DigitalClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        );
      },
    );
  }
}
