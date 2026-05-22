import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/config/display_remote_view.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

import 'display_remote_view_session.dart';

const _jsonHeaders = {'content-type': 'application/json'};

Future<Map<String, String>> _remoteViewKv(AppDatabase db) async {
  final rows = await db.select(db.configKeyValues).get();
  return {for (final r in rows) r.key: r.value};
}

Future<bool> remoteViewPasswordConfigured(SecretStore secrets) async {
  final v = await secrets.read(kDisplayRemoteViewVncPasswordSecretKey);
  return v != null && v.trim().isNotEmpty;
}

Future<Map<String, dynamic>> buildRemoteViewInfoJson(
  AppDatabase db,
  SecretStore secrets,
) async {
  final config = displayRemoteViewConfigFromKv(await _remoteViewKv(db));
  final passwordConfigured = await remoteViewPasswordConfigured(secrets);
  return {
    'configured': config.configured,
    'enabled': config.enabled,
    'host': config.host,
    'port': config.port,
    'path': config.path,
    'password_configured': passwordConfigured,
  };
}

void registerDisplayRemoteViewRoutes(
  Router r, {
  required AppDatabase db,
  required SecretStore secrets,
  DisplayRemoteViewSessionStore? sessionStore,
}) {
  final sessions = sessionStore ?? displayRemoteViewSessionStore;

  r.get('/v1/display/remote-view', (Request req) async {
    final body = await buildRemoteViewInfoJson(db, secrets);
    return Response.ok(jsonEncode(body), headers: _jsonHeaders);
  });

  r.post('/v1/display/remote-view/session', (Request req) async {
    final config = displayRemoteViewConfigFromKv(await _remoteViewKv(db));
    if (!config.configured) {
      return Response(
        400,
        body: '{"error":"remote_view_not_configured"}',
        headers: _jsonHeaders,
      );
    }
    final created = sessions.create(config);
    return Response.ok(
      jsonEncode({
        'ticket': created.ticket,
        'expires_at_ms': created.expiresAtMs,
      }),
      headers: _jsonHeaders,
    );
  });

  r.put('/v1/display/remote-view/password', (Request req) async {
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
    await secrets.write(kDisplayRemoteViewVncPasswordSecretKey, value);
    return Response.ok('{}', headers: _jsonHeaders);
  });

  r.delete('/v1/display/remote-view/password', (Request req) async {
    await secrets.delete(kDisplayRemoteViewVncPasswordSecretKey);
    return Response.ok('{}', headers: _jsonHeaders);
  });
}
