class RuntimeSignalUpdate {
  const RuntimeSignalUpdate(this.value);

  factory RuntimeSignalUpdate.boolValue(bool v) => RuntimeSignalUpdate(v);

  final Object value;

  Map<String, dynamic> toJson() {
    if (value is bool) {
      return {'bool': value};
    }
    if (value is num) {
      return {'number': value};
    }
    return {'value': value};
  }
}

abstract final class SignalIds {
  static const motionDetected = 'room.motion_detected';
  static const beaconPresent = 'beacon.present';
  static const alarmActive = 'alarm.active';
}
