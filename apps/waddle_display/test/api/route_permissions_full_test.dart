import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/route_permissions.dart';
import 'package:waddle_shared/auth/role_permissions.dart';

void main() {
  final cases = <(String, String, String)>[
    ('GET', '/v1/integrations', WaddlePermission.integrationsRead),
    ('PATCH', '/v1/integrations/p1', WaddlePermission.integrationsWrite),
    ('GET', '/v1/alerts', WaddlePermission.alertsRead),
    ('POST', '/v1/alerts', WaddlePermission.alertsWrite),
    ('DELETE', '/v1/alerts/1', WaddlePermission.alertsWrite),
    ('GET', '/v1/curator/settings', WaddlePermission.curatorRead),
    ('PUT', '/v1/curator/settings', WaddlePermission.curatorWrite),
    ('GET', '/v1/curator/categories', WaddlePermission.curatorRead),
    ('POST', '/v1/curator/categories', WaddlePermission.curatorWrite),
    ('PATCH', '/v1/curator/categories/x', WaddlePermission.curatorWrite),
    ('DELETE', '/v1/curator/categories/x', WaddlePermission.curatorWrite),
    ('GET', '/v1/config/key-values', WaddlePermission.curatorRead),
    ('PUT', '/v1/config/key-values', WaddlePermission.curatorWrite),
    ('DELETE', '/v1/config/key-values', WaddlePermission.curatorWrite),
    ('PATCH', '/v1/content/jokes/x', WaddlePermission.contentModerate),
    ('GET', '/v1/catalog/jokes', WaddlePermission.contentCatalogRead),
    ('GET', '/v1/catalog/rss-feeds', WaddlePermission.contentCatalogRead),
    ('GET', '/v1/reject-terms', WaddlePermission.rejectTermsManage),
    ('POST', '/v1/reject-terms/rescan', WaddlePermission.rejectTermsManage),
    ('GET', '/v1/telemetry/programs', WaddlePermission.telemetryRead),
    ('GET', '/v1/media/blob-by-key', WaddlePermission.telemetryRead),
    ('GET', '/v1/media/rss-articles/x', WaddlePermission.telemetryRead),
    ('GET', '/v1/media/weather-at-location/x', WaddlePermission.telemetryRead),
    ('POST', '/v1/display/navigation', WaddlePermission.navigationControl),
    ('GET', '/v1/display/overlays', WaddlePermission.overlaysRead),
    ('POST', '/v1/display/overlays', WaddlePermission.overlaysWrite),
    ('GET', '/v1/ticker/tapes', WaddlePermission.tickerRead),
    ('POST', '/v1/ticker/tapes', WaddlePermission.tickerWrite),
    ('PATCH', '/v1/ticker/tapes/t1', WaddlePermission.tickerWrite),
    ('DELETE', '/v1/ticker/tapes/t1', WaddlePermission.tickerWrite),
    ('GET', '/v1/meta/ticker-types', WaddlePermission.metaRead),
  ];

  for (final (method, path, perm) in cases) {
    test('$method $path -> $perm', () {
      expect(permissionForRoute(method, path), perm);
    });
  }
}
