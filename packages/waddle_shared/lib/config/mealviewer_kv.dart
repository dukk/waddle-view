import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Integration type for MealViewer school lunch menu calendar sync.
const String kMealviewerCalendarProviderId = 'calendar_mealviewer';

/// Default MealViewer API host.
const String kMealviewerApiDefaultBaseUrl = 'https://api.mealviewer.com';

/// Prefix for [CalendarEvents.source] rows produced by a school slug.
String mealviewerCalendarEventSource(String schoolSlug) =>
    'mealviewer:$schoolSlug';

/// Stable [CalendarEvents.id] for a school menu block on a date.
String mealviewerCalendarEventRowId({
  required String schoolSlug,
  required String dateKey,
  required String blockKey,
}) {
  final bytes = utf8.encode(
    'mealviewer\x00$schoolSlug\x00$dateKey\x00$blockKey',
  );
  return sha256.convert(bytes).toString();
}

/// Normalizes a menu block name for stable external ids.
String mealviewerNormalizeBlockKey(String blockName) {
  final trimmed = blockName.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return 'menu';
  }
  return trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(
        RegExp(r'_+'),
        '_',
      );
}
