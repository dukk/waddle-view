/// Normalizes curator category ids: trim, drop empties, preserve first-seen order.
List<String> normalizeMediaCategoryIds(Iterable<String?> raw) {
  final out = <String>[];
  final seen = <String>{};
  for (final id in raw) {
    final t = id?.trim() ?? '';
    if (t.isEmpty || seen.contains(t)) {
      continue;
    }
    seen.add(t);
    out.add(t);
  }
  return out;
}

/// Parses `category`, `categoryId`, or `categoryIds` from integration JSON.
List<String> parseMediaConfigCategoryIds(Object? raw) {
  if (raw == null) {
    return const [];
  }
  if (raw is String) {
    return normalizeMediaCategoryIds([raw]);
  }
  if (raw is List<dynamic>) {
    return normalizeMediaCategoryIds(
      raw.map((e) => e is String ? e : null),
    );
  }
  return const [];
}
