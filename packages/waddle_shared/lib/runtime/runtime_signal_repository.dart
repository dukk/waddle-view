import 'dart:convert';

import 'package:drift/drift.dart';

import '../persistence/database.dart';

/// Reads/writes [RuntimeSignals] rows for curator and overlay gating.
class RuntimeSignalRepository {
  const RuntimeSignalRepository(this.db);

  final AppDatabase db;

  Future<void> upsert({
    required String id,
    required Object value,
    String? sourcePluginId,
    int? ttlSeconds,
  }) async {
    final key = id.trim();
    if (key.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.runtimeSignals).insertOnConflictUpdate(
          RuntimeSignalsCompanion.insert(
            id: key,
            valueJson: jsonEncode(value),
            updatedAtMs: nowMs,
            sourcePluginId: Value(sourcePluginId),
            ttlSeconds: Value(ttlSeconds),
          ),
        );
  }

  Future<Map<String, dynamic>> snapshot() async {
    final rows = await db.select(db.runtimeSignals).get();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final out = <String, dynamic>{};
    for (final row in rows) {
      if (row.ttlSeconds != null &&
          row.ttlSeconds! > 0 &&
          nowMs - row.updatedAtMs > row.ttlSeconds! * 1000) {
        continue;
      }
      out[row.id] = jsonDecode(row.valueJson);
    }
    return out;
  }

  Future<bool?> boolValue(String id) async {
    final snap = await snapshot();
    final v = snap[id.trim()];
    if (v is bool) {
      return v;
    }
    if (v is Map && v.containsKey('bool')) {
      return v['bool'] as bool?;
    }
    return null;
  }

  Stream<void> watchChanges() {
    return db.select(db.runtimeSignals).watch().map((_) {});
  }
}
