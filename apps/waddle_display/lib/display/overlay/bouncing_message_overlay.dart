import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';

/// Reads layout [Size] from a laid-out [RenderBox], if available.
@visibleForTesting
Size? bouncingMessageRenderedSize(RenderBox? box) {
  if (box == null || !box.hasSize) {
    return null;
  }
  return box.size;
}

/// Integrates position and reflects velocity off layout walls (testable).
@visibleForTesting
({double x, double y, double vx, double vy}) integrateBouncingMessagePosition({
  required double x,
  required double y,
  required double vx,
  required double vy,
  required double dt,
  required double speed,
  required double areaW,
  required double areaH,
  required double textW,
  required double textH,
}) {
  if (areaW <= 1 || areaH <= 1 || textW <= 0 || textH <= 0) {
    return (x: x, y: y, vx: vx, vy: vy);
  }
  final maxX = (areaW - textW).clamp(0.0, double.infinity);
  final maxY = (areaH - textH).clamp(0.0, double.infinity);
  if (maxX <= 0 || maxY <= 0) {
    return (x: x, y: y, vx: vx, vy: vy);
  }

  var nx = x + vx * speed * dt;
  var ny = y + vy * speed * dt;
  var nvx = vx;
  var nvy = vy;

  if (nx < 0) {
    nx = 0;
    nvx = nvx.abs();
  } else if (nx > maxX) {
    nx = maxX;
    nvx = -nvx.abs();
  }
  if (ny < 0) {
    ny = 0;
    nvy = nvy.abs();
  } else if (ny > maxY) {
    ny = maxY;
    nvy = -nvy.abs();
  }
  return (x: nx, y: ny, vx: nvx, vy: nvy);
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
  final GlobalKey _textKey = GlobalKey();
  late final Ticker _ticker;
  Duration? _lastElapsed;
  double _x = 32;
  double _y = 48;
  double _vx = 92;
  double _vy = 68;
  Size _textSize = Size.zero;
  double _areaW = 0;
  double _areaH = 0;
  Object? _measureToken;
  bool _measurePending = false;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _vx = (r.nextBool() ? 1 : -1) * (78 + r.nextDouble() * 40);
    _vy = (r.nextBool() ? 1 : -1) * (56 + r.nextDouble() * 36);
    _ticker = createTicker(_onTick)..start();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant BouncingMessageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.settings != widget.settings ||
        oldWidget.fallbackColor != widget.fallbackColor) {
      _textSize = Size.zero;
      _measureToken = null;
      _scheduleMeasure();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _scheduleMeasure() {
    if (_measurePending) {
      return;
    }
    _measurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurePending = false;
      _syncTextSizeFromRender();
    });
  }

  void _syncTextSizeFromRender() {
    if (!mounted) {
      return;
    }
    final box = _textKey.currentContext?.findRenderObject();
    final size = bouncingMessageRenderedSize(
      box is RenderBox ? box : null,
    );
    if (size == null || size.isEmpty) {
      return;
    }
    if (size == _textSize) {
      return;
    }
    setState(() {
      _textSize = size;
      _clampPosition();
    });
  }

  void _clampPosition() {
    if (_textSize.isEmpty || _areaW <= 0 || _areaH <= 0) {
      return;
    }
    final maxX = (_areaW - _textSize.width).clamp(0.0, double.infinity);
    final maxY = (_areaH - _textSize.height).clamp(0.0, double.infinity);
    _x = _x.clamp(0.0, maxX);
    _y = _y.clamp(0.0, maxY);
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
    if (_textSize.isEmpty) {
      return;
    }
    final out = integrateBouncingMessagePosition(
      x: _x,
      y: _y,
      vx: _vx,
      vy: _vy,
      dt: dt,
      speed: widget.settings.speed,
      areaW: _areaW,
      areaH: _areaH,
      textW: _textSize.width,
      textH: _textSize.height,
    );
    _x = out.x;
    _y = out.y;
    _vx = out.vx;
    _vy = out.vy;
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
        final token = Object.hash(
          display,
          style.fontSize,
          style.fontWeight,
          style.letterSpacing,
          style.fontFamily,
          style.shadows,
          style.color,
          c.maxWidth,
          c.maxHeight,
          MediaQuery.textScalerOf(context),
        );
        if (token != _measureToken) {
          _measureToken = token;
          _scheduleMeasure();
        }

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              key: const Key('bouncing_message_positioned'),
              left: _x,
              top: _y,
              child: IgnorePointer(
                child: Text.rich(
                  key: _textKey,
                  TextSpan(text: display, style: style),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
