import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'kv_widget_base.dart';

class KvGaugeSlideWidget extends StatelessWidget {
  const KvGaugeSlideWidget({
    super.key,
    required this.db,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final min = cfgDouble(spec.config, 'min') ?? 0;
    final max = cfgDouble(spec.config, 'max') ?? 100;
    final unit = cfgString(spec.config, 'unit') ?? '';
    final valuePath = cfgString(spec.config, 'valuePath');

    return KvWidgetBase(
      db: db,
      spec: spec,
      theme: theme,
      builder: (context, value, error) {
        var reading = value;
        if (valuePath != null && value is Map) {
          reading = value[valuePath.replaceFirst(r'$.', '')] ?? value;
        }
        final v = _readNumber(reading);
        if (v == null) {
          return Text('Invalid gauge value', style: theme.textTheme.bodyMedium);
        }
        final span = (max - min).abs() < 0.001 ? 1.0 : (max - min);
        final t = ((v - min) / span).clamp(0.0, 1.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _GaugePainter(
                  progress: t,
                  color: theme.colorScheme.primary,
                  trackColor: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}$unit',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double? _readNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is Map) {
      final inner = value['value'];
      if (inner is num) {
        return inner.toDouble();
      }
    }
    return null;
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
