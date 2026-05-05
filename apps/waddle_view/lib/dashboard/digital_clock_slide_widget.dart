import 'dart:async';

import 'package:flutter/material.dart';

import '../clock.dart';
import '../curator/screen_layout_parse.dart';
import 'clock_date_format.dart';

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatClockTime24(local),
            style: (widget.theme.textTheme.displayLarge ??
                    widget.theme.textTheme.headlineLarge)
                ?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
