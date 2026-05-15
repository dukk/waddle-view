import 'package:shelf/shelf.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/auth/user_repository.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../debug/app_debug_log.dart';
import 'route_permissions.dart';

/// Shelf context key for the authenticated [User] on protected routes.
const String kAuthUserContextKey = 'waddle.auth.user';

Middleware sessionAuth(UserRepository users) {
  return (Handler inner) {
    return (Request request) async {
      final token = _bearerToken(request);
      if (token == null || token.isEmpty) {
        AppDebugLog.api('401 ${request.requestedUri.path} missing session');
        return _jsonUnauthorized();
      }
      final user = await users.userForSessionToken(token);
      if (user == null) {
        AppDebugLog.api('401 ${request.requestedUri.path} invalid session');
        return _jsonUnauthorized();
      }
      return inner(request.change(context: {kAuthUserContextKey: user}));
    };
  };
}

/// Enforces [permissionForRoute] for the current request after [sessionAuth].
Middleware routePermissionGuard() {
  return (Handler inner) {
    return (Request request) async {
      final user = request.context[kAuthUserContextKey] as User?;
      if (user == null) {
        return _jsonUnauthorized();
      }
      final perm = permissionForRoute(request.method, request.requestedUri.path);
      if (perm != null && !userHasPermission(user.role, perm)) {
        AppDebugLog.api('403 ${request.requestedUri.path} forbidden');
        return _jsonForbidden();
      }
      return inner(request);
    };
  };
}

User? authUser(Request request) =>
    request.context[kAuthUserContextKey] as User?;

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
