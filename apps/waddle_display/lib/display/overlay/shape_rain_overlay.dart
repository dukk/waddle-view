import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_shape_rain_settings.dart';

import '../../theme/theme_palette_extension.dart';

/// Falling theme-tinted glyphs (hearts, raindrops, cats, dogs).
class ShapeRainOverlay extends StatefulWidget {
  const ShapeRainOverlay({
    super.key,
    required this.settings,
    required this.fallbackAccents,
    this.suppressBottomBias = true,
    this.biasHeightFraction = 0.85,
  });

  final ShapeRainScheduleSettings settings;
  final List<Color> fallbackAccents;
  final bool suppressBottomBias;
  final double biasHeightFraction;

  @override
  State<ShapeRainOverlay> createState() => _ShapeRainOverlayState();
}

class _ShapeRainOverlayState extends State<ShapeRainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<PaletteTertiaryLayers>();
    final accents = palette == null
        ? widget.fallbackAccents
        : <Color>[
            palette.accent1,
            palette.accent2,
            palette.accent3,
            palette.accent4,
          ];

    return LayoutBuilder(
      builder: (context, c) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            return CustomPaint(
              key: const Key('shape_rain_custom_paint'),
              size: Size(c.maxWidth, c.maxHeight),
              painter: _ShapeRainPainter(
                accents: accents,
                shapeTokens: widget.settings.shapeTokens,
                progress: (_ctrl.value * 104729) % 1.0,
                suppressBandStart: widget.biasHeightFraction.clamp(0.5, 1.0),
                suppressBottomBias: widget.suppressBottomBias,
              ),
            );
          },
        );
      },
    );
  }
}

List<String> _expandedShapeGlyphs(List<String> tokens) {
  const concrete = <String, String>{
    'heart': '\u2665',
    'raindrop': '\u{1F4A7}',
    'cat': '\u{1F431}',
    'dog': '\u{1F436}',
  };
  final out = <String>[];
  for (final t in tokens) {
    if (t == 'mix') {
      out.addAll(concrete.values);
    } else {
      final g = concrete[t];
      if (g != null) {
        out.add(g);
      }
    }
  }
  return out.isEmpty ? concrete.values.toList() : out;
}

class _ShapeRainPainter extends CustomPainter {
  _ShapeRainPainter({
    required this.accents,
    required this.shapeTokens,
    required this.progress,
    required this.suppressBandStart,
    required this.suppressBottomBias,
  });

  final List<Color> accents;
  final List<String> shapeTokens;
  final double progress;
  final double suppressBandStart;
  final bool suppressBottomBias;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random((progress * 1e9).toInt());
    final glyphs = _expandedShapeGlyphs(shapeTokens);
    final nSprites = math.min(
      accents.isEmpty ? 10 : accents.length + 12,
      20,
    );
    final denom = accents.isEmpty ? 1 : accents.length;

    for (var i = 0; i < nSprites; i++) {
      final base = accents.isEmpty
          ? Colors.pinkAccent.withValues(alpha: 0.2)
          : accents[i % denom];
      final nx = rand.nextDouble();
      final float = (((progress + i * 0.07) % 1.0) + rand.nextDouble() * 0.35) %
          1.0;
      final yPx = float * size.height * 1.06 - size.height * 0.05;
      final xPx = nx * size.width + math.sin(progress * math.pi * 2 + i) * 22;
      final spriteSize = math.max(
        size.shortestSide * 0.016,
        12.0,
      );
      final relY =
          yPx.clamp(0.0, size.height) / math.max(1e-6, size.height);
      final suppressionT = suppressBottomBias
          ? ((relY - suppressBandStart) /
                  math.max(1e-4, 1.0 - suppressBandStart))
              .clamp(0.0, 1.0)
          : 0.0;
      final bottomFactor = 1.0 - suppressionT * 0.55;

      final alphaBase = bottomFactor *
          (0.14 +
              rand.nextDouble() *
                  (0.1 * math.max(bottomFactor, 0.65)));

      final color = base.withValues(
        alpha: alphaBase.clamp(0.035, 0.22),
      );

      final glyph = glyphs[rand.nextInt(glyphs.length)];
      final scale = spriteSize *
          ((0.7 + rand.nextDouble() * 0.95) *
              math.max(bottomFactor * 1.08, 0.55));

      canvas.save();
      canvas.translate(xPx, yPx);
      canvas.rotate(progress * math.pi * 2 * 0.22 + i * 0.3);
      final shapeTp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: glyph,
          style: TextStyle(
            color: color,
            fontSize: scale * 2.2,
            height: 1,
            shadows: const [
              Shadow(
                blurRadius: 14,
                color: Color.fromRGBO(0, 0, 0, 0.18),
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      )..layout();
      shapeTp.paint(
        canvas,
        Offset(-shapeTp.width / 2, -shapeTp.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShapeRainPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accents.length != accents.length ||
      oldDelegate.shapeTokens.join() != shapeTokens.join();
}
