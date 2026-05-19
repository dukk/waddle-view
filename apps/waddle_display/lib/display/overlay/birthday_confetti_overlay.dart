import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_confetti_settings.dart';

/// One full vertical drift cycle at [fallSpeed] `1.0` matches the historical
/// ~5s tick; lower [fallSpeed] stretches the cycle (slower fall), down to
/// [kBirthdayConfettiFallSpeedMin] and capped at [kBirthdayConfettiMaxCycleSeconds].
Duration birthdayConfettiCycleDuration(double fallSpeed) {
  final clamped = fallSpeed.clamp(
    kBirthdayConfettiFallSpeedMin,
    kBirthdayConfettiFallSpeedMax,
  );
  final s = (5.0 / clamped).clamp(4.0, kBirthdayConfettiMaxCycleSeconds);
  return Duration(milliseconds: (s * 1000).round());
}

/// Translucent falling confetti (no overlay text).
class BirthdayConfettiOverlay extends StatefulWidget {
  const BirthdayConfettiOverlay({
    super.key,
    required this.settings,
    required this.fallbackAccents,
  });

  final BirthdayConfettiScheduleSettings settings;
  final List<Color> fallbackAccents;

  @override
  State<BirthdayConfettiOverlay> createState() => _BirthdayConfettiOverlayState();
}

class _BirthdayConfettiOverlayState extends State<BirthdayConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: birthdayConfettiCycleDuration(widget.settings.fallSpeed),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BirthdayConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.fallSpeed != widget.settings.fallSpeed) {
      _ctrl.duration = birthdayConfettiCycleDuration(widget.settings.fallSpeed);
      _ctrl
        ..reset()
        ..repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    var accents = <Color>[];
    if (widget.settings.colorHexes.isNotEmpty) {
      for (final h in widget.settings.colorHexes) {
        final c = _colorFromHex(h);
        if (c != null) {
          accents.add(c);
        }
      }
    }
    if (accents.isEmpty) {
      for (final h in kBirthdayConfettiDefaultColorHexes) {
        final c = _colorFromHex(h);
        if (c != null) {
          accents.add(c);
        }
      }
    }
    if (accents.isEmpty) {
      accents = widget.fallbackAccents;
    }
    if (accents.isEmpty) {
      accents = <Color>[Colors.blueGrey.shade300];
    }

    return LayoutBuilder(
      builder: (context, c) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            return CustomPaint(
              key: const Key('birthday_confetti_custom_paint'),
              size: Size(c.maxWidth, c.maxHeight),
              painter: _ConfettiPainter(
                accents: accents,
                settings: widget.settings,
                progress: (_ctrl.value * 97103) % 1.0,
              ),
            );
          },
        );
      },
    );
  }
}

Color? _colorFromHex(String hex) {
  final s = hex.trim();
  if (s.length == 7 && s.startsWith('#')) {
    final v = int.tryParse(s.substring(1), radix: 16);
    if (v == null) {
      return null;
    }
    return Color(0xFF000000 | v);
  }
  if (s.length == 9 && s.startsWith('#')) {
    final v = int.tryParse(s.substring(1), radix: 16);
    if (v == null) {
      return null;
    }
    return Color(v);
  }
  return null;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.accents,
    required this.settings,
    required this.progress,
  });

  final List<Color> accents;
  final BirthdayConfettiScheduleSettings settings;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final area = size.width * size.height;
    final baseCount = (area / 9000).round();
    final nSprites = (baseCount + settings.density * 110).round().clamp(72, 240);
    final denom = math.max(1, accents.length);
    final unit = math.max(size.shortestSide * 0.011, 4.5);

    for (var i = 0; i < nSprites; i++) {
      final pieceRand = math.Random(i * 10007 + 17);
      final yNorm = math.pow(pieceRand.nextDouble(), 0.52).toDouble();
      final drift = math.sin(progress * math.pi * 2 + i * 0.63) * 14;
      final float = (yNorm + progress + pieceRand.nextDouble() * 0.08) % 1.0;
      final yPx = float * size.height * 1.06 - size.height * 0.03;
      final xPx =
          pieceRand.nextDouble() * size.width + drift + math.sin(i * 0.41) * 6;
      final relY = yPx.clamp(0.0, size.height) / math.max(1e-6, size.height);

      final zoneFade = relY < 0.4
          ? 1.0
          : relY < 0.7
          ? 1.0 - (relY - 0.4) / 0.3 * 0.35
          : 1.0 - 0.35 - (relY - 0.7) / 0.3 * 0.55;
      if (zoneFade < 0.12) {
        continue;
      }

      final base = accents[i % denom];
      final maxA = settings.opacity;
      final minA = (maxA * 0.55).clamp(0.2, maxA);
      final alpha = (maxA * zoneFade * (0.88 + pieceRand.nextDouble() * 0.12))
          .clamp(minA, maxA);
      final color = base.withValues(alpha: alpha);

      final stripLen = unit * (2.6 + pieceRand.nextDouble() * 2.4);
      final stripW = unit * (0.2 + pieceRand.nextDouble() * 0.14);
      final rotation = pieceRand.nextDouble() * math.pi * 2;

      canvas.save();
      canvas.translate(xPx, yPx);
      canvas.rotate(rotation + progress * math.pi * 0.2);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: stripLen, height: stripW),
        Radius.circular(stripW * 0.2),
      );
      canvas.drawRRect(rrect, Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accents.length != accents.length ||
      oldDelegate.settings.density != settings.density ||
      oldDelegate.settings.fallSpeed != settings.fallSpeed ||
      oldDelegate.settings.opacity != settings.opacity;
}
