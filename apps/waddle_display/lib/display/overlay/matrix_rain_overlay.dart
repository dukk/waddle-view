import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_matrix_rain_settings.dart';

/// One full vertical drift cycle at [fallSpeed] `1.0` is about 5 seconds.
Duration matrixRainCycleDuration(double fallSpeed) {
  final clamped = fallSpeed.clamp(
    kMatrixRainFallSpeedMin,
    kMatrixRainFallSpeedMax,
  );
  final s = (5.0 / clamped).clamp(2.5, 120.0);
  return Duration(milliseconds: (s * 1000).round());
}

const String _kMatrixCharset =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    '\u30A2\u30A4\u30A6\u30A8\u30AA\u30AB\u30AD\u30AF\u30B1\u30B3\u30B5'
    '\u30B7\u30B9\u30BB\u30BD\u30BF\u30C1\u30C3\u30C5\u30C7\u30C9\u30CA'
    '\u30CB\u30CC\u30CD\u30CE\u30CF\u30D2\u30D5\u30D8\u30DB\u30DE\u30DF'
    '\u30E0\u30E1\u30E2\u30E3\u30E4\u30E5\u30E6\u30E7\u30E8\u30E9\u30EA'
    '\u30EB\u30EC\u30ED\u30EF\u30F2\u30F3';

/// Translucent Matrix-style falling character columns (no background fill).
class MatrixRainOverlay extends StatefulWidget {
  const MatrixRainOverlay({
    super.key,
    required this.settings,
  });

  final MatrixRainScheduleSettings settings;

  @override
  State<MatrixRainOverlay> createState() => _MatrixRainOverlayState();
}

class _MatrixRainOverlayState extends State<MatrixRainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: matrixRainCycleDuration(widget.settings.fallSpeed),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MatrixRainOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.fallSpeed != widget.settings.fallSpeed) {
      _ctrl.duration = matrixRainCycleDuration(widget.settings.fallSpeed);
      _ctrl
        ..reset()
        ..repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            return CustomPaint(
              key: const Key('matrix_rain_custom_paint'),
              size: Size(c.maxWidth, c.maxHeight),
              painter: _MatrixRainPainter(
                settings: widget.settings,
                progress: (_ctrl.value * 104729) % 1.0,
              ),
            );
          },
        );
      },
    );
  }
}

class _MatrixRainPainter extends CustomPainter {
  _MatrixRainPainter({
    required this.settings,
    required this.progress,
  });

  final MatrixRainScheduleSettings settings;
  final double progress;

  static const Color _brightGreen = Color(0xFF00FF41);
  static const Color _midGreen = Color(0xFF00CC33);
  static const Color _dimGreen = Color(0xFF006622);

  @override
  void paint(Canvas canvas, Size size) {
    const columnWidth = 14.0;
    const rowHeight = 16.0;
    final nCols = (size.width / columnWidth).floor().clamp(1, 80);
    final charset = _kMatrixCharset;
    final maxOpacity = settings.opacity;

    for (var col = 0; col < nCols; col++) {
      final colRand = math.Random(col * 7919 + 31);
      final x = col * columnWidth + columnWidth * 0.5;
      final trailLen = 8 + colRand.nextInt(7);
      final colPhase = (progress + colRand.nextDouble() * 0.37) % 1.0;
      final headRow =
          ((colPhase * (size.height / rowHeight + trailLen)) - trailLen)
              .floorToDouble();

      for (var t = 0; t < trailLen; t++) {
        final row = headRow - t;
        if (row < -1 || row > size.height / rowHeight + 1) {
          continue;
        }
        final y = row * rowHeight + rowHeight * 0.5;
        final trailFactor = t == 0 ? 1.0 : (1.0 - t / trailLen).clamp(0.15, 1.0);
        final baseColor = t == 0
            ? _brightGreen
            : (t < 3 ? _midGreen : _dimGreen);
        final alpha = (maxOpacity * trailFactor * (t == 0 ? 1.0 : 0.55 + trailFactor * 0.35))
            .clamp(0.02, maxOpacity);
        final charIndex = (colRand.nextInt(charset.length) + t * 17 + col) %
            charset.length;
        final glyph = charset[charIndex];

        final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: glyph,
            style: TextStyle(
              color: baseColor.withValues(alpha: alpha),
              fontSize: 13,
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Courier', 'Courier New'],
              height: 1,
            ),
          ),
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixRainPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.settings.opacity != settings.opacity ||
      oldDelegate.settings.fallSpeed != settings.fallSpeed;
}
