import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/auth/user_repository.dart';
import 'package:waddle_shared/config/provider_access_token_env.dart';
import 'session_auth.dart';

const int kSessionTtlMs = 7 * 24 * 60 * 60 * 1000;
const String kBootstrapWarningCode = 'bootstrap_admin';

void registerAuthRoutes(
  Router r, {
  required UserRepository users,
  required Map<String, String> env,
}) {
  r.post('/v1/auth/login', (Request req) => _login(req, users));
  r.get('/v1/auth/oauth/providers', (Request req) => _oauthProviders(env));

  r.post('/v1/auth/oauth/<provider>/start', (Request req, String provider) async {
    return Response(
      501,
      body: jsonEncode({
        'error': 'oauth_not_implemented',
        'provider': provider,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/auth/oauth/<provider>/callback', (Request req, String provider) async {
    return Response(
      501,
      body: jsonEncode({
        'error': 'oauth_not_implemented',
        'provider': provider,
      }),
      headers: {'content-type': 'application/json'},
    );
  });
}

void registerAuthenticatedAuthRoutes(
  Router r, {
  required UserRepository users,
}) {
  r.post('/v1/auth/logout', (Request req) => _logout(req, users));
  r.get('/v1/auth/me', (Request req) => _me(req, users));
  r.get('/v1/auth/permissions', (Request req) => _me(req, users));

  r.get('/v1/users', (Request req) => _listUsers(req, users));
  r.post('/v1/users', (Request req) => _createUser(req, users));
  r.patch('/v1/users/<id>', (Request req, String id) => _patchUser(req, users, id));
  r.post('/v1/users/<id>/password', (Request req, String id) =>
      _changePassword(req, users, id));
  r.delete('/v1/users/<id>', (Request req, String id) => _disableUser(req, users, id));
}

Future<Response> _login(Request req, UserRepository users) async {
  Map<String, dynamic> body;
  try {
    body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return _badRequest('invalid_json');
  }
  final username = (body['username'] as String? ?? '').trim();
  final password = body['password'] as String? ?? '';
  if (username.isEmpty || password.isEmpty) {
    return _badRequest('username_and_password_required');
  }
  final user = await users.findByUsername(username);
  if (user == null) {
    return Response.unauthorized(
      '{"error":"invalid_credentials"}',
      headers: {'content-type': 'application/json'},
    );
  }
  if (user.isBootstrap && !(await users.bootstrapLoginAllowed())) {
    return Response(
      403,
      body: '{"error":"bootstrap_admin_disabled"}',
      headers: {'content-type': 'application/json'},
    );
  }
  if (!(await users.verifyLoginPassword(user, password))) {
    return Response.unauthorized(
      '{"error":"invalid_credentials"}',
      headers: {'content-type': 'application/json'},
    );
  }
  final token = _randomHex(32);
  final expiresAt = DateTime.now().millisecondsSinceEpoch + kSessionTtlMs;
  await users.createSession(
    userId: user.id,
    token: token,
    expiresAtMs: expiresAt,
    clientLabel: req.headers['user-agent'],
  );
  final warnings = <String>[];
  if (user.isBootstrap) {
    warnings.add(kBootstrapWarningCode);
  }
  return Response.ok(
    jsonEncode({
      'session_token': token,
      'expires_at_ms': expiresAt,
      'user': users.toView(user).toJson(),
      'permissions': permissionsForRole(user.role),
      'warnings': warnings,
    }),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _logout(Request req, UserRepository users) async {
  final token = _bearerFromRequest(req);
  if (token != null) {
    await users.deleteSession(token);
  }
  return Response.ok('{}', headers: {'content-type': 'application/json'});
}

Future<Response> _me(Request req, UserRepository users) async {
  final user = authUser(req);
  if (user == null) {
    return Response.unauthorized(
      '{"error":"unauthorized"}',
      headers: {'content-type': 'application/json'},
    );
  }
  final warnings = <String>[];
  var bootstrapWarning = false;
  if (user.isBootstrap) {
    bootstrapWarning = true;
    warnings.add(kBootstrapWarningCode);
  }
  return Response.ok(
    jsonEncode({
      'user': users.toView(user).toJson(),
      'permissions': permissionsForRole(user.role),
      'warnings': warnings,
      'bootstrap_warning': bootstrapWarning,
    }),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _listUsers(Request req, UserRepository users) async {
  final list = await users.listUsers();
  return Response.ok(
    jsonEncode({'items': list.map((u) => u.toJson()).toList()}),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _createUser(Request req, UserRepository users) async {
  Map<String, dynamic> body;
  try {
    body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return _badRequest('invalid_json');
  }
  final username = (body['username'] as String? ?? '').trim();
  final password = body['password'] as String? ?? '';
  final role = (body['role'] as String? ?? '').trim();
  final displayName = body['display_name'] as String?;
  try {
    final user = await users.createNamedUser(
      username: username,
      password: password,
      role: role,
      displayName: displayName,
    );
    return Response.ok(
      jsonEncode({'user': users.toView(user).toJson()}),
      headers: {'content-type': 'application/json'},
    );
  } on StateError catch (e) {
    if (e.message == 'username_taken') {
      return Response(
        409,
        body: '{"error":"username_taken"}',
        headers: {'content-type': 'application/json'},
      );
    }
    rethrow;
  } on ArgumentError {
    return _badRequest('invalid_user_fields');
  }
}

Future<Response> _patchUser(
  Request req,
  UserRepository users,
  String id,
) async {
  Map<String, dynamic> body;
  try {
    body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return _badRequest('invalid_json');
  }
  try {
    final updated = await users.updateUser(
      id: id,
      role: body['role'] as String?,
      displayName: body['display_name'] as String?,
      disabled: body['disabled'] as bool?,
    );
    if (updated == null) {
      return _notFound();
    }
    return Response.ok(
      jsonEncode({'user': users.toView(updated).toJson()}),
      headers: {'content-type': 'application/json'},
    );
  } on StateError catch (e) {
    if (e.message == 'cannot_modify_bootstrap') {
      return Response(
        403,
        body: '{"error":"cannot_modify_bootstrap"}',
        headers: {'content-type': 'application/json'},
      );
    }
    rethrow;
  } on ArgumentError {
    return _badRequest('invalid_user_fields');
  }
}

Future<Response> _changePassword(
  Request req,
  UserRepository users,
  String id,
) async {
  final actor = authUser(req);
  if (actor == null) {
    return Response.unauthorized(
      '{"error":"unauthorized"}',
      headers: {'content-type': 'application/json'},
    );
  }
  final canManage = userHasPermission(actor.role, WaddlePermission.usersManage);
  if (actor.id != id && !canManage) {
    return Response(
      403,
      body: '{"error":"forbidden"}',
      headers: {'content-type': 'application/json'},
    );
  }
  Map<String, dynamic> body;
  try {
    body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return _badRequest('invalid_json');
  }
  final password = body['password'] as String? ?? '';
  if (password.length < 8) {
    return _badRequest('password_too_short');
  }
  final ok = await users.setPassword(id: id, newPassword: password);
  if (!ok) {
    return _notFound();
  }
  if (actor.id != id) {
    await users.deleteSessionsForUser(id);
  }
  return Response.ok('{}', headers: {'content-type': 'application/json'});
}

Future<Response> _disableUser(
  Request req,
  UserRepository users,
  String id,
) async {
  try {
    final updated = await users.updateUser(id: id, disabled: true);
    if (updated == null) {
      return _notFound();
    }
    await users.deleteSessionsForUser(id);
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  } on StateError catch (e) {
    if (e.message == 'cannot_modify_bootstrap') {
      return Response(
        403,
        body: '{"error":"cannot_modify_bootstrap"}',
        headers: {'content-type': 'application/json'},
      );
    }
    rethrow;
  }
}

Response _oauthProviders(Map<String, String> env) {
  final items = <Map<String, String>>[];
  if (readGoogleClientIdFromEnvMap(env) != null) {
    items.add({'id': 'google', 'label': 'Google'});
  }
  if (readMicrosoftGraphClientIdFromEnvMap(env) != null) {
    items.add({'id': 'microsoft', 'label': 'Microsoft'});
  }
  final appleClientId = env['WADDLE_APPLE_CLIENT_ID']?.trim();
  if (appleClientId != null && appleClientId.isNotEmpty) {
    items.add({'id': 'apple', 'label': 'Apple'});
  }
  return Response.ok(
    jsonEncode({'items': items}),
    headers: {'content-type': 'application/json'},
  );
}

String? _bearerFromRequest(Request req) {
  final bearer = req.headers['authorization'] ?? '';
  if (!bearer.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  return bearer.substring(7).trim();
}

Response _badRequest(String code) => Response(
  400,
  body: '{"error":"$code"}',
  headers: {'content-type': 'application/json'},
);

Response _notFound() => Response(
  404,
  body: '{"error":"not_found"}',
  headers: {'content-type': 'application/json'},
);

String _randomHex(int bytes) {
  final r = Random.secure();
  return List<int>.generate(bytes, (_) => r.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}
