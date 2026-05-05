import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../alerts/alert_repository.dart';
import '../debug/app_debug_log.dart';
import '../persistence/database.dart';
import '../ticker/ticker_curated_repository.dart';
import 'api_key_constant_time.dart';
import 'deployment_api_key_source.dart';

Middleware apiKeyAuth(DeploymentApiKeySource keys) {
  return (Handler inner) {
    return (Request request) async {
      final expected = await keys.load();
      if (expected == null || expected.isEmpty) {
        AppDebugLog.api(
          '503 ${request.requestedUri.path} api_key_unconfigured',
        );
        return Response(
          503,
          body: '{"error":"api_key_unconfigured"}',
          headers: {'content-type': 'application/json'},
        );
      }
      final header = request.headers['x-api-key'] ?? '';
      final bearer = request.headers['authorization'] ?? '';
      var presented = header;
      if (bearer.toLowerCase().startsWith('bearer ')) {
        presented = bearer.substring(7).trim();
      }
      if (!constantTimeStringEquals(presented, expected)) {
        AppDebugLog.api(
          '401 ${request.requestedUri.path} invalid or missing API key',
        );
        return Response.unauthorized('{"error":"unauthorized"}');
      }
      return inner(request);
    };
  };
}

Handler buildProtectedApiRouter({
  required AppDatabase db,
  required AlertRepository alerts,
  required TickerCuratedRepository ticker,
}) {
  final r = Router();

  r.get('/v1/providers', (Request req) async {
    final rows = await db.select(db.providerSettings).get();
    final list = rows
        .map(
          (e) => {
            'id': e.id,
            'type': e.providerType,
            'enabled': e.enabled,
            'poll_seconds': e.pollSeconds,
          },
        )
        .toList();
    return Response.ok(
      jsonEncode({'items': list}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/screens', (Request req) async {
    final rows = await db.select(db.screenDefinitions).get();
    final list = rows
        .map(
          (e) => <String, Object?>{
            'id': e.id,
            'name': e.name,
            'description': e.description,
            'enabled': e.enabled,
            'layout_json': e.layoutJson,
            'dwell_ms': e.dwellMs,
            'frequency_weight': e.frequencyWeight,
            'min_gap_between_shows_ms': e.minGapBetweenShowsMs,
          },
        )
        .toList();
    return Response.ok(
      jsonEncode({'items': list}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/ticker/items', (Request req) async {
    final rows = await ticker.snapshot();
    final list = <Map<String, Object?>>[];
    for (var i = 0; i < rows.length; i++) {
      final e = rows[i];
      list.add({
        'ordinal': i,
        'kind': e.kind,
        'body': e.body,
      });
    }
    return Response.ok(
      jsonEncode({'items': list}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/alerts', (Request req) async {
    final rows = await db.select(db.dashboardAlerts).get();
    return Response.ok(
      jsonEncode({'items': rows.map(_alertJson).toList()}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/alerts', (Request req) async {
    final body = await req.readAsString();
    final map = jsonDecode(body) as Map<String, dynamic>;
    final id = await alerts.insertAlert(
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      qrPayload: map['qr_payload'] as String?,
      severity: map['severity'] as String? ?? 'info',
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      expiresAtMs: (map['expires_at'] as num?)?.toInt(),
    );
    return Response.ok(
      jsonEncode({'id': id}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.delete('/v1/alerts/<id>', (Request req, String id) async {
    await alerts.dismiss(int.parse(id, radix: 10));
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  return r.call;
}

Map<String, Object?> _alertJson(DashboardAlert a) => {
  'id': a.id,
  'title': a.title,
  'body': a.body,
  'severity': a.severity,
  'priority': a.priority,
  'qr_payload': a.qrPayload,
};

Handler buildRootHandler({
  required AppDatabase db,
  required AlertRepository alerts,
  required DeploymentApiKeySource keys,
  required TickerCuratedRepository ticker,
}) {
  Response health(Request req) =>
      Response.ok('{"status":"ok"}', headers: {'content-type': 'application/json'});

  final protected = Pipeline()
      .addMiddleware(apiKeyAuth(keys))
      .addHandler(
        buildProtectedApiRouter(db: db, alerts: alerts, ticker: ticker),
      );

  FutureOr<Response> root(Request req) {
    final path = req.requestedUri.path;
    if (path == '/v1/health' || path == 'v1/health') {
      return health(req);
    }
    return protected(req);
  }

  return withDebugRequestLogging(root);
}

/// Logs method, path, and status in debug only (never logs headers or body).
Handler withDebugRequestLogging(Handler inner) {
  return (Request req) async {
    if (kDebugMode) {
      AppDebugLog.api('${req.method} ${req.requestedUri.path}');
    }
    final res = await inner(req);
    if (kDebugMode) {
      AppDebugLog.api(
        '${req.method} ${req.requestedUri.path} -> ${res.statusCode}',
      );
    }
    return res;
  };
}

class LocalRestServer {
  LocalRestServer._(this._server, this._host, this._port);

  final HttpServer _server;
  final String _host;
  final int _port;

  String get baseUrl => 'http://$_host:$_port';

  Future<void> close() => _server.close(force: true);

  static Future<LocalRestServer> bind({
    required Handler handler,
    InternetAddress? address,
    int port = 8787,
  }) async {
    final addr = address ?? InternetAddress.loopbackIPv4;
    final server = await shelf_io.serve(
      handler,
      addr,
      port,
    );
    return LocalRestServer._(server, server.address.address, server.port);
  }
}
