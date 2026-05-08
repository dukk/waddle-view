/// One calendar filter (name or provider id) with optional forced [ContentCategories] id.
class ProviderCalendarEntry {
  const ProviderCalendarEntry({
    required this.nameOrId,
    this.categoryId,
  });

  final String nameOrId;
  final String? categoryId;

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
      final cat = raw['categoryId'];
      return ProviderCalendarEntry(
        nameOrId: cal.trim(),
        categoryId: cat is String && cat.trim().isNotEmpty ? cat.trim() : null,
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
  if (raw is! String) {
    return null;
  }
  final t = raw.trim();
  return t.isEmpty ? null : t;
}
