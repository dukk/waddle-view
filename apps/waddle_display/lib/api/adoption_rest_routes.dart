import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/auth/cors_origin_repository.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/config/adoption_allowed_roles.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../alerts/alert_repository.dart';
import 'caller_origin.dart';

const int _maxIdentifierLength = 128;

void registerAdoptionRoutes(
  Router r, {
  required AppDatabase db,
  required AdoptionRepository? adoption,
  required AlertRepository alerts,
  CorsOriginRepository? corsOrigins,
}) {
  r.post('/v1/adoption/request', (Request req) async {
    return _request(
      req,
      db: db,
      adoption: adoption,
      alerts: alerts,
      corsOrigins: corsOrigins,
    );
  });
  r.post('/v1/adoption/confirm', (Request req) async {
    return _confirm(
      req,
      adoption: adoption,
      alerts: alerts,
      corsOrigins: corsOrigins,
    );
  });
}

Future<Response> _request(
  Request req, {
  required AppDatabase db,
  required AdoptionRepository? adoption,
  required AlertRepository alerts,
  CorsOriginRepository? corsOrigins,
}) async {
  if (adoption == null) {
    return _jsonError(503, 'adoption_unavailable');
  }
  final body = await _readJsonObject(req);
  if (body == null) {
    return _jsonError(400, 'invalid_json');
  }
  final identifier = _parseIdentifier(body['identifier']);
  if (identifier == null) {
    return _jsonError(400, 'invalid_identifier');
  }
  final role = _parseRole(body['role']);
  if (role == null) {
    return _jsonError(400, 'invalid_role');
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final referrer = callerOriginFromRequest(req);

  final bearer = _bearerToken(req);
  if (bearer != null && bearer.isNotEmpty) {
    final client = await adoption.clientForApiKey(bearer);
    if (client == null) {
      return _jsonError(401, 'unauthorized');
    }
    if (client.role != kUserRoleAdmin) {
      return _jsonError(403, 'forbidden');
    }
    try {
      final granted = await adoption.grantInstant(
        identifier: identifier,
        role: role,
        nowMs: nowMs,
        referrerOrigin: referrer,
      );
      if (corsOrigins != null) {
        await corsOrigins.rememberAdoptionOrigin(referrer, nowMs: nowMs);
      }
      return Response.ok(
        jsonEncode(_confirmJson(granted)),
        headers: {'content-type': 'application/json'},
      );
    } catch (_) {
      return _jsonError(500, 'adoption_grant_failed');
    }
  }

  if (!await isAdoptionRoleAllowed(db, role)) {
    return _jsonError(403, 'adoption_role_not_allowed');
  }

  try {
    final result = await adoption.startRequest(
      identifier: identifier,
      role: role,
      nowMs: nowMs,
      insertAlert: ({
        required String title,
        required String body,
        required int expiresAtMs,
      }) =>
          alerts.insertAlert(
            title: title,
            body: body,
            severity: 'security',
            priority: 100,
            expiresAtMs: expiresAtMs,
            source: kAdoptionAlertSource,
          ),
    );
    return Response.ok(
      jsonEncode({
        'expires_at_ms': result.expiresAtMs,
        'identifier': result.identifier,
        'role': result.role,
      }),
      headers: {'content-type': 'application/json'},
    );
  } catch (_) {
    return _jsonError(500, 'adoption_request_failed');
  }
}

Future<Response> _confirm(
  Request req, {
  required AdoptionRepository? adoption,
  required AlertRepository alerts,
  CorsOriginRepository? corsOrigins,
}) async {
  if (adoption == null) {
    return _jsonError(503, 'adoption_unavailable');
  }
  final body = await _readJsonObject(req);
  if (body == null) {
    return _jsonError(400, 'invalid_json');
  }
  final identifier = _parseIdentifier(body['identifier']);
  if (identifier == null) {
    return _jsonError(400, 'invalid_identifier');
  }
  final challengeCode = body['challenge_code'];
  if (challengeCode is! String || challengeCode.trim().isEmpty) {
    return _jsonError(400, 'invalid_challenge_code');
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final referrer = callerOriginFromRequest(req);
  final confirmed = await adoption.confirm(
    identifier: identifier,
    challengeCode: challengeCode,
    nowMs: nowMs,
    dismissAlert: alerts.dismiss,
    referrerOrigin: referrer,
  );
  if (confirmed == null) {
    return _jsonError(401, 'invalid_challenge');
  }

  if (corsOrigins != null) {
    await corsOrigins.rememberAdoptionOrigin(referrer, nowMs: nowMs);
  }

  return Response.ok(
    jsonEncode(_confirmJson(confirmed)),
    headers: {'content-type': 'application/json'},
  );
}

Map<String, Object?> _confirmJson(AdoptionConfirmResult result) => {
      'api_key': result.apiKey,
      'identifier': result.identifier,
      'role': result.role,
      'permissions': result.permissions,
    };

String? _parseIdentifier(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.length > _maxIdentifierLength) {
    return null;
  }
  return trimmed;
}

String? _parseRole(Object? raw) {
  if (raw == null) {
    return kUserRoleOperator;
  }
  if (raw is! String) {
    return null;
  }
  final role = raw.trim();
  if (!isValidUserRole(role)) {
    return null;
  }
  return role;
}

String? _bearerToken(Request request) {
  final bearer = request.headers['authorization'] ?? '';
  if (!bearer.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  return bearer.substring(7).trim();
}

Future<Map<String, dynamic>?> _readJsonObject(Request req) async {
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  } catch (_) {
    return null;
  }
}

Response _jsonError(int status, String error) => Response(
  status,
  body: jsonEncode({'error': error}),
  headers: {'content-type': 'application/json'},
);
