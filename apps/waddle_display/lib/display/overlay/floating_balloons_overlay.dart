import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_floating_balloons_settings.dart';

import 'balloon_overlay_draw.dart';

/// Rising vector balloons with animated strings and optional clusters.
class FloatingBalloonsOverlay extends StatefulWidget {
  const FloatingBalloonsOverlay({
    super.key,
    required this.settings,
  });

  final FloatingBalloonsScheduleSettings settings;

  @override
  State<FloatingBalloonsOverlay> createState() => _FloatingBalloonsOverlayState();
}

class _BalloonUnit {
  _BalloonUnit({
    required this.id,
    required this.centerXFraction,
    required this.balloonSize,
    required this.colors,
    required this.layoutOffsets,
    required this.sizeFactors,
    required this.stringPhases,
    required this.driftPhase,
    required this.startedAt,
  });

  final int id;
  final double centerXFraction;
  final double balloonSize;
  final List<Color> colors;
  final List<BalloonClusterOffset> layoutOffsets;
  final List<double> sizeFactors;
  final List<double> stringPhases;
  final double driftPhase;
  final DateTime startedAt;
}

class _FloatingBalloonsOverlayState extends State<FloatingBalloonsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final _units = <_BalloonUnit>[];
  final _rand = math.Random();
  Timer? _spawnTimer;
  Size _viewport = Size.zero;
  int _nextUnitId = 0;
  late List<Color> _palette;

  @override
  void initState() {
    super.initState();
    _palette = _resolvePalette(widget.settings);
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(() {
        if (mounted) {
          setState(_pruneFinishedUnits);
        }
      })
      ..repeat();
    _scheduleNextSpawn();
  }

  @override
  void didUpdateWidget(covariant FloatingBalloonsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _palette = _resolvePalette(widget.settings);
    if (oldWidget.settings.spawnIntervalSec !=
        widget.settings.spawnIntervalSec) {
      _spawnTimer?.cancel();
      _scheduleNextSpawn();
    }
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  List<Color> _resolvePalette(FloatingBalloonsScheduleSettings settings) {
    final out = <Color>[];
    for (final hex in settings.effectiveColorHexes) {
      final c = parseBalloonOverlayHexColor(hex);
      if (c != null) {
        out.add(c);
      }
    }
    return out;
  }

  void _scheduleNextSpawn() {
    final base = widget.settings.spawnIntervalSec.toDouble();
    final delaySec = base * (0.75 + _rand.nextDouble() * 0.5);
    _spawnTimer = Timer(
      Duration(milliseconds: (delaySec * 1000).round()),
      () {
        if (!mounted) {
          return;
        }
        _maybeSpawn();
        _scheduleNextSpawn();
      },
    );
  }

  void _maybeSpawn() {
    if (_viewport == Size.zero || _palette.isEmpty) {
      return;
    }
    if (_units.length >= widget.settings.maxActive) {
      return;
    }
    final clusterSize = pickFloatingBalloonClusterSize(
      _rand,
      clusterChance: widget.settings.clusterChance,
    );
    final hexColors = pickFloatingBalloonClusterColors(
      widget.settings.effectiveColorHexes,
      clusterSize,
      _rand,
    );
    final colors = <Color>[];
    for (final hex in hexColors) {
      final c = parseBalloonOverlayHexColor(hex);
      if (c != null) {
        colors.add(c);
      }
    }
    if (colors.isEmpty) {
      return;
    }
    final layouts = randomFloatingBalloonClusterLayoutOffsets(
      colors.length,
      _rand,
    );
    final sizeFactors = List<double>.generate(
      colors.length,
      (_) => 0.86 + _rand.nextDouble() * 0.28,
    );
    final order = List<int>.generate(colors.length, (i) => i)..shuffle(_rand);
    final phases = List<double>.generate(
      colors.length,
      (_) => _rand.nextDouble() * math.pi * 2,
    );
    final shuffledColors = [for (final i in order) colors[i]];
    final shuffledLayouts = [for (final i in order) layouts[i]];
    final shuffledSizes = [for (final i in order) sizeFactors[i]];
    final shuffledPhases = [for (final i in order) phases[i]];
    final base = _viewport.shortestSide * widget.settings.balloonScale;
    final jitter = widget.settings.scaleJitter;
    final factor = jitter <= 0
        ? 1.0
        : 1.0 - jitter + 2 * jitter * _rand.nextDouble();
    final size = base * factor;
    _units.add(
      _BalloonUnit(
        id: _nextUnitId++,
        centerXFraction: 0.1 + _rand.nextDouble() * 0.8,
        balloonSize: size,
        colors: shuffledColors,
        layoutOffsets: shuffledLayouts,
        sizeFactors: shuffledSizes,
        stringPhases: shuffledPhases,
        driftPhase: _rand.nextDouble() * math.pi * 2,
        startedAt: DateTime.now(),
      ),
    );
  }

  void _pruneFinishedUnits() {
    if (_viewport == Size.zero) {
      return;
    }
    final risePxPerSec = widget.settings.riseSpeed;
    final now = DateTime.now();
    _units.removeWhere((unit) {
      final elapsed =
          now.difference(unit.startedAt).inMilliseconds / 1000.0;
      final centerY = _clusterCenterY(unit, elapsed, risePxPerSec);
      final stringDrop = balloonClusterStringDropFromLayouts(
        unit.layoutOffsets,
        unit.balloonSize,
        unit.sizeFactors,
      );
      final bottom = balloonClusterBottomY(
        clusterCenterY: centerY,
        balloonSize: unit.balloonSize,
        layouts: unit.layoutOffsets,
        sizeFactors: unit.sizeFactors,
        stringDrop: stringDrop,
      );
      // Remove only after the whole cluster (strings included) has cleared the top.
      return bottom < 0;
    });
  }

  double _clusterCenterY(
    _BalloonUnit unit,
    double elapsedSec,
    double risePxPerSec,
  ) {
    final startY = _viewport.height + unit.balloonSize * 1.4;
    return startY - elapsedSec * risePxPerSec;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final risePxPerSec = widget.settings.riseSpeed;
        final now = DateTime.now();
        final timeSec = _ticker.value * 86400;

        return CustomPaint(
          key: const Key('floating_balloons_paint'),
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _FloatingBalloonsPainter(
            units: _units,
            viewport: _viewport,
            risePxPerSec: risePxPerSec,
            layerOpacity: widget.settings.opacity,
            now: now,
            timeSec: timeSec,
          ),
        );
      },
    );
  }
}

class _FloatingBalloonsPainter extends CustomPainter {
  _FloatingBalloonsPainter({
    required this.units,
    required this.viewport,
    required this.risePxPerSec,
    required this.layerOpacity,
    required this.now,
    required this.timeSec,
  });

  final List<_BalloonUnit> units;
  final Size viewport;
  final double risePxPerSec;
  final double layerOpacity;
  final DateTime now;
  final double timeSec;

  @override
  void paint(Canvas canvas, Size size) {
    for (final unit in units) {
      final elapsed =
          now.difference(unit.startedAt).inMilliseconds / 1000.0;
      final sway = math.sin(elapsed * 0.9 + unit.driftPhase) * 18;
      final centerX = unit.centerXFraction * viewport.width + sway;
      final startY = viewport.height + unit.balloonSize * 1.4;
      final centerY = startY - elapsed * risePxPerSec;
      final center = Offset(centerX, centerY);
      final stringDrop = balloonClusterStringDropFromLayouts(
        unit.layoutOffsets,
        unit.balloonSize,
        unit.sizeFactors,
      );
      paintBalloonCluster(
        canvas: canvas,
        clusterCenter: center,
        balloonSize: unit.balloonSize,
        colors: unit.colors,
        layouts: unit.layoutOffsets,
        sizeFactors: unit.sizeFactors,
        stringPhases: unit.stringPhases,
        layerOpacity: layerOpacity,
        timeSec: timeSec,
        stringDrop: stringDrop,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingBalloonsPainter oldDelegate) => true;
}
