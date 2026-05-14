import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';

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

FontWeight _fontWeightFromValue(int v) {
  final s = (v ~/ 100 * 100).clamp(100, 900);
  return switch (s) {
    100 => FontWeight.w100,
    200 => FontWeight.w200,
    300 => FontWeight.w300,
    400 => FontWeight.w400,
    500 => FontWeight.w500,
    600 => FontWeight.w600,
    700 => FontWeight.w700,
    800 => FontWeight.w800,
    _ => FontWeight.w900,
  };
}

/// One line of text bouncing inside the layout bounds (edges act like walls).
class BouncingMessageOverlay extends StatefulWidget {
  const BouncingMessageOverlay({
    super.key,
    required this.settings,
    required this.text,
    required this.fallbackColor,
  });

  final BouncingMessageScheduleSettings settings;
  final String text;
  final Color fallbackColor;

  @override
  State<BouncingMessageOverlay> createState() => _BouncingMessageOverlayState();
}

class _BouncingMessageOverlayState extends State<BouncingMessageOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _lastElapsed;
  double _x = 32;
  double _y = 48;
  double _vx = 92;
  double _vy = 68;
  Size _textSize = Size.zero;
  double _areaW = 0;
  double _areaH = 0;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _vx = (r.nextBool() ? 1 : -1) * (78 + r.nextDouble() * 40);
    _vy = (r.nextBool() ? 1 : -1) * (56 + r.nextDouble() * 36);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) {
      return;
    }
    final last = _lastElapsed;
    _lastElapsed = elapsed;
    final rawDt = last == null ? 0.0 : (elapsed - last).inMicroseconds / 1e6;
    if (rawDt <= 0) {
      return;
    }
    final dt = rawDt.clamp(0.001, 0.05);
    _integrate(dt);
    setState(() {});
  }

  void _integrate(double dt) {
    final sp = widget.settings.speed;
    if (_areaW <= 1 || _areaH <= 1 || _textSize.isEmpty) {
      return;
    }
    final maxX = (_areaW - _textSize.width).clamp(0.0, double.infinity);
    final maxY = (_areaH - _textSize.height).clamp(0.0, double.infinity);
    if (maxX <= 0 || maxY <= 0) {
      return;
    }

    _x += _vx * sp * dt;
    _y += _vy * sp * dt;

    if (_x < 0) {
      _x = 0;
      _vx = _vx.abs();
    } else if (_x > maxX) {
      _x = maxX;
      _vx = -_vx.abs();
    }
    if (_y < 0) {
      _y = 0;
      _vy = _vy.abs();
    } else if (_y > maxY) {
      _y = maxY;
      _vy = -_vy.abs();
    }
  }

  TextStyle _textStyle(BuildContext context) {
    Color color = widget.fallbackColor;
    final hex = widget.settings.colorHex;
    if (hex != null) {
      final c = _colorFromHex(hex);
      if (c != null) {
        color = c;
      }
    }
    final fam = widget.settings.fontFamily;
    return TextStyle(
      fontFamily: fam == null || fam.isEmpty ? null : fam,
      fontSize: widget.settings.fontSize,
      fontWeight: _fontWeightFromValue(widget.settings.fontWeightValue),
      letterSpacing: widget.settings.letterSpacing,
      color: color,
      height: 1.1,
      shadows: widget.settings.shadow
          ? const [
              Shadow(
                blurRadius: 14,
                color: Color.fromRGBO(0, 0, 0, 0.35),
                offset: Offset(1, 2),
              ),
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.text.trim().isEmpty ? ' ' : widget.text;
    return LayoutBuilder(
      builder: (context, c) {
        _areaW = c.maxWidth;
        _areaH = c.maxHeight;
        final style = _textStyle(context);
        final tp = TextPainter(
          text: TextSpan(text: display, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 3,
        )..layout(maxWidth: c.maxWidth * 0.92);
        _textSize = Size(tp.width, tp.height);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              key: const Key('bouncing_message_positioned'),
              left: _x,
              top: _y,
              child: IgnorePointer(
                child: Text.rich(
                  TextSpan(text: display, style: style),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
