import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_confetti_settings.dart';

import '../../theme/theme_palette_extension.dart';

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

/// Translucent falling confetti with optional sparse [messages] banners.
class BirthdayConfettiOverlay extends StatefulWidget {
  const BirthdayConfettiOverlay({
    super.key,
    required this.settings,
    required this.messages,
    required this.fallbackAccents,
  });

  final BirthdayConfettiScheduleSettings settings;
  final List<String> messages;
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
    final palette = Theme.of(context).extension<PaletteTertiaryLayers>();
    var accents = <Color>[];
    if (widget.settings.colorHexes.isNotEmpty) {
      for (final h in widget.settings.colorHexes) {
        final c = _colorFromHex(h);
        if (c != null) {
          accents.add(c);
        }
      }
    }
    if (accents.isEmpty && palette != null) {
      accents = <Color>[
        palette.accent1,
        palette.accent2,
        palette.accent3,
        palette.accent4,
      ];
    }
    if (accents.isEmpty) {
      accents = widget.fallbackAccents;
    }
    if (accents.isEmpty) {
      accents = <Color>[Colors.blueGrey.shade300];
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
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
        ),
        if (widget.messages.isNotEmpty)
          _OccasionalMessageLayer(
            messages: widget.messages,
            interval: Duration(seconds: widget.settings.messageIntervalSec),
          ),
      ],
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

enum _ConfettiShapeKind { rect, circle, star, streamer }

class _OccasionalMessageLayer extends StatefulWidget {
  const _OccasionalMessageLayer({
    required this.messages,
    required this.interval,
  });

  final List<String> messages;
  final Duration interval;

  @override
  State<_OccasionalMessageLayer> createState() => _OccasionalMessageLayerState();
}

class _OccasionalMessageLayerState extends State<_OccasionalMessageLayer> {
  Timer? _timer;
  Timer? _fadeTimer;
  String _text = '';
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => _flash());
  }

  void _flash() {
    if (!mounted || widget.messages.isEmpty) {
      return;
    }
    final r = math.Random();
    _fadeTimer?.cancel();
    setState(() {
      _text = widget.messages[r.nextInt(widget.messages.length)];
      _opacity = 1;
    });
    _fadeTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) {
        return;
      }
      setState(() => _opacity = 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Align(
          alignment: const Alignment(0, -0.72),
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth * 0.72),
                child: Text(
                  _text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: 0.42,
                    ),
                    shadows: const [
                      Shadow(
                        blurRadius: 18,
                        color: Color.fromRGBO(0, 0, 0, 0.2),
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

List<_ConfettiShapeKind> _expandedKinds(List<String> tokens) {
  const concrete = <_ConfettiShapeKind>[
    _ConfettiShapeKind.rect,
    _ConfettiShapeKind.circle,
    _ConfettiShapeKind.star,
    _ConfettiShapeKind.streamer,
  ];
  final out = <_ConfettiShapeKind>[];
  for (final t in tokens) {
    if (t == 'mix') {
      out.addAll(concrete);
    } else {
      switch (t) {
        case 'rect':
          out.add(_ConfettiShapeKind.rect);
        case 'circle':
          out.add(_ConfettiShapeKind.circle);
        case 'star':
          out.add(_ConfettiShapeKind.star);
        case 'streamer':
          out.add(_ConfettiShapeKind.streamer);
      }
    }
  }
  return out.isEmpty ? concrete : out;
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
    final rand = math.Random((progress * 1e9).toInt());
    final kinds = _expandedKinds(settings.shapeTokens);
    final nSprites = (10 + settings.density * 12).round().clamp(10, 22);
    final denom = math.max(1, accents.length);

    for (var i = 0; i < nSprites; i++) {
      final base = accents[i % denom];
      final nx = rand.nextDouble();
      final float = (((progress + i * 0.061) % 1.0) + rand.nextDouble() * 0.28) % 1.0;
      final yPx = float * size.height * 1.08 - size.height * 0.04;
      final xPx = nx * size.width + math.sin(progress * math.pi * 2 + i * 0.7) * 18;
      final relY = yPx.clamp(0.0, size.height) / math.max(1e-6, size.height);
      final bottomBias = 1.0 - ((relY - 0.78) / 0.22).clamp(0.0, 1.0) * 0.45;

      final maxA = settings.opacity;
      final minA = (maxA * 0.18).clamp(0.05, maxA * 0.45);
      final alphaBase = bottomBias *
          (0.12 + rand.nextDouble() * 0.2 * math.max(bottomBias, 0.7));
      final color = base.withValues(alpha: alphaBase.clamp(minA, maxA));

      final kind = kinds[rand.nextInt(kinds.length)];
      final w = math.max(size.shortestSide * 0.012, 5.0);
      final h = w * (1.4 + rand.nextDouble() * 1.8);

      canvas.save();
      canvas.translate(xPx, yPx);
      canvas.rotate(progress * math.pi * 2 * 0.35 + i * 0.41);

      switch (kind) {
        case _ConfettiShapeKind.rect:
          final rrect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w * 1.6, height: h * 0.55),
            Radius.circular(w * 0.22),
          );
          canvas.drawRRect(rrect, Paint()..color = color);
        case _ConfettiShapeKind.circle:
          canvas.drawCircle(Offset.zero, w * 0.55, Paint()..color = color);
        case _ConfettiShapeKind.star:
          _paintStar(canvas, w * 0.9, color);
        case _ConfettiShapeKind.streamer:
          final sr = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w * 0.35, height: h * 1.5),
            Radius.circular(w * 0.2),
          );
          canvas.drawRRect(sr, Paint()..color = color);
      }
      canvas.restore();
    }
  }

  void _paintStar(Canvas canvas, double radius, Color color) {
    final path = Path();
    const points = 5;
    final inner = radius * 0.38;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : inner;
      final a = -math.pi / 2 + i * math.pi / points;
      final x = r * math.cos(a);
      final y = r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accents.length != accents.length ||
      oldDelegate.settings.density != settings.density ||
      oldDelegate.settings.fallSpeed != settings.fallSpeed ||
      oldDelegate.settings.opacity != settings.opacity ||
      oldDelegate.settings.shapeTokens.join() != settings.shapeTokens.join();
}
