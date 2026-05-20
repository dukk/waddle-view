import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

const _jsonHeaders = {'content-type': 'application/json'};

void registerIntegrationSecretsRestRoutes(
  Router r, {
  required AppDatabase db,
  required SecretStore secrets,
}) {
  r.get('/v1/integrations/<id>/secrets', (Request req, String id) async {
    final existing = await (db.select(db.integrations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final slots = integrationSecretSlotsForIntegration(
      id,
      existing.integrationType,
    );
    final configuredSlots = <Map<String, dynamic>>[];
    for (final slot in slots) {
      final v = await secrets.read(slot.storageKey);
      configuredSlots.add({
        'id': slot.id,
        'label': slot.label,
        'configured': v != null && v.trim().isNotEmpty,
      });
    }
    return Response.ok(
      jsonEncode({'slots': configuredSlots}),
      headers: _jsonHeaders,
    );
  });

  r.put('/v1/integrations/<id>/secrets/<slotId>',
      (Request req, String id, String slotId) async {
    final existing = await (db.select(db.integrations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final slot = integrationSecretSlotById(id, existing.integrationType, slotId);
    if (slot == null) {
      return Response(404,
          body: '{"error":"unknown_secret_slot"}', headers: _jsonHeaders);
    }
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}', headers: _jsonHeaders);
      }
      map = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}', headers: _jsonHeaders);
    }
    final raw = map['value'];
    if (raw is! String) {
      return Response(400,
          body: '{"error":"value_must_be_string"}', headers: _jsonHeaders);
    }
    final value = raw.trim();
    if (value.isEmpty) {
      return Response(400,
          body: '{"error":"value_must_be_non_empty"}', headers: _jsonHeaders);
    }
    await secrets.write(slot.storageKey, value);
    return Response.ok('{}', headers: _jsonHeaders);
  });

  r.delete('/v1/integrations/<id>/secrets/<slotId>',
      (Request req, String id, String slotId) async {
    final existing = await (db.select(db.integrations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final slot = integrationSecretSlotById(id, existing.integrationType, slotId);
    if (slot == null) {
      return Response(404,
          body: '{"error":"unknown_secret_slot"}', headers: _jsonHeaders);
    }
    await secrets.delete(slot.storageKey);
    return Response.ok('{}', headers: _jsonHeaders);
  });
}

/// Whether required secret slots for [integrationId] are populated.
Future<bool> integrationSecretsConfigured(
  SecretStore secrets,
  String integrationId,
  String integrationType,
) =>
    isIntegrationSecretsFullyConfigured(
      secrets,
      integrationId,
      integrationType: integrationType,
    );
