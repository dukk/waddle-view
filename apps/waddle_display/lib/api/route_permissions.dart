import 'package:waddle_shared/auth/role_permissions.dart';

/// Resolves required permission for a protected REST route, or null if unknown.
String? permissionForRoute(String method, String path) {
  final p = path.startsWith('/') ? path : '/$path';
  final m = method.toUpperCase();

  if (p == '/v1/integrations' && m == 'GET') {
    return WaddlePermission.integrationsRead;
  }
  if (p == '/v1/integration-accounts' && (m == 'GET' || m == 'POST')) {
    return m == 'GET'
        ? WaddlePermission.integrationsRead
        : WaddlePermission.integrationsWrite;
  }
  if (p == '/v1/oauth-providers' && m == 'GET') {
    return WaddlePermission.integrationsRead;
  }
  if (RegExp(r'^/v1/oauth-providers/[^/]+/client-id$').hasMatch(p) && m == 'PUT') {
    return WaddlePermission.integrationsWrite;
  }
  final integrationAccountSecrets =
      RegExp(r'^/v1/integration-accounts/[^/]+/secrets(?:/[^/]+)?$');
  if (integrationAccountSecrets.hasMatch(p)) {
    if (m == 'GET') {
      return WaddlePermission.integrationsRead;
    }
    if (m == 'PUT' || m == 'DELETE') {
      return WaddlePermission.integrationsWrite;
    }
  }
  if (RegExp(r'^/v1/integration-accounts/[^/]+/request-sign-in$').hasMatch(p) &&
      m == 'POST') {
    return WaddlePermission.integrationsWrite;
  }
  if (RegExp(r'^/v1/integrations/[^/]+/accounts$').hasMatch(p) && m == 'GET') {
    return WaddlePermission.integrationsRead;
  }
  final integrationSecrets = RegExp(r'^/v1/integrations/[^/]+/secrets(?:/[^/]+)?$');
  if (integrationSecrets.hasMatch(p)) {
    if (m == 'GET') {
      return WaddlePermission.integrationsRead;
    }
    if (m == 'PUT' || m == 'DELETE') {
      return WaddlePermission.integrationsWrite;
    }
  }
  if (p.startsWith('/v1/integrations/') && m == 'PATCH') {
    return WaddlePermission.integrationsWrite;
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
  if (p == '/v1/ticker/tapes' && m == 'GET') {
    return WaddlePermission.tickerRead;
  }
  if (p == '/v1/ticker/tapes' && m == 'POST') {
    return WaddlePermission.tickerWrite;
  }
  if (p.startsWith('/v1/ticker/tapes/') && m == 'PATCH') {
    return WaddlePermission.tickerWrite;
  }
  if (p.startsWith('/v1/ticker/tapes/') && m == 'DELETE') {
    return WaddlePermission.tickerWrite;
  }

  if (p == '/v1/curator/settings' && m == 'GET') {
    return WaddlePermission.curatorRead;
  }
  if (p == '/v1/curator/settings' && m == 'PUT') {
    return WaddlePermission.curatorWrite;
  }

  if (p == '/v1/config/key-values' && m == 'GET') {
    return WaddlePermission.curatorRead;
  }
  if (p == '/v1/config/key-values' && m == 'PUT') {
    return WaddlePermission.curatorWrite;
  }
  if (p == '/v1/config/key-values' && m == 'DELETE') {
    return WaddlePermission.curatorWrite;
  }

  if (p == '/v1/curator/categories' && m == 'GET') {
    return WaddlePermission.curatorRead;
  }
  if (p == '/v1/curator/categories' && m == 'POST') {
    return WaddlePermission.curatorWrite;
  }
  if (p.startsWith('/v1/curator/categories/') && m == 'PATCH') {
    return WaddlePermission.curatorWrite;
  }
  if (p.startsWith('/v1/curator/categories/') && m == 'DELETE') {
    return WaddlePermission.curatorWrite;
  }

  if (p == '/v1/runtime/signals' && m == 'GET') {
    return WaddlePermission.curatorRead;
  }
  if (p.startsWith('/v1/runtime/signals/') && m == 'PUT') {
    return WaddlePermission.curatorWrite;
  }
  if (p == '/v1/plugins' && m == 'GET') {
    return WaddlePermission.integrationsRead;
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

  if (p.startsWith('/v1/media/') && m == 'GET') {
    return WaddlePermission.telemetryRead;
  }

  if (p.startsWith('/v1/interests/') && m == 'GET') {
    return WaddlePermission.interestsRead;
  }
  if (p.startsWith('/v1/interests/') &&
      (m == 'POST' || m == 'PATCH' || m == 'DELETE')) {
    return WaddlePermission.interestsWrite;
  }

  if (p.startsWith('/v1/catalog/') && m == 'GET') {
    return WaddlePermission.contentCatalogRead;
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
  if (p == '/v1/meta/ticker-types' && m == 'GET') {
    return WaddlePermission.metaRead;
  }

  if (p == '/v1/adoption/session' && m == 'GET') {
    return null;
  }
  if (p == '/v1/adoption/clients' && m == 'GET') {
    return WaddlePermission.usersManage;
  }
  if (p == '/v1/adoption/clients' && m == 'POST') {
    return WaddlePermission.usersManage;
  }
  if (p.startsWith('/v1/adoption/clients/') && m == 'DELETE') {
    return WaddlePermission.usersManage;
  }

  return null;
}

/// Whether [role] satisfies [permissionForRoute]'s [perm] (handles OR cases, e.g. catalog GET).
bool roleSatisfiesRoutePermission(String role, String? perm) {
  if (perm == null) return true;
  if (perm == WaddlePermission.contentCatalogRead) {
    return userHasPermission(role, WaddlePermission.contentModerate) ||
        userHasPermission(role, WaddlePermission.contentCatalogRead);
  }
  return userHasPermission(role, perm);
}
