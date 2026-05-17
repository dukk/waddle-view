import 'package:shelf/shelf.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import '../debug/app_debug_log.dart';
import 'route_permissions.dart';

/// Shelf context key for the authenticated API client role.
const String kApiClientRoleContextKey = 'waddle.auth.client_role';

/// Shelf context key for the authenticated API client identifier.
const String kApiClientIdentifierContextKey = 'waddle.auth.client_identifier';

Middleware apiKeyAuth(AdoptionRepository adoption) {
  return (Handler inner) {
    return (Request request) async {
      final token = _bearerToken(request);
      if (token == null || token.isEmpty) {
        AppDebugLog.api('401 ${request.requestedUri.path} missing api key');
        return _jsonUnauthorized();
      }
      final client = await adoption.clientForApiKey(token);
      if (client == null) {
        AppDebugLog.api('401 ${request.requestedUri.path} invalid api key');
        return _jsonUnauthorized();
      }
      return inner(
        request.change(
          context: {
            kApiClientRoleContextKey: client.role,
            kApiClientIdentifierContextKey: client.identifier,
          },
        ),
      );
    };
  };
}

/// Enforces [permissionForRoute] for the current request after [apiKeyAuth].
Middleware routePermissionGuard() {
  return (Handler inner) {
    return (Request request) async {
      final role = request.context[kApiClientRoleContextKey] as String?;
      if (role == null) {
        return _jsonUnauthorized();
      }
      final perm = permissionForRoute(
        request.method,
        request.requestedUri.path,
      );
      if (perm != null && !roleSatisfiesRoutePermission(role, perm)) {
        AppDebugLog.api('403 ${request.requestedUri.path} forbidden');
        return _jsonForbidden();
      }
      return inner(request);
    };
  };
}

String? apiClientRole(Request request) =>
    request.context[kApiClientRoleContextKey] as String?;

String? apiClientIdentifier(Request request) =>
    request.context[kApiClientIdentifierContextKey] as String?;

String? _bearerToken(Request request) {
  final bearer = request.headers['authorization'] ?? '';
  if (!bearer.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  return bearer.substring(7).trim();
}

Response _jsonUnauthorized() => Response.unauthorized(
  '{"error":"unauthorized"}',
  headers: {'content-type': 'application/json'},
);

Response _jsonForbidden() => Response(
  403,
  body: '{"error":"forbidden"}',
  headers: {'content-type': 'application/json'},
);
