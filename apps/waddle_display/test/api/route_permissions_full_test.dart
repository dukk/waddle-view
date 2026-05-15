import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/route_permissions.dart';
import 'package:waddle_shared/auth/role_permissions.dart';

void main() {
  final cases = <(String, String, String)>[
    ('GET', '/v1/providers', WaddlePermission.providersRead),
    ('PATCH', '/v1/providers/p1', WaddlePermission.providersWrite),
    ('GET', '/v1/alerts', WaddlePermission.alertsRead),
    ('POST', '/v1/alerts', WaddlePermission.alertsWrite),
    ('DELETE', '/v1/alerts/1', WaddlePermission.alertsWrite),
    ('GET', '/v1/curator/settings', WaddlePermission.curatorRead),
    ('PUT', '/v1/curator/settings', WaddlePermission.curatorWrite),
    ('PATCH', '/v1/content/jokes/x', WaddlePermission.contentModerate),
    ('GET', '/v1/reject-terms', WaddlePermission.rejectTermsManage),
    ('POST', '/v1/reject-terms/rescan', WaddlePermission.rejectTermsManage),
    ('GET', '/v1/telemetry/programs', WaddlePermission.telemetryRead),
    ('POST', '/v1/display/navigation', WaddlePermission.navigationControl),
    ('GET', '/v1/display/overlays', WaddlePermission.overlaysRead),
    ('POST', '/v1/display/overlays', WaddlePermission.overlaysWrite),
    ('PATCH', '/v1/ticker/definitions/t1', WaddlePermission.tickerWrite),
  ];

  for (final (method, path, perm) in cases) {
    test('$method $path -> $perm', () {
      expect(permissionForRoute(method, path), perm);
    });
  }
}
