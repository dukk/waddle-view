import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/display_viewport.dart';

void main() {
  test('DisplayViewportConfig defaults to 16:9 horizontal', () {
    const config = DisplayViewportConfig();

    expect(config.aspectRatio, DashboardAspectRatio.widescreen16x9);
    expect(config.orientation, DashboardOrientation.horizontal);
    expect(config.targetAspectRatio, closeTo(16 / 9, 0.0001));
  });

  test('DisplayViewportConfig vertical flips the target aspect ratio', () {
    const config = DisplayViewportConfig(
      aspectRatio: DashboardAspectRatio.standard4x3,
      orientation: DashboardOrientation.vertical,
    );

    expect(config.targetAspectRatio, closeTo(3 / 4, 0.0001));
  });

  test('resolveDisplayViewportLayout fits 4:3 viewport in 16:9 screen', () {
    final layout = resolveDisplayViewportLayout(
      availableSize: Size(1920, 1080),
      config: DisplayViewportConfig(
        aspectRatio: DashboardAspectRatio.standard4x3,
      ),
    );

    expect(layout.viewportSize.width, closeTo(1440, 0.1));
    expect(layout.viewportSize.height, closeTo(1080, 0.1));
    expect(layout.viewportInsets.left, closeTo(240, 0.1));
    expect(layout.viewportInsets.top, 0);
  });

  test('resolveDisplayViewportLayout fits vertical 16:9 on 16:9 display', () {
    final layout = resolveDisplayViewportLayout(
      availableSize: Size(1920, 1080),
      config: DisplayViewportConfig(
        orientation: DashboardOrientation.vertical,
      ),
    );

    expect(layout.viewportSize.width, closeTo(607.5, 0.1));
    expect(layout.viewportSize.height, closeTo(1080, 0.1));
    expect(layout.viewportInsets.left, closeTo(656.25, 0.1));
    expect(layout.viewportInsets.top, 0);
  });
}
