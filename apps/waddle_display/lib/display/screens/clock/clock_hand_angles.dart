import 'dart:math' as math;

/// Radians for clock hands; 0 = 12 o'clock, increasing clockwise (standard dial).
class ClockHandAngles {
  const ClockHandAngles({
    required this.hour,
    required this.minute,
    required this.second,
  });

  final double hour;
  final double minute;
  final double second;

  @override
  bool operator ==(Object other) {
    return other is ClockHandAngles &&
        other.hour == hour &&
        other.minute == minute &&
        other.second == second;
  }

  @override
  int get hashCode => Object.hash(hour, minute, second);

  factory ClockHandAngles.fromLocal(DateTime local) {
    final h = local.hour % 12 + local.minute / 60.0 + local.second / 3600.0;
    final m = local.minute + local.second / 60.0;
    final s = local.second.toDouble();
    return ClockHandAngles(
      hour: 2 * math.pi * h / 12.0,
      minute: 2 * math.pi * m / 60.0,
      second: 2 * math.pi * s / 60.0,
    );
  }
}
