import 'dart:math';

import 'package:flutter/material.dart';

import 'trivia_slide_timing.dart';

/// Layout JSON `strikeAnimation` values for the trivia widget.
enum TriviaStrikeAnimationKind {
  /// Wobbly two-stroke X with per-option variation.
  handDrawnX,

  /// Legacy circle badge with red close icon (original strike-out look).
  strikeOutX,

  /// Dense horizontal scribble drawn progressively across the option (default).
  scribbleOut,
}

/// Parses `strikeAnimation` from trivia widget `config` (case-insensitive;
/// accepts `hand_drawn_x`, `strike-out-x`, etc.).
TriviaStrikeAnimationKind parseTriviaStrikeAnimationKind(
  Map<String, dynamic> config,
) {
  final raw = config['strikeAnimation'];
  if (raw is! String) {
    return TriviaStrikeAnimationKind.scribbleOut;
  }
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  switch (key) {
    case 'strikeoutx':
    case 'strikeout':
      return TriviaStrikeAnimationKind.strikeOutX;
    case 'scribbleout':
    case 'scribble':
      return TriviaStrikeAnimationKind.scribbleOut;
    case 'handdrawnx':
    case 'handdrawn':
      return TriviaStrikeAnimationKind.handDrawnX;
    default:
      return TriviaStrikeAnimationKind.scribbleOut;
  }
}

/// Parses `strikeAnimationDurationMs` from trivia widget `config`.
/// Clamped to \[120, 3000]; invalid or missing values use [kTriviaStrikeAnimationMs].
int parseStrikeAnimationDurationMs(Map<String, dynamic> config) {
  final v = config['strikeAnimationDurationMs'];
  if (v is! num) {
    return kTriviaStrikeAnimationMs;
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

/// Deterministic scalar in \[0, 1) from a seed and salt (for per-option variation).
@visibleForTesting
double triviaStrikeDet01(int seed, int salt) {
  var x = seed ^ (salt * 0x9e3779b9);
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  return (x & 0xfffffff) / 0x10000000;
}

Offset _rotateAround(Offset p, Offset c, double radians) {
  final x = p.dx - c.dx;
  final y = p.dy - c.dy;
  final cosR = cos(radians);
  final sinR = sin(radians);
  return Offset(
    x * cosR - y * sinR + c.dx,
    x * sinR + y * cosR + c.dy,
  );
}

/// Builds a slightly irregular polyline between [a] and [b] for a hand-drawn feel.
Path _wobblyStrokePath(
  Offset a,
  Offset b,
  int seed, {
  int segments = 14,
}) {
  final path = Path()..moveTo(a.dx, a.dy);
  final d = b - a;
  final len = d.distance;
  if (len < 1e-6) {
    path.lineTo(b.dx, b.dy);
    return path;
  }
  final u = d / len;
  final perp = Offset(-u.dy, u.dx);
  final amp = len * (0.012 + 0.018 * triviaStrikeDet01(seed, 401));

  for (var i = 1; i < segments; i++) {
    final t = i / segments;
    final base = Offset.lerp(a, b, t)!;
    final envelope = sin(t * pi);
    final jitter = (triviaStrikeDet01(seed, 500 + i) - 0.5) * 2.0;
    final wobble = perp * (amp * envelope * jitter);
    path.lineTo(base.dx + wobble.dx, base.dy + wobble.dy);
  }
  path.lineTo(b.dx, b.dy);
  return path;
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
    final partial = metric.extractPath(0.0, end);
    canvas.drawPath(partial, paint);
    return;
  }
}

Path _buildScribblePath(double w, double h, int seed) {
  final mx = w * 0.04;
  final my = h * 0.06;
  final usableW = w - 2 * mx;
  final usableH = h - 2 * my;
  if (usableW < 1 || usableH < 1) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, h);
  }
  // Many short waves across the width for a busier “scribble” read.
  final waves = 34 + (seed % 18);
  final pts = 160;
  final path = Path();
  final baseY = my + usableH * (0.48 + 0.12 * (triviaStrikeDet01(seed, 600) - 0.5));
  final drift = usableH * 0.14 * (triviaStrikeDet01(seed, 601) - 0.5);
  for (var i = 0; i <= pts; i++) {
    final u = i / pts;
    final x = mx + usableW * u;
    final phase = triviaStrikeDet01(seed, 700) * pi * 2;
    final freq = waves * pi * u + phase;
    final amp1 = usableH * (0.34 + 0.14 * triviaStrikeDet01(seed, 701));
    final amp2 = usableH * (0.22 + 0.1 * triviaStrikeDet01(seed, 702));
    final amp3 = usableH * (0.14 + 0.08 * triviaStrikeDet01(seed, 703));
    final y = baseY +
        drift * u +
        sin(freq) * amp1 * 0.72 +
        sin(freq * 4.2 + 0.35) * amp2 * 0.58 +
        sin(freq * 9.1 + 1.1) * amp3 * 0.52 +
        sin(freq * 0.47 + 2.4) * amp1 * 0.18;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path;
}

/// Paints hand-drawn X or scribble strike overlay ([TriviaStrikeAnimationKind.strikeOutX]
/// is handled in the widget with a badge, not this painter).
class TriviaStrikeOverlayPainter extends CustomPainter {
  TriviaStrikeOverlayPainter({
    required this.kind,
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.styleSeed,
  });

  final TriviaStrikeAnimationKind kind;
  final double progress;
  final Color color;
  final double strokeWidth;
  final int styleSeed;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case TriviaStrikeAnimationKind.strikeOutX:
        return;
      case TriviaStrikeAnimationKind.handDrawnX:
        _paintHandDrawnX(canvas, size);
        return;
      case TriviaStrikeAnimationKind.scribbleOut:
        _paintScribble(canvas, size);
        return;
    }
  }

  void _paintHandDrawnX(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) {
      return;
    }

    final inset = min(w, h) * (0.035 + 0.04 * triviaStrikeDet01(styleSeed, 1));
    final c = Offset(w * 0.5, h * 0.5);
    final hubJ = Offset(
      w * (0.08 * (triviaStrikeDet01(styleSeed, 2) - 0.5)),
      h * (0.08 * (triviaStrikeDet01(styleSeed, 3) - 0.5)),
    );
    final rot = (triviaStrikeDet01(styleSeed, 4) - 0.5) * 0.14;
    final swap = triviaStrikeDet01(styleSeed, 5) >= 0.5;
    final split = 0.38 + triviaStrikeDet01(styleSeed, 6) * 0.22;
    final segA = 11 + (styleSeed % 5);
    final segB = 11 + ((styleSeed >> 3) % 5);

    Offset nw = Offset(inset, inset);
    Offset se = Offset(w - inset, h - inset);
    Offset ne = Offset(w - inset, inset);
    Offset sw = Offset(inset, h - inset);

    final j0 = (triviaStrikeDet01(styleSeed, 7) - 0.5) * inset * 0.55;
    final j1 = (triviaStrikeDet01(styleSeed, 8) - 0.5) * inset * 0.55;
    nw += Offset(j0, j0 * 0.6);
    se -= Offset(j1 * 0.7, j1);
    ne += Offset(j1, -j0 * 0.5);
    sw += Offset(-j0 * 0.5, j1);

    nw = _rotateAround(nw + hubJ, c, rot);
    se = _rotateAround(se + hubJ, c, rot);
    ne = _rotateAround(ne + hubJ, c, rot);
    sw = _rotateAround(sw + hubJ, c, rot);

    final pathBackslash = _wobblyStrokePath(nw, se, styleSeed ^ 0x1111, segments: segA);
    final pathSlash = _wobblyStrokePath(ne, sw, styleSeed ^ 0x2222, segments: segB);

    final firstPath = swap ? pathSlash : pathBackslash;
    final secondPath = swap ? pathBackslash : pathSlash;

    final wobbleStroke =
        strokeWidth * (0.88 + 0.28 * triviaStrikeDet01(styleSeed, 9));

    final paint = Paint()
      ..color = color
      ..strokeWidth = wobbleStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double firstLegT;
    double secondLegT;
    if (progress <= split) {
      firstLegT = progress / split;
      secondLegT = 0;
    } else {
      firstLegT = 1;
      secondLegT = (progress - split) / (1.0 - split);
    }

    _drawPathProgress(canvas, firstPath, firstLegT, paint);
    _drawPathProgress(canvas, secondPath, secondLegT, paint);
  }

  void _paintScribble(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    final scribblePath = _buildScribblePath(w, h, styleSeed);
    final wobbleStroke =
        strokeWidth * (0.92 + 0.28 * triviaStrikeDet01(styleSeed, 800));
    final paint = Paint()
      ..color = color
      ..strokeWidth = wobbleStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawPathProgress(canvas, scribblePath, progress, paint);
  }

  @override
  bool shouldRepaint(covariant TriviaStrikeOverlayPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.styleSeed != styleSeed;
  }
}
