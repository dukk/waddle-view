import 'dart:math' as math;

import 'package:flutter/material.dart';

enum DashboardAspectRatio {
  standard4x3(4 / 3),
  widescreen16x9(16 / 9),
  ultrawide21x9(21 / 9);

  const DashboardAspectRatio(this.horizontalRatio);
  final double horizontalRatio;
}

enum DashboardOrientation { horizontal, vertical }

class DisplayViewportConfig {
  const DisplayViewportConfig({
    this.aspectRatio = DashboardAspectRatio.widescreen16x9,
    this.orientation = DashboardOrientation.horizontal,
  });

  final DashboardAspectRatio aspectRatio;
  final DashboardOrientation orientation;

  double get targetAspectRatio {
    final ratio = aspectRatio.horizontalRatio;
    if (orientation == DashboardOrientation.vertical) {
      return 1 / ratio;
    }
    return ratio;
  }
}

class DisplayViewportLayout {
  const DisplayViewportLayout({
    required this.viewportSize,
    required this.viewportInsets,
    required this.scale,
  });

  final Size viewportSize;
  final EdgeInsets viewportInsets;
  final double scale;
}

class DashboardShellScaleMetrics {
  const DashboardShellScaleMetrics({
    required this.contentPadding,
    required this.gapHeight,
    required this.tickerHeight,
  });

  final double contentPadding;
  final double gapHeight;
  final double tickerHeight;
}

DisplayViewportLayout resolveDisplayViewportLayout({
  required Size availableSize,
  required DisplayViewportConfig config,
}) {
  final availableWidth = availableSize.width <= 0 ? 0.0 : availableSize.width;
  final availableHeight = availableSize.height <= 0 ? 0.0 : availableSize.height;
  final targetRatio = config.targetAspectRatio;

  if (availableWidth == 0 || availableHeight == 0) {
    return const DisplayViewportLayout(
      viewportSize: Size.zero,
      viewportInsets: EdgeInsets.zero,
      scale: 0,
    );
  }

  final availableRatio = availableWidth / availableHeight;
  late final double viewportWidth;
  late final double viewportHeight;
  if (availableRatio > targetRatio) {
    viewportHeight = availableHeight;
    viewportWidth = viewportHeight * targetRatio;
  } else {
    viewportWidth = availableWidth;
    viewportHeight = viewportWidth / targetRatio;
  }

  final insetHorizontal = (availableWidth - viewportWidth) / 2;
  final insetVertical = (availableHeight - viewportHeight) / 2;
  final designSize = config.orientation == DashboardOrientation.horizontal
      ? const Size(1920, 1080)
      : const Size(1080, 1920);
  final scale = math.min(
    viewportWidth / designSize.width,
    viewportHeight / designSize.height,
  );
  return DisplayViewportLayout(
    viewportSize: Size(viewportWidth, viewportHeight),
    viewportInsets: EdgeInsets.symmetric(
      horizontal: insetHorizontal,
      vertical: insetVertical,
    ),
    scale: scale,
  );
}

DashboardShellScaleMetrics resolveDashboardShellScaleMetrics({
  required double viewportScale,
}) {
  return DashboardShellScaleMetrics(
    contentPadding: 24 * viewportScale,
    gapHeight: 8 * viewportScale,
    tickerHeight: 96 * viewportScale,
  );
}
