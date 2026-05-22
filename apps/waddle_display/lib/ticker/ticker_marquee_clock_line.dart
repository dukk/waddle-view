import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../clock.dart';
import '../config/display_timezone.dart';
import '../curator/ticker_item.dart';
import '../display/screens/clock/clock_date_format.dart';

/// Live-updating clock line for the ticker marquee (seconds tick while scrolling).
class TickerMarqueeClockLine extends StatefulWidget {
  const TickerMarqueeClockLine({
    super.key,
    required this.timeDisplay,
    required this.baseStyle,
    this.clock = const SystemClock(),
  });

  final TickerTimeDisplay timeDisplay;
  final TextStyle? baseStyle;
  final Clock clock;

  @override
  State<TickerMarqueeClockLine> createState() => _TickerMarqueeClockLineState();
}

class _TickerMarqueeClockLineState extends State<TickerMarqueeClockLine> {
  Timer? _timer;
  late DateTime _tick;

  @override
  void initState() {
    super.initState();
    _tick = _nowForDisplay();
    _armTimer();
  }

  @override
  void didUpdateWidget(TickerMarqueeClockLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeDisplay != widget.timeDisplay) {
      _tick = _nowForDisplay();
      _armTimer();
    }
  }

  DateTime _nowForDisplay() {
    final zone = widget.timeDisplay.timeZone?.trim();
    if (zone == null || zone.isEmpty) {
      return widget.clock.now().toLocal();
    }
    final loc = resolveDisplayTimeZoneLocation(zone);
    return tz.TZDateTime.from(widget.clock.now().toUtc(), loc);
  }

  void _armTimer() {
    _timer?.cancel();
    if (!tickerTimePresetShowsSeconds(widget.timeDisplay.timeFormatPreset)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tick = _nowForDisplay();
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
    final formatted =
        formatTickerTimePreset(_tick, widget.timeDisplay.timeFormatPreset);
    final prefix = widget.timeDisplay.labelPrefix?.trim() ?? '';
    final text = prefix.isEmpty ? formatted : '$prefix $formatted';
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: widget.baseStyle?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
