import 'dart:convert';

import 'display_overlay_clock_placement.dart';
import 'display_overlay_static_image_settings.dart';

/// Default scale for calendar month overlay (fraction of viewport shortest side).
const double kCalendarMonthOverlayScaleDefault = 0.22;

/// Resolved calendar month overlay settings from overlay `config_json`.
class CalendarMonthOverlaySettings {
  const CalendarMonthOverlaySettings({
    required this.placement,
    this.categoryId,
  });

  static final CalendarMonthOverlaySettings defaults =
      CalendarMonthOverlaySettings(
    placement: const ClockOverlayPlacement(
      x: kStaticImageOverlayPositionDefault,
      y: kStaticImageOverlayPositionDefault,
      scale: kCalendarMonthOverlayScaleDefault,
      opacity: 1.0,
    ),
  );

  final ClockOverlayPlacement placement;
  final String? categoryId;

  Map<String, dynamic> toJson() => {
        ...placement.toJson(),
        if (categoryId != null && categoryId!.isNotEmpty) 'categoryId': categoryId,
      };

  Map<String, dynamic> calendarConfigMap() => {
        if (categoryId != null && categoryId!.isNotEmpty) 'categoryId': categoryId,
      };

  static CalendarMonthOverlaySettings parse(String configJson) {
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

  static CalendarMonthOverlaySettings parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    final placement = ClockOverlayPlacement.parseMap(raw);
    final scale = placement.scale == kClockOverlayScaleDefault
        ? kCalendarMonthOverlayScaleDefault
        : placement.scale;
    final cat = raw['categoryId'];
    return CalendarMonthOverlaySettings(
      placement: ClockOverlayPlacement(
        x: placement.x,
        y: placement.y,
        scale: scale,
        opacity: placement.opacity,
      ),
      categoryId: cat is String && cat.trim().isNotEmpty ? cat.trim() : null,
    );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates calendar-month rules.
String? normalizeCalendarMonthOverlayConfigJsonString(String raw) {
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
  if (!_calendarMonthOverlayConfigMapValid(map)) {
    return null;
  }
  final settings = CalendarMonthOverlaySettings.parseMap(map);
  return jsonEncode(settings.toJson());
}

bool _calendarMonthOverlayConfigMapValid(Map<String, dynamic> map) {
  if (!validateClockOverlayPlacementMap(map)) {
    return false;
  }
  if (map.containsKey('categoryId') && map['categoryId'] is! String) {
    return false;
  }
  return true;
}
