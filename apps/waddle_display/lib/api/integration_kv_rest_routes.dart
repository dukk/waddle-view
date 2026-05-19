import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/persistence/database.dart';

const _jsonHeaders = {'content-type': 'application/json'};

void registerIntegrationKvRestRoutes(Router r, {required AppDatabase db}) {
  r.get('/v1/integrations/<id>/kv', (Request req, String id) async {
    final existing = await (db.select(db.integrations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404, body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final prefix = req.url.queryParameters['prefix']?.trim();
    final kv = IntegrationKvRepository(db);
    final rows = await kv.listIntegrationKeys(id, keyPrefix: prefix);
    rows.sort((a, b) => a.key.compareTo(b.key));
    return Response.ok(
      jsonEncode({
        'items': [
          for (final row in rows)
            {
              'key': row.key,
              'value_type': row.valueType,
              'created_at_ms': row.createdAtMs,
              'updated_at_ms': row.updatedAtMs,
              'value_length': row.value.length,
            },
        ],
      }),
      headers: _jsonHeaders,
    );
  });

  r.get('/v1/integrations/<id>/kv/<key>', (Request req, String id, String key) async {
    final existing = await (db.select(db.integrations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404, body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final kv = IntegrationKvRepository(db);
    final value = await kv.getIntegrationValue(id, key);
    if (value == null) {
      return Response(404, body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    return Response.ok(
      jsonEncode({'key': key, 'value': value}),
      headers: _jsonHeaders,
    );
  });

  r.delete('/v1/integrations/<id>/kv/<key>',
      (Request req, String id, String key) async {
    final existing = await (db.select(db.integrations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404, body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    await IntegrationKvRepository(db).deleteIntegrationKey(id, key);
    return Response.ok('{}', headers: _jsonHeaders);
  });
}
