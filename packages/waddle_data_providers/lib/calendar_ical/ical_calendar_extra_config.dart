import 'dart:convert';

import '../shared/calendar_provider_calendar_entry.dart';

class IcalFeedConfig {
  const IcalFeedConfig({
    required this.id,
    required this.url,
    this.label,
    this.categoryId,
    this.enabled = true,
  });

  final String id;
  final String url;
  final String? label;
  final String? categoryId;
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
    return IcalFeedConfig(
      id: id,
      url: url,
      label: label,
      categoryId: parseOptionalCategoryId(
        raw['categoryId'] ?? raw['category'],
      ),
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
        pastDays: 14,
        futureDays: 14,
      );
    }
    try {
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic>) {
        return const IcalCalendarExtraConfig(
          feeds: [],
          pastDays: 14,
          futureDays: 14,
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
        pastDays: _asInt(root['pastDays'], fallback: 14),
        futureDays: _asInt(root['futureDays'], fallback: 14),
      );
    } on Object {
      return const IcalCalendarExtraConfig(
        feeds: [],
        pastDays: 14,
        futureDays: 14,
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
