import 'content_category_resolve.dart';
import 'database.dart';

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
    return normalizeMediaCategoryIds(raw.map((e) => e is String ? e : null));
  }
  return const [];
}

/// Maps integration config values ([ContentCategories.id] or display [label]) to ids.
Future<List<String>> resolveMediaCategoryIds(
  AppDatabase db,
  Iterable<String?> raw, {
  Map<String, String>? labelToIdCache,
  Set<String>? idSetCache,
}) async {
  return resolveContentCategoryIds(
    db,
    normalizeMediaCategoryIds(raw),
    labelToIdCache: labelToIdCache,
    idSetCache: idSetCache,
  );
}
