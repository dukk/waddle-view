import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_cloud_drift_settings.dart';

import 'balloon_overlay_draw.dart';

/// One full right-to-left crossing at normalized drift takes about 25 seconds.
const Duration kCloudDriftCycleDuration = Duration(seconds: 25);

/// Maps [density] (0.1–0.9) to an active cloud count for the painter.
int cloudDriftCloudCount(double density) {
  final clamped = density.clamp(
    kCloudDriftDensityMin,
    kCloudDriftDensityMax,
  );
  final t = (clamped - kCloudDriftDensityMin) /
      (kCloudDriftDensityMax - kCloudDriftDensityMin);
  return (4 + t * 24).round().clamp(4, 28);
}

/// Procedural clouds drifting from right to left (non-interactive).
class CloudDriftOverlay extends StatefulWidget {
  const CloudDriftOverlay({
    super.key,
    required this.settings,
  });

  final CloudDriftScheduleSettings settings;

  @override
  State<CloudDriftOverlay> createState() => _CloudDriftOverlayState();
}

class _CloudDriftOverlayState extends State<CloudDriftOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: kCloudDriftCycleDuration,
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            return CustomPaint(
              key: const Key('cloud_drift_custom_paint'),
              size: Size(c.maxWidth, c.maxHeight),
              painter: _CloudDriftPainter(
                settings: widget.settings,
                progress: _ctrl.value,
              ),
            );
          },
        );
      },
    );
  }
}

class _CloudDriftPainter extends CustomPainter {
  _CloudDriftPainter({
    required this.settings,
    required this.progress,
  });

  final CloudDriftScheduleSettings settings;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final base =
        parseBalloonOverlayHexColor(settings.colorHex) ??
        const Color(0xFFC8CDD3);
    final maxAlpha = settings.opacity.clamp(
      kCloudDriftOpacityMin,
      kCloudDriftOpacityMax,
    );
    final count = cloudDriftCloudCount(settings.density);
    final shortest = size.shortestSide;

    for (var i = 0; i < count; i++) {
      final rand = math.Random(i * 9829 + 41);
      final yJitter = (rand.nextDouble() - 0.5) * settings.scatter;
      final y =
          size.height * (0.28 + yJitter * 0.42 + rand.nextDouble() * 0.22);
      final scale =
          0.55 + rand.nextDouble() * 0.75 * (1 + settings.scatter * 0.35);
      final cloudWidth = shortest * 0.38 * scale;
      final phase = rand.nextDouble();
      final cycle = size.width + cloudWidth * 1.6;
      final x =
          size.width +
          cloudWidth * 0.4 -
          ((progress * cycle + phase * cycle) % cycle);

      _paintCloudUnit(
        canvas,
        center: Offset(x, y),
        width: cloudWidth,
        baseColor: base,
        maxAlpha: maxAlpha,
        cloudType: settings.cloudType,
        seed: i,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CloudDriftPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.settings.cloudType != settings.cloudType ||
      oldDelegate.settings.scatter != settings.scatter ||
      oldDelegate.settings.density != settings.density ||
      oldDelegate.settings.opacity != settings.opacity ||
      oldDelegate.settings.colorHex != settings.colorHex;
}

void _paintCloudUnit(
  Canvas canvas, {
  required Offset center,
  required double width,
  required Color baseColor,
  required double maxAlpha,
  required String cloudType,
  required int seed,
}) {
  switch (cloudType) {
    case 'cirrus':
      _paintCirrus(canvas, center, width, baseColor, maxAlpha, seed);
    case 'cumulus':
      _paintCumulus(canvas, center, width, baseColor, maxAlpha, seed);
    case 'stratocumulus':
      _paintStratocumulus(canvas, center, width, baseColor, maxAlpha, seed);
    case 'altostratus':
      _paintAltostratus(canvas, center, width, baseColor, maxAlpha, seed);
    case 'cirrostratus':
    default:
      _paintCirrostratus(canvas, center, width, baseColor, maxAlpha, seed);
  }
}

void _paintCirrostratus(
  Canvas canvas,
  Offset center,
  double width,
  Color base,
  double maxAlpha,
  int seed,
) {
  final rand = math.Random(seed * 31 + 7);
  final blur = ui.MaskFilter.blur(ui.BlurStyle.normal, width * 0.08);
  for (var layer = 0; layer < 3; layer++) {
    final w = width * (1.1 - layer * 0.12);
    final h = width * (0.12 + layer * 0.04);
    final dy = (layer - 1) * h * 0.35;
    final alpha = maxAlpha * (0.35 + layer * 0.12) * (0.85 + rand.nextDouble() * 0.15);
    final paint = Paint()
      ..color = base.withValues(alpha: alpha.clamp(0.04, maxAlpha))
      ..maskFilter = blur;
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, dy),
        width: w,
        height: h,
      ),
      paint,
    );
  }
}

void _paintCirrus(
  Canvas canvas,
  Offset center,
  double width,
  Color base,
  double maxAlpha,
  int seed,
) {
  final rand = math.Random(seed * 53 + 3);
  final paint = Paint()
    ..color = base.withValues(alpha: maxAlpha * 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * 0.025
    ..strokeCap = StrokeCap.round
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, width * 0.04);
  for (var streak = 0; streak < 4; streak++) {
    final path = Path();
    final startX = center.dx - width * 0.45 + streak * width * 0.12;
    final startY = center.dy + (rand.nextDouble() - 0.5) * width * 0.15;
    path.moveTo(startX, startY);
    path.quadraticBezierTo(
      startX + width * 0.2,
      startY - width * 0.08,
      startX + width * 0.5,
      startY + width * 0.05,
    );
    canvas.drawPath(path, paint);
  }
}

void _paintCumulus(
  Canvas canvas,
  Offset center,
  double width,
  Color base,
  double maxAlpha,
  int seed,
) {
  final rand = math.Random(seed * 67 + 11);
  final blur = ui.MaskFilter.blur(ui.BlurStyle.normal, width * 0.06);
  final lobes = 6 + rand.nextInt(3);
  for (var i = 0; i < lobes; i++) {
    final t = i / lobes;
    final r = width * (0.14 + rand.nextDouble() * 0.1);
    final ox = (t - 0.5) * width * 0.75 + (rand.nextDouble() - 0.5) * width * 0.08;
    final oy = (rand.nextDouble() - 0.5) * width * 0.12;
    final alpha = maxAlpha * (0.5 + rand.nextDouble() * 0.35);
    final paint = Paint()
      ..color = base.withValues(alpha: alpha.clamp(0.05, maxAlpha))
      ..maskFilter = blur;
    canvas.drawCircle(center + Offset(ox, oy), r, paint);
  }
}

void _paintStratocumulus(
  Canvas canvas,
  Offset center,
  double width,
  Color base,
  double maxAlpha,
  int seed,
) {
  final rand = math.Random(seed * 79 + 5);
  final blur = ui.MaskFilter.blur(ui.BlurStyle.normal, width * 0.05);
  final puffs = 8 + rand.nextInt(4);
  for (var i = 0; i < puffs; i++) {
    final t = i / (puffs - 1).clamp(1, 99);
    final r = width * (0.07 + rand.nextDouble() * 0.04);
    final ox = (t - 0.5) * width * 0.9;
    final oy = (rand.nextDouble() - 0.5) * width * 0.06;
    final alpha = maxAlpha * (0.4 + rand.nextDouble() * 0.3);
    final paint = Paint()
      ..color = base.withValues(alpha: alpha.clamp(0.04, maxAlpha))
      ..maskFilter = blur;
    canvas.drawCircle(center + Offset(ox, oy), r, paint);
  }
}

void _paintAltostratus(
  Canvas canvas,
  Offset center,
  double width,
  Color base,
  double maxAlpha,
  int seed,
) {
  final rand = math.Random(seed * 97 + 2);
  final rect = Rect.fromCenter(
    center: center,
    width: width * 1.15,
    height: width * 0.22,
  );
  final alpha = maxAlpha * (0.45 + rand.nextDouble() * 0.2);
  final paint = Paint()
    ..shader = ui.Gradient.linear(
      rect.topCenter,
      rect.bottomCenter,
      [
        base.withValues(alpha: 0),
        base.withValues(alpha: alpha.clamp(0.05, maxAlpha)),
        base.withValues(alpha: alpha.clamp(0.05, maxAlpha)),
        base.withValues(alpha: 0),
      ],
      [0, 0.25, 0.75, 1],
    )
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, width * 0.07);
  canvas.drawRect(rect, paint);
}
