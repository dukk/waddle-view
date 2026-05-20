import 'dart:convert';

import 'display_overlay_clock_placement.dart';
import 'display_overlay_static_image_settings.dart';

/// Default scale for calendar upcoming overlay.
const double kCalendarUpcomingOverlayScaleDefault = 0.28;

/// Default horizontal anchor (right edge).
const double kCalendarUpcomingOverlayPositionXDefault = 0.72;

/// Minimum [CalendarUpcomingOverlaySettings.upcomingDays].
const int kCalendarUpcomingOverlayDaysMin = 1;

/// Maximum [CalendarUpcomingOverlaySettings.upcomingDays].
const int kCalendarUpcomingOverlayDaysMax = 14;

/// Default upcoming window length in days.
const int kCalendarUpcomingOverlayDaysDefault = 5;

/// Resolved calendar upcoming overlay settings from overlay `config_json`.
class CalendarUpcomingOverlaySettings {
  const CalendarUpcomingOverlaySettings({
    required this.placement,
    this.categoryId,
    this.upcomingTime12Hour = true,
    this.upcomingTimeNoonLabel = 'Noon',
    this.upcomingTimeWidthCompact = 132,
    this.upcomingTimeWidth = 156,
    this.upcomingDays = kCalendarUpcomingOverlayDaysDefault,
  });

  static final CalendarUpcomingOverlaySettings defaults =
      CalendarUpcomingOverlaySettings(
    placement: const ClockOverlayPlacement(
      x: kCalendarUpcomingOverlayPositionXDefault,
      y: kStaticImageOverlayPositionDefault,
      scale: kCalendarUpcomingOverlayScaleDefault,
      opacity: 1.0,
    ),
  );

  final ClockOverlayPlacement placement;
  final String? categoryId;
  final bool upcomingTime12Hour;
  final String upcomingTimeNoonLabel;
  final double upcomingTimeWidthCompact;
  final double upcomingTimeWidth;
  final int upcomingDays;

  Map<String, dynamic> toJson() => {
        ...placement.toJson(),
        if (categoryId != null && categoryId!.isNotEmpty) 'categoryId': categoryId,
        if (!upcomingTime12Hour) 'upcomingTime12Hour': false,
        if (upcomingTimeNoonLabel != 'Noon')
          'upcomingTimeNoonLabel': upcomingTimeNoonLabel,
        if (upcomingTimeWidthCompact != 132)
          'upcomingTimeWidthCompact': upcomingTimeWidthCompact,
        if (upcomingTimeWidth != 156) 'upcomingTimeWidth': upcomingTimeWidth,
        if (upcomingDays != kCalendarUpcomingOverlayDaysDefault)
          'upcomingDays': upcomingDays,
      };

  Map<String, dynamic> calendarConfigMap() => {
        if (categoryId != null && categoryId!.isNotEmpty) 'categoryId': categoryId,
        if (!upcomingTime12Hour) 'upcomingTime12Hour': false,
        if (upcomingTimeNoonLabel != 'Noon')
          'upcomingTimeNoonLabel': upcomingTimeNoonLabel,
        if (upcomingTimeWidthCompact != 132)
          'upcomingTimeWidthCompact': upcomingTimeWidthCompact,
        if (upcomingTimeWidth != 156) 'upcomingTimeWidth': upcomingTimeWidth,
        'upcomingDays': upcomingDays,
      };

  static CalendarUpcomingOverlaySettings parse(String configJson) {
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

  static CalendarUpcomingOverlaySettings parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    var placement = ClockOverlayPlacement.parseMap(raw);
    // Clock parseMap defaults (0.05, 0.05, 0.2) or static anchor + calendar scale
    // without right-edge x — apply full calendar-upcoming placement (0.72, 0.05, 0.28).
    if (placement.x == kStaticImageOverlayPositionDefault &&
        placement.y == kStaticImageOverlayPositionDefault &&
        (placement.scale == kClockOverlayScaleDefault ||
            placement.scale == kCalendarUpcomingOverlayScaleDefault)) {
      placement = defaults.placement;
    } else if (placement.scale == kClockOverlayScaleDefault) {
      placement = ClockOverlayPlacement(
        x: placement.x,
        y: placement.y,
        scale: kCalendarUpcomingOverlayScaleDefault,
        opacity: placement.opacity,
      );
    }
    final cat = raw['categoryId'];
    return CalendarUpcomingOverlaySettings(
      placement: placement,
      categoryId: cat is String && cat.trim().isNotEmpty ? cat.trim() : null,
      upcomingTime12Hour: raw['upcomingTime12Hour'] is bool
          ? raw['upcomingTime12Hour'] as bool
          : true,
      upcomingTimeNoonLabel: _parseNoonLabel(raw['upcomingTimeNoonLabel']),
      upcomingTimeWidthCompact: _parsePositiveDouble(
        raw['upcomingTimeWidthCompact'],
        132,
      ),
      upcomingTimeWidth: _parsePositiveDouble(raw['upcomingTimeWidth'], 156),
      upcomingDays: _parseUpcomingDays(raw['upcomingDays']),
    );
  }
}

String _parseNoonLabel(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return 'Noon';
}

double _parsePositiveDouble(Object? raw, double fallback) {
  final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (v == null || !v.isFinite || v <= 0) {
    return fallback;
  }
  return v;
}

int _parseUpcomingDays(Object? raw) {
  final v = raw is int ? raw : int.tryParse('$raw');
  if (v == null) {
    return kCalendarUpcomingOverlayDaysDefault;
  }
  return v.clamp(kCalendarUpcomingOverlayDaysMin, kCalendarUpcomingOverlayDaysMax);
}

/// Returns `null` when [raw] is not a JSON object or violates calendar-upcoming rules.
String? normalizeCalendarUpcomingOverlayConfigJsonString(String raw) {
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
  if (!_calendarUpcomingOverlayConfigMapValid(map)) {
    return null;
  }
  final settings = CalendarUpcomingOverlaySettings.parseMap(map);
  return jsonEncode(settings.toJson());
}

bool _calendarUpcomingOverlayConfigMapValid(Map<String, dynamic> map) {
  if (!validateClockOverlayPlacementMap(map)) {
    return false;
  }
  if (map.containsKey('categoryId') && map['categoryId'] is! String) {
    return false;
  }
  if (map.containsKey('upcomingTime12Hour') &&
      map['upcomingTime12Hour'] is! bool) {
    return false;
  }
  if (map.containsKey('upcomingTimeNoonLabel') &&
      map['upcomingTimeNoonLabel'] is! String) {
    return false;
  }
  for (final key in ['upcomingTimeWidthCompact', 'upcomingTimeWidth']) {
    if (map.containsKey(key) && map[key] is! num) {
      return false;
    }
  }
  if (map.containsKey('upcomingDays') && map['upcomingDays'] is! int) {
    return false;
  }
  return true;
}
