import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../clock.dart';
import '../../../curator/screen_layout_parse.dart';
import '../../../theme/display_theme.dart';
import 'clock_date_format.dart';
import 'clock_hand_angles.dart';
import '../../dashboard_viewport_scope.dart';

enum AnalogClockDialLabelMode {
  none,
  numbers,
  roman,
  cardinalNumbers;

  static const Set<int> _cardinalHours = {12, 3, 6, 9};
  static const Map<int, String> _romanByHour = <int, String>{
    1: 'I',
    2: 'II',
    3: 'III',
    4: 'IV',
    5: 'V',
    6: 'VI',
    7: 'VII',
    8: 'VIII',
    9: 'IX',
    10: 'X',
    11: 'XI',
    12: 'XII',
  };

  static AnalogClockDialLabelMode fromConfigValue(Object? raw) {
    if (raw is! String) {
      return AnalogClockDialLabelMode.none;
    }
    switch (raw.trim().toLowerCase()) {
      case 'numbers':
      case 'numeric':
        return AnalogClockDialLabelMode.numbers;
      case 'roman':
      case 'roman_numerals':
        return AnalogClockDialLabelMode.roman;
      case 'cardinal_numbers':
      case 'cardinal':
      case 'crosshair_numbers':
        return AnalogClockDialLabelMode.cardinalNumbers;
      case 'none':
      default:
        return AnalogClockDialLabelMode.none;
    }
  }

  bool includesHour(int hour) {
    return switch (this) {
      AnalogClockDialLabelMode.none => false,
      AnalogClockDialLabelMode.cardinalNumbers => _cardinalHours.contains(hour),
      _ => true,
    };
  }

  String labelForHour(int hour) {
    return switch (this) {
      AnalogClockDialLabelMode.roman => _romanByHour[hour] ?? '$hour',
      _ => '$hour',
    };
  }
}

enum AnalogClockAccentChoice {
  accent1,
  accent2,
  accent3;

  static AnalogClockAccentChoice fromConfigValue(
    Object? raw, {
    AnalogClockAccentChoice defaultChoice = AnalogClockAccentChoice.accent1,
  }) {
    if (raw is int) {
      return _fromInt(raw);
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty) {
        return defaultChoice;
      }
      switch (normalized) {
        case 'accent1':
        case '1':
          return AnalogClockAccentChoice.accent1;
        case 'accent2':
        case '2':
          return AnalogClockAccentChoice.accent2;
        case 'accent3':
        case '3':
          return AnalogClockAccentChoice.accent3;
      }
      final parsed = int.tryParse(normalized);
      if (parsed != null) {
        return _fromInt(parsed);
      }
    }
    return defaultChoice;
  }

  static AnalogClockAccentChoice _fromInt(int value) {
    switch (value) {
      case 2:
        return AnalogClockAccentChoice.accent2;
      case 3:
        return AnalogClockAccentChoice.accent3;
      case 1:
      default:
        return AnalogClockAccentChoice.accent1;
    }
  }
}

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
  AnalogClockDialLabelMode get _dialLabelMode =>
      AnalogClockDialLabelMode.fromConfigValue(widget.spec.config['dialLabels']);
  AnalogClockAccentChoice get _hourHandAccentChoice =>
      AnalogClockAccentChoice.fromConfigValue(
        widget.spec.config['hourHandAccent'],
        defaultChoice: AnalogClockAccentChoice.accent1,
      );
  AnalogClockAccentChoice get _minuteHandAccentChoice =>
      AnalogClockAccentChoice.fromConfigValue(
        widget.spec.config['minuteHandAccent'],
        defaultChoice: AnalogClockAccentChoice.accent2,
      );
  AnalogClockAccentChoice get _secondHandAccentChoice =>
      AnalogClockAccentChoice.fromConfigValue(
        widget.spec.config['secondHandAccent'],
        defaultChoice: AnalogClockAccentChoice.accent3,
      );

  Color _resolveAccentColor({
    required PaletteTertiaryLayers? palette,
    required AnalogClockAccentChoice choice,
    required Color fallback,
  }) {
    if (palette == null) {
      return fallback;
    }
    return switch (choice) {
      AnalogClockAccentChoice.accent1 => palette.accent1,
      AnalogClockAccentChoice.accent2 => palette.accent2,
      AnalogClockAccentChoice.accent3 => palette.accent3,
    };
  }

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
    final palette = widget.theme.extension<PaletteTertiaryLayers>();
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
              handHour: _resolveAccentColor(
                palette: palette,
                choice: _hourHandAccentChoice,
                fallback: scheme.secondary,
              ),
              handMinute: _resolveAccentColor(
                palette: palette,
                choice: _minuteHandAccentChoice,
                fallback: scheme.tertiary,
              ),
              handSecond: _resolveAccentColor(
                palette: palette,
                choice: _secondHandAccentChoice,
                fallback: scheme.outline,
              ),
              dialLabelMode: _dialLabelMode,
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
    this.dialLabelMode = AnalogClockDialLabelMode.none,
  });

  final ClockHandAngles angles;
  final double layoutScale;
  final Color dialColor;
  final Color faceColor;
  final Color handHour;
  final Color handMinute;
  final Color handSecond;
  final AnalogClockDialLabelMode dialLabelMode;

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
    _drawDialLabels(canvas, c, r, s);

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

  void _drawDialLabels(Canvas canvas, Offset center, double radius, double scale) {
    if (dialLabelMode == AnalogClockDialLabelMode.none) {
      return;
    }
    final textStyle = TextStyle(
      color: dialColor,
      fontSize: 22 * scale,
      fontWeight: FontWeight.w600,
    );
    for (var hour = 1; hour <= 12; hour++) {
      if (!dialLabelMode.includesHour(hour)) {
        continue;
      }
      final angle = 2 * math.pi * hour / 12.0;
      final labelCenter = Offset(
        center.dx + radius * 0.68 * math.sin(angle),
        center.dy - radius * 0.68 * math.cos(angle),
      );
      final textPainter = TextPainter(
        text: TextSpan(text: dialLabelMode.labelForHour(hour), style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final topLeft = Offset(
        labelCenter.dx - textPainter.width / 2,
        labelCenter.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, topLeft);
    }
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) {
    return oldDelegate.angles != angles ||
        oldDelegate.layoutScale != layoutScale ||
        oldDelegate.dialColor != dialColor ||
        oldDelegate.faceColor != faceColor ||
        oldDelegate.handHour != handHour ||
        oldDelegate.handMinute != handMinute ||
        oldDelegate.handSecond != handSecond ||
        oldDelegate.dialLabelMode != dialLabelMode;
  }
}
