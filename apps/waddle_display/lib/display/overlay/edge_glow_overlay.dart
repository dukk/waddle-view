import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_edge_glow_settings.dart';

/// One full fade-in-out pulse at [pulseSpeed] `1.0` is about 3 seconds.
Duration edgeGlowPulseDuration(double pulseSpeed) {
  final clamped = pulseSpeed.clamp(
    kEdgeGlowPulseSpeedMin,
    kEdgeGlowPulseSpeedMax,
  );
  final s = (3.0 / clamped).clamp(1.5, 60.0);
  return Duration(milliseconds: (s * 1000).round());
}

/// Pulsing colored vignette along screen edges (non-interactive).
class EdgeGlowOverlay extends StatefulWidget {
  const EdgeGlowOverlay({
    super.key,
    required this.settings,
  });

  final EdgeGlowScheduleSettings settings;

  @override
  State<EdgeGlowOverlay> createState() => _EdgeGlowOverlayState();
}

class _EdgeGlowOverlayState extends State<EdgeGlowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: edgeGlowPulseDuration(widget.settings.pulseSpeed),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EdgeGlowOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.pulseSpeed != widget.settings.pulseSpeed) {
      _ctrl.duration = edgeGlowPulseDuration(widget.settings.pulseSpeed);
      _ctrl
        ..reset()
        ..repeat(reverse: true);
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
              key: const Key('edge_glow_custom_paint'),
              size: Size(c.maxWidth, c.maxHeight),
              painter: _EdgeGlowPainter(
                settings: widget.settings,
                pulseFactor: _ctrl.value,
              ),
            );
          },
        );
      },
    );
  }
}

class _EdgeGlowPainter extends CustomPainter {
  _EdgeGlowPainter({
    required this.settings,
    required this.pulseFactor,
  });

  final EdgeGlowScheduleSettings settings;
  final double pulseFactor;

  static const double _edgeBandFraction = 0.22;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final base = _colorFromHex(settings.colorHex);
    final peakAlpha = (settings.intensity * pulseFactor).clamp(0.0, 1.0);
    if (peakAlpha <= 0) {
      return;
    }
    final glow = base.withValues(alpha: peakAlpha);
    final transparent = base.withValues(alpha: 0);
    final band = (size.shortestSide * _edgeBandFraction).clamp(24.0, 280.0);

    _paintBand(
      canvas,
      Rect.fromLTWH(0, 0, size.width, band),
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      glow: glow,
      transparent: transparent,
    );
    _paintBand(
      canvas,
      Rect.fromLTWH(0, size.height - band, size.width, band),
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      glow: glow,
      transparent: transparent,
    );
    _paintBand(
      canvas,
      Rect.fromLTWH(0, 0, band, size.height),
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      glow: glow,
      transparent: transparent,
    );
    _paintBand(
      canvas,
      Rect.fromLTWH(size.width - band, 0, band, size.height),
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      glow: glow,
      transparent: transparent,
    );
  }

  void _paintBand(
    Canvas canvas,
    Rect rect, {
    required Alignment begin,
    required Alignment end,
    required Color glow,
    required Color transparent,
  }) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: [glow, transparent],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _EdgeGlowPainter oldDelegate) =>
      oldDelegate.pulseFactor != pulseFactor ||
      oldDelegate.settings.colorHex != settings.colorHex ||
      oldDelegate.settings.intensity != settings.intensity ||
      oldDelegate.settings.pulseSpeed != settings.pulseSpeed;
}

Color _colorFromHex(String hex) {
  final trimmed = hex.trim();
  if (!trimmed.startsWith('#')) {
    return const Color(0xFFFF3B30);
  }
  final h = trimmed.substring(1);
  if (h.length == 6) {
    return Color(int.parse('FF$h', radix: 16));
  }
  if (h.length == 8) {
    return Color(int.parse(h, radix: 16));
  }
  return const Color(0xFFFF3B30);
}
