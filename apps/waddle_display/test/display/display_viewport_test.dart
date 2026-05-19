import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/display_viewport.dart';
import 'package:waddle_shared/display/display_viewport_reserve.dart';

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

  test('resolveViewportReserveInsets uses width for horizontal sides', () {
    const reserve = DisplayViewportReservePct(top: 10, right: 20, bottom: 5, left: 15);
    final insets = resolveViewportReserveInsets(const Size(1000, 800), reserve);

    expect(insets.top, closeTo(80, 0.01));
    expect(insets.bottom, closeTo(40, 0.01));
    expect(insets.left, closeTo(150, 0.01));
    expect(insets.right, closeTo(200, 0.01));
  });
}
