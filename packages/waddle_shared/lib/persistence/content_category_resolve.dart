import 'package:drift/drift.dart';

import 'database.dart';

/// Sync resolver when [labelToId] is already loaded (curator / tests).
String? resolveCategoryIdFromConfigMap(
  Map<String, dynamic> config,
  Map<String, String> labelToId,
) {
  final names = config['categoryNames'];
  if (names is List) {
    for (final raw in names) {
      if (raw is! String || raw.trim().isEmpty) continue;
      final t = raw.trim();
      return labelToId[t] ?? t;
    }
  }
  final single = config['categoryName'] ?? config['categoryId'];
  if (single is String && single.trim().isNotEmpty) {
    final t = single.trim();
    return labelToId[t] ?? t;
  }
  return null;
}

/// All category ids from config (names resolved via [labelToId]).
List<String> resolveCategoryIdsFromConfigMap(
  Map<String, dynamic> config,
  Map<String, String> labelToId,
) {
  final names = config['categoryNames'];
  if (names is List && names.isNotEmpty) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in names) {
      if (raw is! String || raw.trim().isEmpty) continue;
      final t = raw.trim();
      final id = labelToId[t] ?? t;
      if (seen.add(id)) out.add(id);
    }
    return out;
  }
  final single = resolveCategoryIdFromConfigMap(config, labelToId);
  if (single != null) {
    return [single];
  }
  return const [];
}

/// Resolves a stored category reference (display [label] or legacy [id]) to
/// [ContentCategories.id], or null when empty / unknown.
Future<String?> resolveContentCategoryId(
  AppDatabase db,
  String? raw, {
  Map<String, String>? labelToIdCache,
  Set<String>? idSetCache,
}) async {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) {
    return null;
  }
  final labelToId = labelToIdCache ?? await _loadLabelToId(db);
  final byLabel = labelToId[t];
  if (byLabel != null) {
    return byLabel;
  }
  final ids = idSetCache ?? await _loadIdSet(db);
  if (ids.contains(t)) {
    return t;
  }
  return null;
}

/// Resolves a list of category names/ids to distinct canonical ids (order preserved).
Future<List<String>> resolveContentCategoryIds(
  AppDatabase db,
  Iterable<String?> raw, {
  Map<String, String>? labelToIdCache,
  Set<String>? idSetCache,
}) async {
  final labelToId = labelToIdCache ?? await _loadLabelToId(db);
  final ids = idSetCache ?? await _loadIdSet(db);
  final out = <String>[];
  final seen = <String>{};
  for (final item in raw) {
    final t = item?.trim() ?? '';
    if (t.isEmpty) {
      continue;
    }
    final id = labelToId[t] ?? (ids.contains(t) ? t : null);
    if (id == null || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    out.add(id);
  }
  return out;
}

/// Reads `categoryName`, `categoryNames`, or legacy `categoryId` / `categoryIds`
/// from screen/overlay config JSON.
Future<String?> resolveCategoryFromConfig(
  AppDatabase db,
  Map<String, dynamic> config, {
  Map<String, String>? labelToIdCache,
  Set<String>? idSetCache,
}) async {
  final names = config['categoryNames'];
  if (names is List) {
    final resolved = await resolveContentCategoryIds(
      db,
      names.map((e) => e is String ? e : null),
      labelToIdCache: labelToIdCache,
      idSetCache: idSetCache,
    );
    if (resolved.isNotEmpty) {
      return resolved.first;
    }
  }
  final singleName = config['categoryName'];
  if (singleName is String && singleName.trim().isNotEmpty) {
    return resolveContentCategoryId(
      db,
      singleName,
      labelToIdCache: labelToIdCache,
      idSetCache: idSetCache,
    );
  }
  final legacy = config['categoryId'];
  if (legacy is String) {
    return resolveContentCategoryId(
      db,
      legacy,
      labelToIdCache: labelToIdCache,
      idSetCache: idSetCache,
    );
  }
  return null;
}

/// All configured category names/ids resolved to canonical ids.
Future<List<String>> resolveCategoryNamesListFromConfig(
  AppDatabase db,
  Map<String, dynamic> config, {
  Map<String, String>? labelToIdCache,
  Set<String>? idSetCache,
}) async {
  final names = config['categoryNames'];
  if (names is List && names.isNotEmpty) {
    return resolveContentCategoryIds(
      db,
      names.map((e) => e is String ? e : null),
      labelToIdCache: labelToIdCache,
      idSetCache: idSetCache,
    );
  }
  final single = await resolveCategoryFromConfig(
    db,
    config,
    labelToIdCache: labelToIdCache,
    idSetCache: idSetCache,
  );
  if (single != null) {
    return [single];
  }
  return const [];
}

Future<Map<String, String>> _loadLabelToId(AppDatabase db) async {
  final rows = await db.select(db.contentCategories).get();
  final out = <String, String>{};
  for (final row in rows) {
    final label = row.label.trim();
    if (label.isNotEmpty) {
      out.putIfAbsent(label, () => row.id);
    }
  }
  return out;
}

Future<Set<String>> _loadIdSet(AppDatabase db) async {
  final rows = await db.select(db.contentCategories).get();
  return rows.map((r) => r.id).toSet();
}
