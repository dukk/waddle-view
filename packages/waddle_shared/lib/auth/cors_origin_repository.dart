import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'cors_origin_normalize.dart';

class CorsOriginRepository {
  CorsOriginRepository(this._db);

  final AppDatabase _db;

  Future<void> seedEnvOrigins(List<String> origins, {required int nowMs}) async {
    for (final raw in origins) {
      final origin = normalizeHttpOrigin(raw);
      if (origin == null) {
        continue;
      }
      await _insertOriginIfMissing(
        origin: origin,
        source: kCorsOriginSourceEnv,
        nowMs: nowMs,
      );
    }
  }

  Future<void> rememberAdoptionOrigin(String? rawOrigin, {required int nowMs}) async {
    final origin = normalizeHttpOrigin(rawOrigin);
    if (origin == null) {
      return;
    }
    await _insertOriginIfMissing(
      origin: origin,
      source: kCorsOriginSourceAdoption,
      nowMs: nowMs,
    );
  }

  Future<bool> isOriginAllowed(String? rawOrigin) async {
    final origin = normalizeHttpOrigin(rawOrigin);
    if (origin == null) {
      return false;
    }
    final row = await (_db.select(_db.corsAllowedOrigins)
          ..where((t) => t.origin.equals(origin)))
        .getSingleOrNull();
    return row != null;
  }

  Future<Set<String>> loadAllOrigins() async {
    final rows = await _db.select(_db.corsAllowedOrigins).get();
    return rows.map((r) => r.origin).toSet();
  }

  Future<void> _insertOriginIfMissing({
    required String origin,
    required String source,
    required int nowMs,
  }) async {
    final existing = await (_db.select(_db.corsAllowedOrigins)
          ..where((t) => t.origin.equals(origin)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }
    await _db.into(_db.corsAllowedOrigins).insert(
          CorsAllowedOriginsCompanion.insert(
            origin: origin,
            createdAtMs: nowMs,
            source: source,
          ),
        );
  }
}
