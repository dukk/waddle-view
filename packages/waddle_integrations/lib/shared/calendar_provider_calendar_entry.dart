import 'package:waddle_shared/persistence/calendar_event_categories.dart';

/// One calendar filter (name or provider id) with optional forced [ContentCategories] ids.
class ProviderCalendarEntry {
  const ProviderCalendarEntry({
    required this.nameOrId,
    this.categoryIds = const [],
  });

  final String nameOrId;
  final List<String> categoryIds;

  /// First configured category (legacy single-column / primary assignment).
  String? get categoryId =>
      categoryIds.isEmpty ? null : categoryIds.first;

  static ProviderCalendarEntry? parse(dynamic raw) {
    if (raw is String) {
      final t = raw.trim();
      return t.isEmpty ? null : ProviderCalendarEntry(nameOrId: t);
    }
    if (raw is Map<String, dynamic>) {
      final cal = raw['calendar'] ?? raw['name'] ?? raw['id'];
      if (cal is! String || cal.trim().isEmpty) {
        return null;
      }
      final ids = <String>[
        ...parseCalendarConfigCategoryIds(raw['categoryIds']),
        ...parseCalendarConfigCategoryIds(raw['categoryId'] ?? raw['category']),
      ];
      return ProviderCalendarEntry(
        nameOrId: cal.trim(),
        categoryIds: normalizeCalendarEventCategoryIds(ids),
      );
    }
    return null;
  }

  static List<ProviderCalendarEntry> parseList(Object? raw) {
    if (raw is! List<dynamic>) {
      return const [];
    }
    final out = <ProviderCalendarEntry>[];
    for (final e in raw) {
      final p = parse(e);
      if (p != null) {
        out.add(p);
      }
    }
    return out;
  }
}

/// Maps provider-native category labels (e.g. Outlook preset names) to [ContentCategories.id].
Map<String, String> parseCategoryAliasMap(Object? raw) {
  final out = <String, String>{};
  if (raw is! Map) {
    return out;
  }
  raw.forEach((k, v) {
    if (k is String && v is String) {
      final kk = k.trim();
      final vv = v.trim();
      if (kk.isNotEmpty && vv.isNotEmpty) {
        out[kk] = vv;
      }
    }
  });
  return out;
}

String? parseOptionalCategoryId(Object? raw) {
  final ids = parseCalendarConfigCategoryIds(raw);
  return ids.isEmpty ? null : ids.first;
}

/// Parses `defaultCategoryId` / `defaultCategory` / `defaultCategoryIds` from source config.
List<String> parseDefaultCategoryIds(Map<String, dynamic> m) {
  final ids = <String>[
    ...parseCalendarConfigCategoryIds(m['defaultCategoryIds']),
    ...parseCalendarConfigCategoryIds(
      m['defaultCategoryId'] ?? m['defaultCategory'],
    ),
  ];
  return normalizeCalendarEventCategoryIds(ids);
}
