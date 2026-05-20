import 'dart:convert';

import 'package:waddle_shared/config/calendar_integration_defaults.dart';
import 'package:waddle_shared/persistence/calendar_event_categories.dart';

class IcalFeedConfig {
  const IcalFeedConfig({
    required this.id,
    required this.url,
    this.label,
    this.categoryIds = const [],
    this.enabled = true,
  });

  final String id;
  final String url;
  final String? label;
  final List<String> categoryIds;
  final bool enabled;

  static IcalFeedConfig? parse(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?)?.trim() ?? '';
    final url = (raw['url'] as String?)?.trim() ?? '';
    if (id.isEmpty || url.isEmpty) {
      return null;
    }
    final enabledRaw = raw['enabled'];
    final enabled = enabledRaw is bool ? enabledRaw : enabledRaw != false;
    final labelRaw = raw['label'];
    final label = labelRaw is String && labelRaw.trim().isNotEmpty
        ? labelRaw.trim()
        : null;
    final categoryIds = <String>[
      ...parseCalendarConfigCategoryIds(raw['categoryIds']),
      ...parseCalendarConfigCategoryIds(raw['categoryId'] ?? raw['category']),
    ];
    return IcalFeedConfig(
      id: id,
      url: url,
      label: label,
      categoryIds: normalizeCalendarEventCategoryIds(categoryIds),
      enabled: enabled,
    );
  }
}

class IcalCalendarExtraConfig {
  const IcalCalendarExtraConfig({
    required this.feeds,
    required this.pastDays,
    required this.futureDays,
  });

  final List<IcalFeedConfig> feeds;
  final int pastDays;
  final int futureDays;

  static IcalCalendarExtraConfig parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const IcalCalendarExtraConfig(
        feeds: [],
        pastDays: kCalendarSyncPastFutureDaysDefault,
        futureDays: kCalendarSyncPastFutureDaysDefault,
      );
    }
    try {
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic>) {
        return const IcalCalendarExtraConfig(
          feeds: [],
          pastDays: kCalendarSyncPastFutureDaysDefault,
          futureDays: kCalendarSyncPastFutureDaysDefault,
        );
      }
      final feedsRaw = root['feeds'];
      final feeds = <IcalFeedConfig>[];
      if (feedsRaw is List<dynamic>) {
        for (final f in feedsRaw) {
          if (f is Map<String, dynamic>) {
            final parsed = IcalFeedConfig.parse(f);
            if (parsed != null) {
              feeds.add(parsed);
            }
          }
        }
      }
      return IcalCalendarExtraConfig(
        feeds: feeds,
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
      return const IcalCalendarExtraConfig(
        feeds: [],
        pastDays: kCalendarSyncPastFutureDaysDefault,
        futureDays: kCalendarSyncPastFutureDaysDefault,
      );
    }
  }
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
