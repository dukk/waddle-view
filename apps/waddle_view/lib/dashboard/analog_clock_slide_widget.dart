import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clock.dart';
import '../curator/screen_layout_parse.dart';
import 'clock_date_format.dart';
import 'clock_hand_angles.dart';
import 'dashboard_viewport_scope.dart';

/// Full-slide analog clock with date (local time).
class AnalogClockSlideWidget extends StatefulWidget {
  const AnalogClockSlideWidget({
    super.key,
    required this.spec,
    required this.theme,
    this.clock = const SystemClock(),
    this.dialSize = 480,
  });

  final ParsedWidgetSpec spec;
  final ThemeData theme;
  final Clock clock;
  final double dialSize;

  @override
  State<AnalogClockSlideWidget> createState() => _AnalogClockSlideWidgetState();
}

class _AnalogClockSlideWidgetState extends State<AnalogClockSlideWidget> {
  Timer? _timer;
  late DateTime _tick;

  @override
  void initState() {
    super.initState();
    _tick = widget.clock.now().toLocal();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tick = widget.clock.now().toLocal();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = _tick;
    final angles = ClockHandAngles.fromLocal(local);
    final scheme = widget.theme.colorScheme;
    final s = DashboardViewportScope.scaleOf(context);
    final dial = widget.dialSize * s;

    return Padding(
      padding: EdgeInsets.only(bottom: 12 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            key: const ValueKey<String>('analog_clock_dial'),
            size: Size(dial, dial),
            painter: AnalogClockPainter(
              angles: angles,
              layoutScale: s,
              dialColor: scheme.onSurface,
              faceColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              handHour: scheme.primary,
              handMinute: scheme.onSurface,
              handSecond: scheme.tertiary,
            ),
          ),
          SizedBox(height: 16 * s),
          Text(
            formatClockDate(local),
            style: widget.theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AnalogClockPainter extends CustomPainter {
  AnalogClockPainter({
    required this.angles,
    this.layoutScale = 1.0,
    required this.dialColor,
    required this.faceColor,
    required this.handHour,
    required this.handMinute,
    required this.handSecond,
  });

  final ClockHandAngles angles;
  final double layoutScale;
  final Color dialColor;
  final Color faceColor;
  final Color handHour;
  final Color handMinute;
  final Color handSecond;

  @override
  void paint(Canvas canvas, Size size) {
    final s = layoutScale;
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 * 0.92;

    final face = Paint()..color = faceColor;
    canvas.drawCircle(c, r, face);

    final rim = Paint()
      ..color = dialColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s;
    canvas.drawCircle(c, r, rim);

    final tickMajor = Paint()
      ..color = dialColor
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round;
    final tickMinor = Paint()
      ..color = dialColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.5 * s
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 60; i++) {
      final a = 2 * math.pi * i / 60.0;
      final outer = Offset(c.dx + r * 0.98 * math.sin(a), c.dy - r * 0.98 * math.cos(a));
      final innerFrac = i % 5 == 0 ? 0.82 : 0.9;
      final inner = Offset(
        c.dx + r * innerFrac * math.sin(a),
        c.dy - r * innerFrac * math.cos(a),
      );
      canvas.drawLine(inner, outer, i % 5 == 0 ? tickMajor : tickMinor);
    }

    void drawHand(double angle, double length, double width, Color color) {
      final p = Paint()
        ..color = color
        ..strokeWidth = width * s
        ..strokeCap = StrokeCap.round;
      final end = Offset(
        c.dx + r * length * math.sin(angle),
        c.dy - r * length * math.cos(angle),
      );
      canvas.drawLine(c, end, p);
    }

    drawHand(angles.hour, 0.48, 6, handHour);
    drawHand(angles.minute, 0.72, 4, handMinute);
    drawHand(angles.second, 0.78, 2, handSecond);

    final hub = Paint()..color = handMinute;
    canvas.drawCircle(c, 5 * s, hub);
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) {
    return oldDelegate.angles != angles ||
        oldDelegate.layoutScale != layoutScale ||
        oldDelegate.dialColor != dialColor ||
        oldDelegate.faceColor != faceColor ||
        oldDelegate.handHour != handHour ||
        oldDelegate.handMinute != handMinute ||
        oldDelegate.handSecond != handSecond;
  }
}
