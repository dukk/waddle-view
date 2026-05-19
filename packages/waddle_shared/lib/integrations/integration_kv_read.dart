import 'dart:convert';

import 'package:drift/drift.dart';

import '../persistence/database.dart';

/// Watches one integration-scoped KV value.
Stream<String?> watchIntegrationKvValue(
  AppDatabase db, {
  required String integrationId,
  required String valueKey,
}) {
  final iid = integrationId.trim();
  final key = valueKey.trim();
  if (iid.isEmpty || key.isEmpty) {
    return Stream<String?>.value(null);
  }
  return (db.select(db.integrationsKeyValue)
        ..where((t) => t.integrationId.equals(iid) & t.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row?.value);
}

/// Decodes a KV string as JSON when possible; otherwise returns the raw string.
dynamic parseIntegrationJsonValue(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final trimmed = raw.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return trimmed;
  }
  try {
    return jsonDecode(trimmed);
  } catch (_) {
    return trimmed;
  }
}

/// Minimal JSONPath: `$.a.b`, `$[0]`, or empty/root returns [root].
dynamic selectJsonPath(dynamic root, String? jsonPath) {
  if (root == null) {
    return null;
  }
  final path = jsonPath?.trim();
  if (path == null || path.isEmpty || path == r'$') {
    return root;
  }
  if (!path.startsWith(r'$')) {
    return null;
  }
  var current = root;
  var i = 1;
  while (i < path.length) {
    if (path[i] == '.') {
      i++;
      final start = i;
      while (i < path.length && path[i] != '.' && path[i] != '[') {
        i++;
      }
      final key = path.substring(start, i);
      if (key.isEmpty) {
        return null;
      }
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else if (current is Map) {
        current = current[key];
      } else {
        return null;
      }
      continue;
    }
    if (path[i] == '[') {
      i++;
      final start = i;
      while (i < path.length && path[i] != ']') {
        i++;
      }
      final indexStr = path.substring(start, i);
      i++;
      final index = int.tryParse(indexStr);
      if (index == null || current is! List) {
        return null;
      }
      if (index < 0 || index >= current.length) {
        return null;
      }
      current = current[index];
      continue;
    }
    return null;
  }
  return current;
}
