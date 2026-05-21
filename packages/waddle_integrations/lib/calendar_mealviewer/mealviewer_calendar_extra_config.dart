import 'dart:convert';

import 'package:waddle_shared/config/calendar_integration_defaults.dart';
import 'package:waddle_shared/config/mealviewer_kv.dart';
import 'package:waddle_shared/persistence/calendar_event_categories.dart';

class MealviewerSchoolConfig {
  const MealviewerSchoolConfig({
    required this.schoolSlug,
    required this.label,
    this.districtSlug,
    this.categoryIds = const [],
  });

  final String schoolSlug;
  final String label;
  final String? districtSlug;
  final List<String> categoryIds;

  static MealviewerSchoolConfig? parse(Map<String, dynamic> raw) {
    final slug = normalizeMealviewerSchoolSlug(
      (raw['schoolSlug'] as String?) ?? (raw['school_slug'] as String?),
    );
    if (slug == null || slug.isEmpty) {
      return null;
    }
    final labelRaw = raw['label'] as String?;
    final label = labelRaw != null && labelRaw.trim().isNotEmpty
        ? labelRaw.trim()
        : slug;
    final district = (raw['districtSlug'] as String?)?.trim();
    final districtSlug =
        district != null && district.isNotEmpty ? district : null;
    final categoryIds = normalizeCalendarEventCategoryIds([
      ...parseCalendarConfigCategoryIds(raw['categoryIds']),
      ...parseCalendarConfigCategoryIds(raw['categoryId'] ?? raw['category']),
    ]);
    return MealviewerSchoolConfig(
      schoolSlug: slug,
      label: label,
      districtSlug: districtSlug,
      categoryIds: categoryIds,
    );
  }
}

class MealviewerCalendarExtraConfig {
  const MealviewerCalendarExtraConfig({
    required this.baseUrl,
    required this.schools,
    required this.pastDays,
    required this.futureDays,
  });

  final String baseUrl;
  final List<MealviewerSchoolConfig> schools;
  final int pastDays;
  final int futureDays;

  static MealviewerCalendarExtraConfig parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const MealviewerCalendarExtraConfig(
        baseUrl: kMealviewerApiDefaultBaseUrl,
        schools: [],
        pastDays: kCalendarSyncPastFutureDaysDefault,
        futureDays: kCalendarSyncPastFutureDaysDefault,
      );
    }
    try {
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic>) {
        return const MealviewerCalendarExtraConfig(
          baseUrl: kMealviewerApiDefaultBaseUrl,
          schools: [],
          pastDays: kCalendarSyncPastFutureDaysDefault,
          futureDays: kCalendarSyncPastFutureDaysDefault,
        );
      }
      final schoolsRaw = root['schools'];
      final schools = <MealviewerSchoolConfig>[];
      if (schoolsRaw is List<dynamic>) {
        for (final s in schoolsRaw) {
          if (s is Map<String, dynamic>) {
            final parsed = MealviewerSchoolConfig.parse(s);
            if (parsed != null) {
              schools.add(parsed);
            }
          }
        }
      }
      final baseUrl = _normalizeBaseUrl(
        root['baseUrl'] as String? ?? root['base_url'] as String?,
      );
      return MealviewerCalendarExtraConfig(
        baseUrl: baseUrl,
        schools: schools,
        pastDays: _asInt(
          root['pastDays'],
          fallback: kCalendarSyncPastFutureDaysDefault,
        ),
        futureDays: _asInt(
          root['futureDays'],
          fallback: kCalendarSyncPastFutureDaysDefault,
        ),
      );
    } on Object {
      return const MealviewerCalendarExtraConfig(
        baseUrl: kMealviewerApiDefaultBaseUrl,
        schools: [],
        pastDays: kCalendarSyncPastFutureDaysDefault,
        futureDays: kCalendarSyncPastFutureDaysDefault,
      );
    }
  }
}

/// MealViewer school slugs omit spaces (see community clients).
String? normalizeMealviewerSchoolSlug(String? raw) {
  if (raw == null) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed.split(RegExp(r'\s+')).join('');
}

String _normalizeBaseUrl(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) {
    return kMealviewerApiDefaultBaseUrl;
  }
  return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
}

int _asInt(Object? v, {required int fallback}) {
  if (v is int && v > 0) {
    return v;
  }
  if (v is String) {
    final parsed = int.tryParse(v);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  return fallback;
}
