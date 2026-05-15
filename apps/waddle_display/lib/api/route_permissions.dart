import 'package:waddle_shared/auth/role_permissions.dart';

/// Resolves required permission for a protected REST route, or null if unknown.
String? permissionForRoute(String method, String path) {
  final p = path.startsWith('/') ? path : '/$path';
  final m = method.toUpperCase();

  if (p == '/v1/providers' && m == 'GET') {
    return WaddlePermission.providersRead;
  }
  if (p.startsWith('/v1/providers/') && m == 'PATCH') {
    return WaddlePermission.providersWrite;
  }

  if (p == '/v1/screens' && m == 'GET') {
    return WaddlePermission.screensRead;
  }
  if (p == '/v1/screens' && m == 'POST') {
    return WaddlePermission.screensWrite;
  }
  if (p.startsWith('/v1/screens/') && m == 'PATCH') {
    return WaddlePermission.screensWrite;
  }
  if (p.startsWith('/v1/screens/') && m == 'DELETE') {
    return WaddlePermission.screensWrite;
  }

  if (p == '/v1/ticker/items' && m == 'GET') {
    return WaddlePermission.tickerRead;
  }
  if (p == '/v1/ticker/definitions' && m == 'GET') {
    return WaddlePermission.tickerRead;
  }
  if (p.startsWith('/v1/ticker/definitions/') && m == 'PATCH') {
    return WaddlePermission.tickerWrite;
  }

  if (p == '/v1/curator/settings' && m == 'GET') {
    return WaddlePermission.curatorRead;
  }
  if (p == '/v1/curator/settings' && m == 'PUT') {
    return WaddlePermission.curatorWrite;
  }

  if (p == '/v1/alerts' && m == 'GET') {
    return WaddlePermission.alertsRead;
  }
  if (p == '/v1/alerts' && m == 'POST') {
    return WaddlePermission.alertsWrite;
  }
  if (p.startsWith('/v1/alerts/') && m == 'DELETE') {
    return WaddlePermission.alertsWrite;
  }

  if (p == '/v1/display/overlays' && m == 'GET') {
    return WaddlePermission.overlaysRead;
  }
  if (p == '/v1/display/overlays' && m == 'POST') {
    return WaddlePermission.overlaysWrite;
  }
  if (p.startsWith('/v1/display/overlays/') && m == 'PATCH') {
    return WaddlePermission.overlaysWrite;
  }
  if (p.startsWith('/v1/display/overlays/') && m == 'DELETE') {
    return WaddlePermission.overlaysWrite;
  }
  if (p == '/v1/display/navigation' && m == 'POST') {
    return WaddlePermission.navigationControl;
  }

  if (p.startsWith('/v1/content/') && m == 'PATCH') {
    return WaddlePermission.contentModerate;
  }

  if (p.startsWith('/v1/reject-terms')) {
    if (m == 'GET') {
      return WaddlePermission.rejectTermsManage;
    }
    return WaddlePermission.rejectTermsManage;
  }

  if (p.startsWith('/v1/telemetry/') && m == 'GET') {
    return WaddlePermission.telemetryRead;
  }
  if (p == '/v1/meta/screen-types' && m == 'GET') {
    return WaddlePermission.metaRead;
  }

  if (p == '/v1/auth/logout' && m == 'POST') {
    return null;
  }
  if (p == '/v1/auth/me' || p == '/v1/auth/permissions') {
    return null;
  }
  if (p.contains('/password') && m == 'POST') {
    return null;
  }
  if (p.startsWith('/v1/users')) {
    return WaddlePermission.usersManage;
  }

  return null;
}
