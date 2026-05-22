import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/config/display_live_preview.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../preview/live_preview_capture_backend.dart';
import 'display_live_preview_session.dart';

const _jsonHeaders = {'content-type': 'application/json'};

Future<Map<String, String>> _livePreviewKv(AppDatabase db) async {
  final rows = await db.select(db.configKeyValues).get();
  return {for (final r in rows) r.key: r.value};
}

Future<Map<String, dynamic>> buildLivePreviewInfoJson(AppDatabase db) async {
  final config = displayLivePreviewConfigFromKv(await _livePreviewKv(db));
  return {
    'configured': config.configured,
    'enabled': config.enabled,
    'fps': config.fps,
    'width': config.width,
    'quality': config.quality,
    'capture_backend': livePreviewActiveBackend.id,
    'capture_ready': true,
  };
}

void registerDisplayLivePreviewRoutes(
  Router r, {
  required AppDatabase db,
  DisplayLivePreviewSessionStore? sessionStore,
}) {
  final sessions = sessionStore ?? displayLivePreviewSessionStore;

  r.get('/v1/display/live-preview', (Request req) async {
    final body = await buildLivePreviewInfoJson(db);
    return Response.ok(jsonEncode(body), headers: _jsonHeaders);
  });

  r.post('/v1/display/live-preview/session', (Request req) async {
    final config = displayLivePreviewConfigFromKv(await _livePreviewKv(db));
    if (!config.configured) {
      return Response(
        400,
        body: '{"error":"live_preview_not_configured"}',
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
}
