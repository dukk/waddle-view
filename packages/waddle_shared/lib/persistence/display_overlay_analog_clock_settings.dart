import 'dart:convert';

import 'display_overlay_clock_placement.dart';

/// Allowed `dialLabels` values (matches analog clock screen schema).
const Set<String> kAnalogClockOverlayDialLabels = {
  'none',
  'numbers',
  'numeric',
  'roman',
  'roman_numerals',
  'cardinal_numbers',
  'cardinal',
  'crosshair_numbers',
};

/// Default dial label mode when unset or invalid.
const String kAnalogClockOverlayDialLabelsDefault = 'none';

/// Resolved analog clock overlay settings from overlay `config_json`.
class AnalogClockOverlaySettings {
  const AnalogClockOverlaySettings({
    required this.placement,
    required this.dialLabels,
    required this.hourHandAccent,
    required this.minuteHandAccent,
    required this.secondHandAccent,
  });

  static const AnalogClockOverlaySettings defaults = AnalogClockOverlaySettings(
    placement: ClockOverlayPlacement.defaults,
    dialLabels: kAnalogClockOverlayDialLabelsDefault,
    hourHandAccent: 'accent1',
    minuteHandAccent: 'accent2',
    secondHandAccent: 'accent3',
  );

  final ClockOverlayPlacement placement;
  final String dialLabels;
  final Object hourHandAccent;
  final Object minuteHandAccent;
  final Object secondHandAccent;

  Map<String, dynamic> toJson() => {
        ...placement.toJson(),
        if (dialLabels != kAnalogClockOverlayDialLabelsDefault)
          'dialLabels': dialLabels,
        if (hourHandAccent != 'accent1') 'hourHandAccent': hourHandAccent,
        if (minuteHandAccent != 'accent2') 'minuteHandAccent': minuteHandAccent,
        if (secondHandAccent != 'accent3') 'secondHandAccent': secondHandAccent,
      };

  Map<String, dynamic> clockConfigMap() => {
        if (dialLabels != kAnalogClockOverlayDialLabelsDefault)
          'dialLabels': dialLabels,
        if (hourHandAccent != 'accent1') 'hourHandAccent': hourHandAccent,
        if (minuteHandAccent != 'accent2') 'minuteHandAccent': minuteHandAccent,
        if (secondHandAccent != 'accent3') 'secondHandAccent': secondHandAccent,
      };

  static AnalogClockOverlaySettings parse(String configJson) {
    if (configJson.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is Map<String, dynamic>) {
        return parseMap(decoded);
      }
      if (decoded is Map) {
        return parseMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      /* fall through */
    }
    return defaults;
  }

  static AnalogClockOverlaySettings parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    return AnalogClockOverlaySettings(
      placement: ClockOverlayPlacement.parseMap(raw),
      dialLabels: _normalizeDialLabels(raw['dialLabels']),
      hourHandAccent: _normalizeHandAccent(
        raw['hourHandAccent'],
        defaultAccent: 'accent1',
      ),
      minuteHandAccent: _normalizeHandAccent(
        raw['minuteHandAccent'],
        defaultAccent: 'accent2',
      ),
      secondHandAccent: _normalizeHandAccent(
        raw['secondHandAccent'],
        defaultAccent: 'accent3',
      ),
    );
  }
}

String _normalizeDialLabels(Object? raw) {
  if (raw is! String) {
    return kAnalogClockOverlayDialLabelsDefault;
  }
  final normalized = raw.trim().toLowerCase();
  if (kAnalogClockOverlayDialLabels.contains(normalized)) {
    return normalized;
  }
  return kAnalogClockOverlayDialLabelsDefault;
}

Object _normalizeHandAccent(
  Object? raw, {
  required String defaultAccent,
}) {
  if (raw is int) {
    if (raw >= 1 && raw <= 3) {
      return raw;
    }
    return defaultAccent;
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return defaultAccent;
    }
    switch (normalized) {
      case 'accent1':
      case '1':
        return 'accent1';
      case 'accent2':
      case '2':
        return 'accent2';
      case 'accent3':
      case '3':
        return 'accent3';
    }
    final parsed = int.tryParse(normalized);
    if (parsed != null && parsed >= 1 && parsed <= 3) {
      return parsed;
    }
  }
  return defaultAccent;
}

/// Returns `null` when [raw] is not a JSON object or violates analog-clock rules.
String? normalizeAnalogClockOverlayConfigJsonString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '{}') {
    return '{}';
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on Object {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final map = decoded.cast<String, dynamic>();
  map.remove('messages');
  map.remove('message_interval_sec');
  map.remove('enabled');
  if (!_analogClockOverlayConfigMapValid(map)) {
    return null;
  }
  final settings = AnalogClockOverlaySettings.parseMap(map);
  return jsonEncode(settings.toJson());
}

bool _analogClockOverlayConfigMapValid(Map<String, dynamic> map) {
  if (!validateClockOverlayPlacementMap(map)) {
    return false;
  }
  if (map.containsKey('dialLabels') &&
      (map['dialLabels'] is! String ||
          !kAnalogClockOverlayDialLabels
              .contains((map['dialLabels'] as String).trim().toLowerCase()))) {
    return false;
  }
  for (final key in [
    'hourHandAccent',
    'minuteHandAccent',
    'secondHandAccent',
  ]) {
    if (!map.containsKey(key)) {
      continue;
    }
    final v = map[key];
    if (v is! String && v is! int) {
      return false;
    }
  }
  return true;
}
