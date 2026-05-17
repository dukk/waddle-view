import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/auth/cors_origin_repository.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/persistence/tables.dart';

import 'api_key_auth.dart';
import 'caller_origin.dart';

const int _maxIdentifierLength = 128;

void registerAdoptionClientRoutes(
  Router r, {
  required AdoptionRepository adoption,
  CorsOriginRepository? corsOrigins,
}) {
  r.get('/v1/adoption/session', (Request req) async {
    final role = apiClientRole(req);
    final identifier = apiClientIdentifier(req);
    if (role == null || identifier == null) {
      return _jsonError(401, 'unauthorized');
    }
    return Response.ok(
      jsonEncode({
        'identifier': identifier,
        'role': role,
        'permissions': permissionsForRole(role),
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/adoption/clients', (Request req) async {
    final items = await adoption.listClients();
    return Response.ok(
      jsonEncode({
        'items': [
          for (final c in items)
            {
              'id': c.id,
              'identifier': c.identifier,
              'role': c.role,
              'masked_api_key': c.maskedApiKey,
              'created_at_ms': c.createdAtMs,
              'updated_at_ms': c.updatedAtMs,
            },
        ],
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/adoption/clients', (Request req) async {
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
  });

  r.delete('/v1/adoption/clients/<id>', (Request req, String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return _jsonError(400, 'invalid_id');
    }
    final revoked = await adoption.revokeClient(trimmed);
    if (!revoked) {
      return _jsonError(404, 'not_found');
    }
    return Response.ok(
      jsonEncode({'revoked': true, 'id': trimmed}),
      headers: {'content-type': 'application/json'},
    );
  });
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
