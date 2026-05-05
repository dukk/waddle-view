import 'dart:async';

import 'package:flutter/material.dart';

import '../clock.dart';
import '../curator/screen_layout_parse.dart';
import 'clock_date_format.dart';
import 'dashboard_viewport_scope.dart';

/// Full-slide digital clock with date (local time).
class DigitalClockSlideWidget extends StatefulWidget {
  const DigitalClockSlideWidget({
    super.key,
    required this.spec,
    required this.theme,
    this.clock = const SystemClock(),
  });

  final ParsedWidgetSpec spec;
  final ThemeData theme;
  final Clock clock;

  @override
  State<DigitalClockSlideWidget> createState() => _DigitalClockSlideWidgetState();
}

class _DigitalClockSlideWidgetState extends State<DigitalClockSlideWidget> {
  Timer? _timer;
  late DateTime _tick;

  bool get _hour24 => widget.spec.config['hour24'] == true;

  bool get _showSeconds => widget.spec.config['showSeconds'] == true;

  @override
  void initState() {
    super.initState();
    _tick = widget.clock.now().toLocal();
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    if (_showSeconds) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _tick = widget.clock.now().toLocal();
        });
      });
      return;
    }

    void tick() {
      if (!mounted) {
        return;
      }
      setState(() {
        _tick = widget.clock.now().toLocal();
      });
    }

    void scheduleAligned() {
      if (!mounted) {
        return;
      }
      final local = widget.clock.now().toLocal();
      final intoMinute = Duration(
        seconds: local.second,
        milliseconds: local.millisecond,
        microseconds: local.microsecond,
      );
      final untilNext = const Duration(minutes: 1) - intoMinute;
      _timer?.cancel();
      if (untilNext.inMicroseconds <= 0) {
        tick();
        _timer = Timer.periodic(const Duration(minutes: 1), (_) => tick());
      } else {
        _timer = Timer(untilNext, () {
          tick();
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(minutes: 1), (_) => tick());
        });
      }
    }

    scheduleAligned();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = _tick;
    final s = DashboardViewportScope.scaleOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatDigitalClockTime(
              local,
              hour24: _hour24,
              showSeconds: _showSeconds,
            ),
            style: (widget.theme.textTheme.displayLarge ??
                    widget.theme.textTheme.headlineLarge)
                ?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
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
