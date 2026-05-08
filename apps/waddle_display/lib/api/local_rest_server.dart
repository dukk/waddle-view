import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../alerts/alert_repository.dart';
import '../debug/app_debug_log.dart';
import '../persistence/content_suppression_repository.dart';
import '../persistence/database.dart';
import '../persistence/tables.dart';
import '../secrets/secret_store.dart';
import '../theme/display_theme.dart';
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
  final suppression = ContentSuppressionRepository(db);

  r.patch('/v1/content/jokes/<id>', (Request req, String id) async {
    return _patchContentSuppressed(req, (b) => suppression.setJokeSuppressed(id, b));
  });
  r.patch('/v1/content/rss-articles/<id>', (Request req, String id) async {
    return _patchContentSuppressed(
      req,
      (b) => suppression.setRssArticleSuppressed(id, b),
    );
  });
  r.patch('/v1/content/photos/<id>', (Request req, String id) async {
    return _patchContentSuppressed(req, (b) => suppression.setPhotoSuppressed(id, b));
  });
  r.patch('/v1/content/videos/<id>', (Request req, String id) async {
    return _patchContentSuppressed(req, (b) => suppression.setVideoSuppressed(id, b));
  });
  r.patch('/v1/content/trivia/<id>', (Request req, String id) async {
    return _patchContentSuppressed(
      req,
      (b) => suppression.setTriviaQuestionSuppressed(id, b),
    );
  });

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
    final dataKeyLimitRows =
        await db.select(db.curatorDataKeyProgramLimits).get();
    final dataKeyLimits = <String, CuratorDataKeyProgramLimit>{
      for (final row in dataKeyLimitRows) row.dataKey: row,
    };
    final list = rows
        .map(
          (e) => <String, Object?>{
            'id': e.id,
            'name': e.name,
            'description': e.description,
            'enabled': e.enabled,
            'layout_json': e.layoutJson,
            'layout_json_schema': e.layoutJsonSchema,
            'example_layout_json': e.exampleLayoutJson,
            'dwell_seconds': e.dwellSeconds,
            'frequency_weight': e.frequencyWeight,
            'min_gap_between_shows_seconds': e.minGapBetweenShowsSeconds,
            'min_placements_per_program': e.minPlacementsPerProgram,
            'max_placements_per_program': e.maxPlacementsPerProgram,
            'data_key': e.dataKey,
            'data_key_min_placements_per_program':
                e.dataKey.isEmpty
                    ? null
                    : dataKeyLimits[e.dataKey]?.minPlacementsPerProgram,
            'data_key_max_placements_per_program':
                e.dataKey.isEmpty
                    ? null
                    : dataKeyLimits[e.dataKey]?.maxPlacementsPerProgram,
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

Future<Response> _patchContentSuppressed(
  Request req,
  Future<int> Function(bool suppressed) apply,
) async {
  Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return Response(
        400,
        body: '{"error":"expected_json_object"}',
        headers: {'content-type': 'application/json'},
      );
    }
    map = decoded;
  } on Object {
    return Response(
      400,
      body: '{"error":"invalid_json"}',
      headers: {'content-type': 'application/json'},
    );
  }
  final suppressed = map['suppressed'];
  if (suppressed is! bool) {
    return Response(
      400,
      body: '{"error":"suppressed_must_be_bool"}',
      headers: {'content-type': 'application/json'},
    );
  }
  final n = await apply(suppressed);
  if (n == 0) {
    return Response(
      404,
      body: '{"error":"not_found"}',
      headers: {'content-type': 'application/json'},
    );
  }
  return Response.ok('{}', headers: {'content-type': 'application/json'});
}

Handler buildRootHandler({
  required AppDatabase db,
  required AlertRepository alerts,
  required DeploymentApiKeySource keys,
  required TickerCuratedRepository ticker,
  required SecretStore secrets,
  required Future<void> Function() onConfigChanged,
  required File keyFile,
  required String setupScreenId,
}) {
  Response health(Request req) =>
      Response.ok('{"status":"ok"}', headers: {'content-type': 'application/json'});

  final protected = Pipeline()
      .addMiddleware(apiKeyAuth(keys))
      .addHandler(
        buildProtectedApiRouter(db: db, alerts: alerts, ticker: ticker),
      );
  final admin = _AdminServer(
    db: db,
    keys: keys,
    secrets: secrets,
    onConfigChanged: onConfigChanged,
    keyFile: keyFile,
    setupScreenId: setupScreenId,
  );

  FutureOr<Response> root(Request req) {
    final path = req.requestedUri.path;
    if (path == '/v1/health' || path == 'v1/health') {
      return health(req);
    }
    if (path.startsWith('admin') || path.startsWith('/admin')) {
      return admin.handler(req);
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
  String get displayBaseUrl => 'http://${_displayHost ?? _host}:$_port';
  String? _displayHost;

  Future<void> close() => _server.close(force: true);

  static Future<LocalRestServer> bind({
    required Handler handler,
    InternetAddress? address,
    int port = 8787,
    String? displayHost,
  }) async {
    final addr = address ?? InternetAddress.loopbackIPv4;
    final server = await shelf_io.serve(
      handler,
      addr,
      port,
    );
    final out = LocalRestServer._(server, server.address.address, server.port);
    out._displayHost = displayHost;
    return out;
  }
}

class _AdminServer {
  _AdminServer({
    required this.db,
    required this.keys,
    required this.secrets,
    required this.onConfigChanged,
    required this.keyFile,
    required this.setupScreenId,
  });

  final AppDatabase db;
  final DeploymentApiKeySource keys;
  final SecretStore secrets;
  final Future<void> Function() onConfigChanged;
  final File keyFile;
  final String setupScreenId;

  final Map<String, _AdminSession> _sessions = <String, _AdminSession>{};

  Future<Response> handler(Request req) async {
    final path = req.requestedUri.path;
    if (path == 'admin' || path == '/admin') {
      return _requireSession(req, _adminHome);
    }
    if (path == 'admin/login' || path == '/admin/login') {
      if (req.method == 'GET') {
        return _loginPage();
      }
      if (req.method == 'POST') {
        return _loginSubmit(req);
      }
    }
    if (path == 'admin/logout' || path == '/admin/logout') {
      return _logout(req);
    }
    if (path == 'admin/change-password' || path == '/admin/change-password') {
      if (req.method == 'GET') {
        return _requireSession(req, _changePasswordPage);
      }
      if (req.method == 'POST') {
        return _requireSession(req, _changePasswordSubmit);
      }
    }
    if (path == 'admin/update-screen' || path == '/admin/update-screen') {
      return _requireSession(req, _updateScreen);
    }
    if (path == 'admin/update-curator' || path == '/admin/update-curator') {
      return _requireSession(req, _updateCurator);
    }
    if (path == 'admin/update-provider' || path == '/admin/update-provider') {
      return _requireSession(req, _updateProvider);
    }
    return Response.notFound('Not found');
  }

  Future<Response> _requireSession(
    Request req,
    Future<Response> Function(Request req, _AdminSession session) next,
  ) async {
    final session = _sessionFromRequest(req);
    if (session == null) {
      return _redirect('/admin/login');
    }
    final bootstrapDone = await _isBootstrapDone();
    if (!bootstrapDone &&
        req.requestedUri.path != 'admin/change-password' &&
        req.requestedUri.path != '/admin/change-password') {
      return _redirect('/admin/change-password');
    }
    return next(req, session);
  }

  _AdminSession? _sessionFromRequest(Request req) {
    final cookie = req.headers['cookie'] ?? '';
    final parts = cookie.split(';');
    for (final part in parts) {
      final kv = part.trim();
      if (!kv.startsWith('wv_admin_session=')) {
        continue;
      }
      final token = kv.substring('wv_admin_session='.length);
      return _sessions[token];
    }
    return null;
  }

  Future<Response> _loginPage() async {
    return _html(
      'Admin Login',
      '''
<h1>Waddle View Admin Login</h1>
<form method="post" action="/admin/login">
  <label>Password</label><br/>
  <input type="password" name="password" autocomplete="current-password"/><br/><br/>
  <button type="submit">Sign in</button>
</form>
''',
    );
  }

  Future<Response> _loginSubmit(Request req) async {
    final form = await _readForm(req);
    final password = form['password'] ?? '';
    final expected = (await keys.load()) ?? '';
    if (!constantTimeStringEquals(password, expected)) {
      return _html('Admin Login', '<p>Invalid password.</p><a href="/admin/login">Back</a>', status: 401);
    }
    final token = _randomHex(32);
    final csrf = _randomHex(16);
    _sessions[token] = _AdminSession(token: token, csrfToken: csrf);
    return _redirect(
      '/admin',
      headers: {'set-cookie': 'wv_admin_session=$token; HttpOnly; SameSite=Lax; Path=/'},
    );
  }

  Future<Response> _logout(Request req) async {
    final session = _sessionFromRequest(req);
    if (session != null) {
      _sessions.remove(session.token);
    }
    return _redirect(
      '/admin/login',
      headers: {
        'set-cookie':
            'wv_admin_session=deleted; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/',
      },
    );
  }

  Future<Response> _adminHome(Request req, _AdminSession session) async {
    final screens = await (db.select(db.screenDefinitions)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final providers = await (db.select(db.providerSettings)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final kvRows = await (db.select(db.configKeyValues)
          ..orderBy([(t) => OrderingTerm.asc(t.key)]))
        .get();
    final kvMap = {for (final row in kvRows) row.key: row.value};
    final programDurationSeconds = int.tryParse(
          kvMap[kCuratorProgramDurationSecondsKvKey]?.trim() ?? '',
        ) ??
        180;
    final historyDepth = int.tryParse(
          kvMap[kCuratorHistoryDepthKvKey]?.trim() ?? '',
        ) ??
        5;
    final kvTicker = kvMap['curator.ticker.newsPixelsPerSecond'] ?? '80';
    final requireNewsPhotoForScreens =
        kvMap[kRequireNewsPhotoForScreensKvKey] ?? 'true';
    final currentThemeId = normalizeDisplayThemeId(kvMap[kDisplayThemeIdKvKey]);
    final themeOptionRows = kDisplayThemeOptions
        .map(
          (o) =>
              '<option value="${_h(o.id)}" ${o.id == currentThemeId ? 'selected' : ''}>'
              '${_h(o.label)}'
              '</option>',
        )
        .join('\n');
    final screenTextScaleId = normalizeDisplayTextScaleOption(
      kvMap[kDisplayTextScaleScreenKvKey],
    );
    final tickerTextScaleId = normalizeDisplayTextScaleOption(
      kvMap[kDisplayTextScaleTickerKvKey],
    );
    final screenTextScaleRows = kDisplayTextScaleSelectOptions
        .map(
          (o) =>
              '<option value="${_h(o.id)}" ${o.id == screenTextScaleId ? 'selected' : ''}>'
              '${_h(o.label)}'
              '</option>',
        )
        .join('\n');
    final tickerTextScaleRows = kDisplayTextScaleSelectOptions
        .map(
          (o) =>
              '<option value="${_h(o.id)}" ${o.id == tickerTextScaleId ? 'selected' : ''}>'
              '${_h(o.label)}'
              '</option>',
        )
        .join('\n');

    final screenRows = screens
        .map(
          (s) => '''
<tr>
<form method="post" action="/admin/update-screen">
<input type="hidden" name="csrf" value="${session.csrfToken}"/>
<td>${_h(s.id)}<input type="hidden" name="id" value="${_h(s.id)}"/></td>
<td><input name="name" value="${_h(s.name)}"/></td>
<td><input name="enabled" type="checkbox" ${s.enabled ? 'checked' : ''}/></td>
<td><input name="dwell_seconds" value="${s.dwellSeconds}"/></td>
<td><input name="frequency_weight" value="${s.frequencyWeight}"/></td>
<td><input name="min_gap_between_shows_seconds" value="${s.minGapBetweenShowsSeconds}"/></td>
<td><button type="submit">Save</button></td>
</form>
</tr>
''',
        )
        .join('\n');

    final providerRows = providers
        .map(
          (p) => '''
<tr>
<form method="post" action="/admin/update-provider">
<input type="hidden" name="csrf" value="${session.csrfToken}"/>
<td>${_h(p.id)}<input type="hidden" name="id" value="${_h(p.id)}"/></td>
<td>${_h(p.providerType)}</td>
<td><input name="enabled" type="checkbox" ${p.enabled ? 'checked' : ''}/></td>
<td><input name="poll_seconds" value="${p.pollSeconds}"/></td>
<td><input name="base_url" value="${_h(p.baseUrl ?? '')}"/></td>
<td><input name="config_json" value="${_h(p.configJson ?? '')}"/></td>
<td><input name="access_token" placeholder="leave blank to keep"/></td>
<td><button type="submit">Save</button></td>
</form>
</tr>
''',
        )
        .join('\n');

    return _html(
      'Admin',
      '''
<h1>Waddle View Admin</h1>
<p><a href="/admin/change-password">Change password</a> | <a href="/admin/logout">Logout</a></p>
<h2>Curator</h2>
<form method="post" action="/admin/update-curator">
<input type="hidden" name="csrf" value="${session.csrfToken}"/>
Program duration seconds: <input name="program_duration_seconds" value="$programDurationSeconds"/><br/>
History depth: <input name="history_depth" value="$historyDepth"/><br/>
Require photo for RSS screen slides (ticker unchanged):
<input name="require_news_photo_for_screens" type="checkbox" ${requireNewsPhotoForScreens != 'false' ? 'checked' : ''}/><br/>
Ticker px/s: <input name="ticker_pixels_per_second" value="${_h(kvTicker)}"/><br/>
Display theme:
<select name="display_theme_id">
$themeOptionRows
</select><br/>
Screen text scale:
<select name="display_text_scale_screen">
$screenTextScaleRows
</select><br/>
Ticker text scale:
<select name="display_text_scale_ticker">
$tickerTextScaleRows
</select><br/>
<button type="submit">Save curator settings</button>
</form>
<h2>Screens</h2>
<table border="1" cellpadding="4" cellspacing="0">
<tr><th>ID</th><th>Name</th><th>Enabled</th><th>Dwell</th><th>Weight</th><th>Min Gap</th><th>Action</th></tr>
$screenRows
</table>
<h2>Providers</h2>
<table border="1" cellpadding="4" cellspacing="0">
<tr><th>ID</th><th>Type</th><th>Enabled</th><th>Poll Seconds</th><th>Base URL</th><th>Config JSON</th><th>Secret Token</th><th>Action</th></tr>
$providerRows
</table>
''',
    );
  }

  Future<Response> _changePasswordPage(
    Request req,
    _AdminSession session,
  ) async {
    return _html(
      'Change Password',
      '''
<h1>Change admin password</h1>
<p>You must rotate the install password before continuing.</p>
<form method="post" action="/admin/change-password">
  <input type="hidden" name="csrf" value="${session.csrfToken}"/>
  <label>New password</label><br/>
  <input type="password" name="password"/><br/><br/>
  <label>Confirm password</label><br/>
  <input type="password" name="confirm_password"/><br/><br/>
  <button type="submit">Update password</button>
</form>
''',
    );
  }

  Future<Response> _changePasswordSubmit(
    Request req,
    _AdminSession session,
  ) async {
    final form = await _readForm(req);
    if (!_validCsrf(session, form)) {
      return Response.forbidden('csrf');
    }
    final password = (form['password'] ?? '').trim();
    final confirm = (form['confirm_password'] ?? '').trim();
    if (password.length < 12 || password != confirm) {
      return _html('Change Password', '<p>Passwords must match and be at least 12 chars.</p>', status: 400);
    }
    await keyFile.writeAsString('$password\n', flush: true);
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '1',
          ),
        );
    await (db.update(db.screenDefinitions)..where((t) => t.id.equals(setupScreenId)))
        .write(const ScreenDefinitionsCompanion(enabled: Value(false)));
    await onConfigChanged();
    _sessions.clear();
    return _redirect('/admin/login');
  }

  Future<Response> _updateScreen(Request req, _AdminSession session) async {
    final form = await _readForm(req);
    if (!_validCsrf(session, form)) {
      return Response.forbidden('csrf');
    }
    final id = form['id'] ?? '';
    final dwellSeconds = int.tryParse(form['dwell_seconds'] ?? '');
    final weight = int.tryParse(form['frequency_weight'] ?? '');
    final gapSeconds = int.tryParse(form['min_gap_between_shows_seconds'] ?? '');
    if (id.isEmpty ||
        dwellSeconds == null ||
        weight == null ||
        gapSeconds == null) {
      return Response(400, body: 'invalid');
    }
    await (db.update(db.screenDefinitions)..where((t) => t.id.equals(id))).write(
      ScreenDefinitionsCompanion(
        name: Value(form['name'] ?? ''),
        enabled: Value(form.containsKey('enabled')),
        dwellSeconds: Value(dwellSeconds),
        frequencyWeight: Value(weight),
        minGapBetweenShowsSeconds: Value(gapSeconds),
      ),
    );
    await onConfigChanged();
    return _redirect('/admin');
  }

  Future<Response> _updateCurator(Request req, _AdminSession session) async {
    final form = await _readForm(req);
    if (!_validCsrf(session, form)) {
      return Response.forbidden('csrf');
    }
    final duration = int.tryParse(form['program_duration_seconds'] ?? '');
    final depth = int.tryParse(form['history_depth'] ?? '');
    if (duration == null || depth == null) {
      return Response(400, body: 'invalid');
    }
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kCuratorProgramDurationSecondsKvKey,
            value: '$duration',
          ),
        );
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kCuratorHistoryDepthKvKey,
            value: '$depth',
          ),
        );
    final tickerPx = (form['ticker_pixels_per_second'] ?? '').trim();
    if (tickerPx.isNotEmpty) {
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: 'curator.ticker.newsPixelsPerSecond',
              value: tickerPx,
            ),
          );
    }
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kRequireNewsPhotoForScreensKvKey,
            value: form.containsKey('require_news_photo_for_screens')
                ? 'true'
                : 'false',
          ),
        );
    final themeId = normalizeDisplayThemeId(form['display_theme_id'] ?? '');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayThemeIdKvKey,
            value: themeId,
          ),
        );
    final screenTextScale = normalizeDisplayTextScaleOption(
      form['display_text_scale_screen'] ?? '',
    );
    final tickerTextScale = normalizeDisplayTextScaleOption(
      form['display_text_scale_ticker'] ?? '',
    );
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTextScaleScreenKvKey,
            value: screenTextScale,
          ),
        );
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTextScaleTickerKvKey,
            value: tickerTextScale,
          ),
        );
    await onConfigChanged();
    return _redirect('/admin');
  }

  Future<Response> _updateProvider(Request req, _AdminSession session) async {
    final form = await _readForm(req);
    if (!_validCsrf(session, form)) {
      return Response.forbidden('csrf');
    }
    final id = form['id'] ?? '';
    final poll = int.tryParse(form['poll_seconds'] ?? '');
    if (id.isEmpty || poll == null) {
      return Response(400, body: 'invalid');
    }
    await (db.update(db.providerSettings)..where((t) => t.id.equals(id))).write(
      ProviderSettingsCompanion(
        enabled: Value(form.containsKey('enabled')),
        pollSeconds: Value(poll),
        baseUrl: Value((form['base_url'] ?? '').trim().isEmpty
            ? null
            : (form['base_url'] ?? '').trim()),
        configJson: Value((form['config_json'] ?? '').trim().isEmpty
            ? null
            : (form['config_json'] ?? '').trim()),
      ),
    );
    final token = (form['access_token'] ?? '').trim();
    if (token.isNotEmpty) {
      await secrets.write('provider:access_token:$id', token);
    }
    await onConfigChanged();
    return _redirect('/admin');
  }

  bool _validCsrf(_AdminSession session, Map<String, String> form) {
    return form['csrf'] == session.csrfToken;
  }

  Future<Map<String, String>> _readForm(Request req) async {
    final raw = await req.readAsString();
    final m = Uri.splitQueryString(raw, encoding: utf8);
    return m.map((k, v) => MapEntry(k, v.trim()));
  }

  Future<bool> _isBootstrapDone() async {
    final row = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(kAdminBootstrapDoneKvKey)))
        .getSingleOrNull();
    return row?.value == '1';
  }

  Response _redirect(String to, {Map<String, String>? headers}) {
    return Response(
      302,
      headers: {'location': to, ...?headers},
    );
  }

  Response _html(String title, String body, {int status = 200}) {
    return Response(
      status,
      body: '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${_h(title)}</title>
</head>
<body style="font-family: sans-serif; margin: 20px;">
$body
</body>
</html>
''',
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }
}

class _AdminSession {
  const _AdminSession({
    required this.token,
    required this.csrfToken,
  });

  final String token;
  final String csrfToken;
}

String _h(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _randomHex(int bytes) {
  final r = Random.secure();
  final out = List<int>.generate(bytes, (_) => r.nextInt(256));
  return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
