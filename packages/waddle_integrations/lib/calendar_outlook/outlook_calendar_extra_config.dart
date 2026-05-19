import 'dart:convert';

import 'package:waddle_shared/config/calendar_integration_defaults.dart';

import '../shared/calendar_provider_calendar_entry.dart';

/// One mailbox (UPN or `me`) and optional calendar display names or Graph ids.
class OutlookMailboxSource {
  const OutlookMailboxSource({
    required this.mailbox,
    required this.calendars,
    this.defaultCategoryIds = const [],
    this.categoryMap = const {},
  });

  final String mailbox;
  /// Display names or calendar `id` strings. Empty means the user's default calendar only.
  final List<ProviderCalendarEntry> calendars;
  /// Applied to events from the default calendar when [calendars] is empty.
  final List<String> defaultCategoryIds;
  /// Outlook event `categories` labels → [ContentCategories.id].
  final Map<String, String> categoryMap;

  static OutlookMailboxSource? parse(Map<String, dynamic> m) {
    final box = m['mailbox'] ?? m['email'];
    if (box is! String || box.trim().isEmpty) {
      return null;
    }
    return OutlookMailboxSource(
      mailbox: box.trim(),
      calendars: ProviderCalendarEntry.parseList(m['calendars']),
      defaultCategoryIds: parseDefaultCategoryIds(m),
      categoryMap: parseCategoryAliasMap(m['categoryMap']),
    );
  }
}

/// One Microsoft identity (device-code / token pair) and its mailboxes to read.
class OutlookAccountConfig {
  const OutlookAccountConfig({
    required this.graphAccountKey,
    required this.sources,
  });

  final String graphAccountKey;
  final List<OutlookMailboxSource> sources;

  static OutlookAccountConfig? parse(Map<String, dynamic> m) {
    final key = m['graphAccountKey'];
    if (key is! String || key.trim().isEmpty) {
      return null;
    }
    final sources = <OutlookMailboxSource>[];
    final raw = m['sources'];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final s = OutlookMailboxSource.parse(e);
          if (s != null) {
            sources.add(s);
          }
        }
      }
    }
    return OutlookAccountConfig(
      graphAccountKey: key.trim(),
      sources: sources,
    );
  }
}

class OutlookCalendarExtraConfig {
  const OutlookCalendarExtraConfig({
    required this.accounts,
    required this.pastDays,
    required this.futureDays,
  });

  final List<OutlookAccountConfig> accounts;
  final int pastDays;
  final int futureDays;

  static OutlookCalendarExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const OutlookCalendarExtraConfig(
        accounts: [],
        pastDays: kCalendarSyncPastFutureDaysDefault,
        futureDays: kCalendarSyncPastFutureDaysDefault,
      );
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      final accounts = <OutlookAccountConfig>[];
      final rawAccounts = m['accounts'];
      if (rawAccounts is List<dynamic>) {
        for (final e in rawAccounts) {
          if (e is Map<String, dynamic>) {
            final a = OutlookAccountConfig.parse(e);
            if (a != null) {
              accounts.add(a);
            }
          }
        }
      }
      return OutlookCalendarExtraConfig(
        accounts: accounts,
        pastDays: _positiveInt(m['pastDays'], kCalendarSyncPastFutureDaysDefault),
        futureDays: _positiveInt(m['futureDays'], kCalendarSyncPastFutureDaysDefault),
      );
    } on Object {
      return parse(null);
    }
  }
}

int _positiveInt(Object? v, int fallback) {
  if (v is int && v > 0) {
    return v;
  }
  if (v is num && v.toInt() > 0) {
    return v.toInt();
  }
  return fallback;
}
