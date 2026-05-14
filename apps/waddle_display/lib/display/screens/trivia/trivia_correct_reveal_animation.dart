import 'dart:math';

import 'package:flutter/material.dart';

/// Deterministic scalar in \[0, 1) for per-option ring variation (mirrors strike hash).
double _correctRevealDet01(int seed, int salt) {
  var x = seed ^ (salt * 0x9e3779b9);
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  return (x & 0xfffffff) / 0x10000000;
}

/// Layout JSON `correctRevealAnimation` values for the trivia widget.
enum TriviaCorrectRevealKind {
  /// Clean rounded-rectangle outline drawn progressively (default).
  smoothRing,

  /// Irregular loop following the tile outline (hand-drawn feel).
  wobblyRing,

  /// Two concentric outlines: outer ring first, then inner.
  doubleSweep,
}

/// Parses `correctRevealAnimation` from trivia widget `config` (case-insensitive;
/// accepts `smooth_ring`, `double-sweep`, etc.).
TriviaCorrectRevealKind parseTriviaCorrectRevealKind(
  Map<String, dynamic> config,
) {
  final raw = config['correctRevealAnimation'];
  if (raw is! String) {
    return TriviaCorrectRevealKind.smoothRing;
  }
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  switch (key) {
    case 'wobblyring':
    case 'wobbly':
    case 'handdrawnring':
    case 'handdrawn':
      return TriviaCorrectRevealKind.wobblyRing;
    case 'doublesweep':
    case 'double':
    case 'doublering':
      return TriviaCorrectRevealKind.doubleSweep;
    case 'smoothring':
    case 'smooth':
    default:
      return TriviaCorrectRevealKind.smoothRing;
  }
}

const int kTriviaCorrectRevealAnimationMs = 360;

/// Parses `correctRevealAnimationDurationMs` from trivia widget `config`.
/// Clamped to \[120, 3000]; invalid or missing uses [kTriviaCorrectRevealAnimationMs].
int parseCorrectRevealAnimationDurationMs(Map<String, dynamic> config) {
  final v = config['correctRevealAnimationDurationMs'];
  if (v is! num) {
    return kTriviaCorrectRevealAnimationMs;
  }
  final ms = v.round();
  if (ms < 120) {
    return 120;
  }
  if (ms > 3000) {
    return 3000;
  }
  return ms;
}

RRect _outlineRRect(
  Size size,
  double topRightRadius,
  double bottomRightRadius,
  double inset,
) {
  final w = size.width;
  final h = size.height;
  final tr = max(0.0, topRightRadius - inset);
  final br = max(0.0, bottomRightRadius - inset);
  return RRect.fromLTRBAndCorners(
    inset,
    inset,
    w - inset,
    h - inset,
    topLeft: Radius.zero,
    bottomLeft: Radius.zero,
    topRight: Radius.circular(tr),
    bottomRight: Radius.circular(br),
  );
}

void _drawPathProgress(
  Canvas canvas,
  Path fullPath,
  double legProgress,
  Paint paint,
) {
  if (legProgress <= 0) {
    return;
  }
  for (final metric in fullPath.computeMetrics()) {
    final len = metric.length;
    if (len < 1e-6) {
      return;
    }
    final end = len * legProgress.clamp(0.0, 1.0);
    canvas.drawPath(metric.extractPath(0.0, end), paint);
    return;
  }
}

Path _smoothOutlinePath(
  Size size,
  double topRightRadius,
  double bottomRightRadius,
  double inset,
) {
  return Path()
    ..addRRect(
      _outlineRRect(size, topRightRadius, bottomRightRadius, inset),
    );
}

Path _wobblyOutlinePath(
  Size size,
  double topRightRadius,
  double bottomRightRadius,
  double inset,
  int seed,
) {
  final rrect = _outlineRRect(size, topRightRadius, bottomRightRadius, inset);
  final base = Path()..addRRect(rrect);
  for (final metric in base.computeMetrics()) {
    final len = metric.length;
    if (len < 2) {
      return base;
    }
    final samples = max(40, min(140, (len / 4).round()));
    final wPath = Path();
    for (var i = 0; i < samples; i++) {
      final t = i / samples;
      final dist = len * t;
      final tan = metric.getTangentForOffset(dist);
      if (tan == null) {
        continue;
      }
      final p = tan.position;
      final v = tan.vector;
      final nx = -v.dy;
      final ny = v.dx;
      final amp =
          min(rrect.width, rrect.height) *
          (0.018 + 0.022 * _correctRevealDet01(seed, 1200 + i));
      final wobble =
          sin(t * pi * 2 * 2.7 + _correctRevealDet01(seed, 1300) * pi * 2) * amp;
      final x = p.dx + nx * wobble;
      final y = p.dy + ny * wobble;
      if (i == 0) {
        wPath.moveTo(x, y);
      } else {
        wPath.lineTo(x, y);
      }
    }
    wPath.close();
    return wPath;
  }
  return base;
}

/// Progressive ring around the correct trivia option (tile-shaped rounded rect).
class TriviaCorrectRevealPainter extends CustomPainter {
  TriviaCorrectRevealPainter({
    required this.kind,
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.styleSeed,
    required this.topRightRadius,
    required this.bottomRightRadius,
  });

  final TriviaCorrectRevealKind kind;
  final double progress;
  final Color color;
  final double strokeWidth;
  final int styleSeed;
  final double topRightRadius;
  final double bottomRightRadius;

  Paint get _paint => Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0 || progress <= 0) {
      return;
    }
    final inset = strokeWidth * 1.2;
    if (w <= 2 * inset || h <= 2 * inset) {
      return;
    }

    switch (kind) {
      case TriviaCorrectRevealKind.smoothRing:
        _paintSmooth(canvas, size, inset);
        return;
      case TriviaCorrectRevealKind.wobblyRing:
        _paintWobbly(canvas, size, inset);
        return;
      case TriviaCorrectRevealKind.doubleSweep:
        _paintDoubleSweep(canvas, size, inset);
        return;
    }
  }

  void _paintSmooth(Canvas canvas, Size size, double inset) {
    final path = _smoothOutlinePath(
      size,
      topRightRadius,
      bottomRightRadius,
      inset,
    );
    _drawPathProgress(canvas, path, progress, _paint);
  }

  void _paintWobbly(Canvas canvas, Size size, double inset) {
    final path = _wobblyOutlinePath(
      size,
      topRightRadius,
      bottomRightRadius,
      inset,
      styleSeed,
    );
    _drawPathProgress(canvas, path, progress, _paint);
  }

  void _paintDoubleSweep(Canvas canvas, Size size, double inset) {
    final outer = _smoothOutlinePath(
      size,
      topRightRadius,
      bottomRightRadius,
      inset,
    );
    final gap = max(strokeWidth * 2.2, 5.0);
    final innerInset = inset + gap;
    if (size.width <= 2 * innerInset + 4 || size.height <= 2 * innerInset + 4) {
      _drawPathProgress(canvas, outer, progress, _paint);
      return;
    }
    final inner = _smoothOutlinePath(
      size,
      topRightRadius,
      bottomRightRadius,
      innerInset,
    );

    final split = 0.48 + 0.04 * _correctRevealDet01(styleSeed, 1400);
    if (progress <= split) {
      _drawPathProgress(canvas, outer, progress / split, _paint);
    } else {
      _drawPathProgress(canvas, outer, 1.0, _paint);
      final innerT = (progress - split) / (1.0 - split);
      _drawPathProgress(canvas, inner, innerT, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant TriviaCorrectRevealPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.styleSeed != styleSeed ||
        oldDelegate.topRightRadius != topRightRadius ||
        oldDelegate.bottomRightRadius != bottomRightRadius;
  }
}
