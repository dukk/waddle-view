import 'dart:convert';

import '../shared/calendar_provider_calendar_entry.dart';

class GoogleCalendarSourceConfig {
  const GoogleCalendarSourceConfig({
    required this.calendars,
    this.defaultCategoryId,
  });

  final List<ProviderCalendarEntry> calendars;
  final String? defaultCategoryId;

  static GoogleCalendarSourceConfig parse(Map<String, dynamic> s) {
    return GoogleCalendarSourceConfig(
      calendars: ProviderCalendarEntry.parseList(s['calendars']),
      defaultCategoryId: parseOptionalCategoryId(
        s['defaultCategoryId'] ?? s['defaultCategory'],
      ),
    );
  }
}

class GoogleCalendarAccountConfig {
  const GoogleCalendarAccountConfig({
    required this.googleAccountKey,
    required this.sources,
  });

  final String googleAccountKey;
  final List<GoogleCalendarSourceConfig> sources;
}

class GoogleCalendarExtraConfig {
  const GoogleCalendarExtraConfig({
    required this.accounts,
    required this.pastDays,
    required this.futureDays,
  });

  final List<GoogleCalendarAccountConfig> accounts;
  final int pastDays;
  final int futureDays;

  static GoogleCalendarExtraConfig parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const GoogleCalendarExtraConfig(
        accounts: [],
        pastDays: 14,
        futureDays: 14,
      );
    }
    try {
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic>) {
        return const GoogleCalendarExtraConfig(
          accounts: [],
          pastDays: 14,
          futureDays: 14,
        );
      }
      final accountsRaw = root['accounts'];
      final accounts = <GoogleCalendarAccountConfig>[];
      if (accountsRaw is List<dynamic>) {
        for (final a in accountsRaw) {
          if (a is! Map<String, dynamic>) {
            continue;
          }
          final accountKey = (a['googleAccountKey'] as String?)?.trim() ?? '';
          if (accountKey.isEmpty) {
            continue;
          }
          final sourcesRaw = a['sources'];
          final sources = <GoogleCalendarSourceConfig>[];
          if (sourcesRaw is List<dynamic>) {
            for (final s in sourcesRaw) {
              if (s is! Map<String, dynamic>) {
                continue;
              }
              sources.add(GoogleCalendarSourceConfig.parse(s));
            }
          }
          accounts.add(
            GoogleCalendarAccountConfig(
              googleAccountKey: accountKey,
              sources: sources,
            ),
          );
        }
      }
      return GoogleCalendarExtraConfig(
        accounts: accounts,
        pastDays: _asInt(root['pastDays'], fallback: 14),
        futureDays: _asInt(root['futureDays'], fallback: 14),
      );
    } on Object {
      return const GoogleCalendarExtraConfig(
        accounts: [],
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
