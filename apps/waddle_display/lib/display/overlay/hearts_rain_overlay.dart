import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme_palette_extension.dart';

/// Subtle repeating hearts / short phrases tinted from [PaletteTertiaryLayers].
class HeartsRainOverlay extends StatefulWidget {
  const HeartsRainOverlay({
    super.key,
    required this.messages,
    required this.fallbackAccents,
    this.suppressBottomBias = true,
    this.biasHeightFraction = 0.85,
  });

  final List<String> messages;
  final List<Color> fallbackAccents;
  final bool suppressBottomBias;
  final double biasHeightFraction;

  @override
  State<HeartsRainOverlay> createState() => _HeartsRainOverlayState();
}

class _HeartsRainOverlayState extends State<HeartsRainOverlay>
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
              size: Size(c.maxWidth, c.maxHeight),
              painter: _HeartsRainPainter(
                accents: accents,
                messages: widget.messages.isEmpty ? const [''] : widget.messages,
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

class _HeartsRainPainter extends CustomPainter {
  _HeartsRainPainter({
    required this.accents,
    required this.messages,
    required this.progress,
    required this.suppressBandStart,
    required this.suppressBottomBias,
  });

  final List<Color> accents;
  final List<String> messages;
  final double progress;
  final double suppressBandStart;
  final bool suppressBottomBias;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random((progress * 1e9).toInt());
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
          ((i.isEven ? 0.11 : 0.18) +
              rand.nextDouble() *
                  ((i.isEven ? 0.07 : 0.08) *
                      math.max(bottomFactor, 0.65)));

      final color = base.withValues(
        alpha: alphaBase.clamp(0.035, 0.22),
      );

      if (i.isEven) {
        final scale = spriteSize *
            ((0.7 + rand.nextDouble() * 0.95) *
                math.max(bottomFactor * 1.08, 0.55));

        canvas.save();
        canvas.translate(xPx, yPx);
        canvas.rotate(progress * math.pi * 2 * 0.22 + i * 0.3);
        final heartTp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: '\u2665',
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
        heartTp.paint(
          canvas,
          Offset(-heartTp.width / 2, -heartTp.height / 2),
        );
        canvas.restore();
      } else {
        final txt = messages[i % messages.length].trim().isEmpty
            ? ''
            : messages[i % messages.length];
        if (txt.isEmpty) {
          continue;
        }
        final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            style: TextStyle(
              fontSize: (spriteSize * (0.9 + rand.nextDouble() * 0.45))
                  .clamp(9, 20),
              color:
                  color.withValues(alpha: color.a.clamp(0.04, 0.21)),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.35,
              shadows: const [
                Shadow(
                  blurRadius: 10,
                  color: Color.fromRGBO(0, 0, 0, 0.22),
                  offset: Offset(0, 2),
                ),
              ],
            ),
            text: txt,
          ),
        )..layout(maxWidth: size.width * 0.45);

        canvas.save();
        canvas.translate(xPx + math.sin(progress * math.pi + i) * 6, yPx);
        canvas.rotate(math.sin(progress * math.pi + i * 0.51) * 0.08);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeartsRainPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accents.length != accents.length ||
      oldDelegate.messages.join('\u241e') !=
          messages.join('\u241e');
}
