import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/route_permissions.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('catalog GET allows moderate or catalog_read', () {
    expect(
      roleSatisfiesRoutePermission(kUserRoleOperator, WaddlePermission.contentCatalogRead),
      isTrue,
    );
    expect(
      roleSatisfiesRoutePermission(kUserRolePowerViewer, WaddlePermission.contentCatalogRead),
      isTrue,
    );
    expect(
      roleSatisfiesRoutePermission(kUserRoleViewer, WaddlePermission.contentCatalogRead),
      isFalse,
    );
  });
}
