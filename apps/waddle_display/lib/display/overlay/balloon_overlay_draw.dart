import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, StrokeCap;

import 'package:flutter/material.dart' show Colors;
import 'package:waddle_shared/persistence/display_overlay_floating_balloons_settings.dart';

/// Parses `#RRGGBB` or `#RRGGBBAA` into a [Color], or `null` when invalid.
Color? parseBalloonOverlayHexColor(String hex) {
  final h = hex.trim();
  if (h.length == 7 && h.startsWith('#')) {
    final v = int.tryParse(h.substring(1), radix: 16);
    if (v == null) {
      return null;
    }
    return Color(0xFF000000 | v);
  }
  if (h.length == 9 && h.startsWith('#')) {
    final v = int.tryParse(h.substring(1), radix: 16);
    if (v == null) {
      return null;
    }
    return Color(v);
  }
  return null;
}

/// Builds a teardrop balloon body centered at [center] with vertical extent [size].
Path buildBalloonBodyPath(Offset center, double size) {
  final w = size * 0.72;
  final h = size;
  final path = Path();
  path.moveTo(center.dx, center.dy - h * 0.48);
  path.cubicTo(
    center.dx + w * 0.55,
    center.dy - h * 0.42,
    center.dx + w * 0.52,
    center.dy + h * 0.08,
    center.dx + w * 0.18,
    center.dy + h * 0.36,
  );
  path.lineTo(center.dx, center.dy + h * 0.44);
  path.lineTo(center.dx - w * 0.18, center.dy + h * 0.36);
  path.cubicTo(
    center.dx - w * 0.52,
    center.dy + h * 0.08,
    center.dx - w * 0.55,
    center.dy - h * 0.42,
    center.dx,
    center.dy - h * 0.48,
  );
  path.close();
  return path;
}

/// Small knot where the string attaches.
Path buildBalloonKnotPath(Offset center, double size) {
  final w = size * 0.14;
  final top = center.dy + size * 0.42;
  final path = Path();
  path.moveTo(center.dx - w, top);
  path.lineTo(center.dx + w, top);
  path.lineTo(center.dx, top + size * 0.08);
  path.close();
  return path;
}

/// Curved highlight stroke on the balloon body.
void paintBalloonHighlight(
  Canvas canvas,
  Offset center,
  double size,
) {
  final paint = Paint()
    ..color = Colors.white.withValues(alpha: 0.58)
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.045
    ..strokeCap = StrokeCap.round;
  final path = Path();
  path.moveTo(center.dx - size * 0.12, center.dy - size * 0.28);
  path.quadraticBezierTo(
    center.dx - size * 0.22,
    center.dy - size * 0.08,
    center.dx - size * 0.08,
    center.dy + size * 0.02,
  );
  canvas.drawPath(path, paint);
}

/// Animated wavy string from [knot] down to [anchor].
void paintBalloonString(
  Canvas canvas,
  Offset knot,
  Offset anchor,
  double timeSec,
  double phase, {
  required double opacity,
}) {
  final paint = Paint()
    ..color = Colors.black.withValues(alpha: 0.72 * opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;

  final path = Path()..moveTo(knot.dx, knot.dy);
  final midY = (knot.dy + anchor.dy) * 0.5;
  final sway = math.sin(timeSec * 2.8 + phase) * 10;
  final sway2 = math.sin(timeSec * 3.6 + phase + 1.2) * 8;
  path.cubicTo(
    knot.dx + sway,
    knot.dy + (midY - knot.dy) * 0.45,
    anchor.dx + sway2,
    midY,
    anchor.dx,
    anchor.dy,
  );
  canvas.drawPath(path, paint);
}

/// Paints one filled balloon with knot, highlight, and string.
void paintBalloon({
  required Canvas canvas,
  required Offset center,
  required double size,
  required Color fill,
  required double layerOpacity,
  required Offset stringAnchor,
  required double timeSec,
  required double stringPhase,
}) {
  final body = buildBalloonBodyPath(center, size);
  final fillPaint = Paint()
    ..color = fill.withValues(alpha: layerOpacity)
    ..style = PaintingStyle.fill;
  canvas.drawPath(body, fillPaint);

  final knotCenter = Offset(center.dx, center.dy + size * 0.44);
  canvas.drawPath(
    buildBalloonKnotPath(center, size),
    fillPaint,
  );

  paintBalloonHighlight(canvas, center, size);

  final knot = Offset(knotCenter.dx, knotCenter.dy + size * 0.06);
  paintBalloonString(
    canvas,
    knot,
    stringAnchor,
    timeSec,
    stringPhase,
    opacity: layerOpacity,
  );
}

/// Paints a full cluster (or single balloon) at [clusterCenter].
void paintBalloonCluster({
  required Canvas canvas,
  required Offset clusterCenter,
  required double balloonSize,
  required List<Color> colors,
  required List<BalloonClusterOffset> layouts,
  required List<double> sizeFactors,
  required List<double> stringPhases,
  required double layerOpacity,
  required double timeSec,
  required double stringDrop,
}) {
  final anchor = Offset(clusterCenter.dx, clusterCenter.dy + stringDrop);
  for (var i = 0; i < colors.length; i++) {
    final layout = layouts[i];
    final scale = i < sizeFactors.length ? sizeFactors[i] : 1.0;
    final size = balloonSize * scale;
    final center = Offset(
      clusterCenter.dx + layout.dx * balloonSize,
      clusterCenter.dy + layout.dy * balloonSize,
    );
    paintBalloon(
      canvas: canvas,
      center: center,
      size: size,
      fill: colors[i],
      layerOpacity: layerOpacity,
      stringAnchor: anchor,
      timeSec: timeSec,
      stringPhase: i < stringPhases.length ? stringPhases[i] : 0,
    );
  }
}

/// Topmost Y of balloons in a cluster.
double balloonClusterTopY({
  required double clusterCenterY,
  required double balloonSize,
  required List<BalloonClusterOffset> layouts,
  required List<double> sizeFactors,
}) {
  var top = clusterCenterY;
  for (var i = 0; i < layouts.length; i++) {
    final scale = i < sizeFactors.length ? sizeFactors[i] : 1.0;
    final size = balloonSize * scale;
    final centerY = clusterCenterY + layouts[i].dy * balloonSize;
    top = math.min(top, centerY - size * 0.48);
  }
  return top;
}

/// Lowest Y of a cluster including balloon bodies and string anchor (for pruning).
double balloonClusterBottomY({
  required double clusterCenterY,
  required double balloonSize,
  required List<BalloonClusterOffset> layouts,
  required List<double> sizeFactors,
  required double stringDrop,
}) {
  var bottom = clusterCenterY + stringDrop;
  for (var i = 0; i < layouts.length; i++) {
    final scale = i < sizeFactors.length ? sizeFactors[i] : 1.0;
    final size = balloonSize * scale;
    final centerY = clusterCenterY + layouts[i].dy * balloonSize;
    bottom = math.max(bottom, centerY + size * 0.52);
  }
  return bottom;
}

/// Vertical extent below [clusterCenter] including strings.
double balloonClusterStringDropFromLayouts(
  List<BalloonClusterOffset> layouts,
  double balloonSize,
  List<double> sizeFactors,
) {
  var maxBelow = 0.95;
  for (var i = 0; i < layouts.length; i++) {
    final scale = i < sizeFactors.length ? sizeFactors[i] : 1.0;
    final size = balloonSize * scale;
    maxBelow = math.max(
      maxBelow,
      layouts[i].dy + size / balloonSize * 0.52,
    );
  }
  return balloonSize * (maxBelow + 0.38);
}
