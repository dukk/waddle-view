import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/route_permissions.dart';
import 'package:waddle_shared/auth/role_permissions.dart';

void main() {
  test('maps screens GET to screens.read', () {
    expect(permissionForRoute('GET', '/v1/screens'), WaddlePermission.screensRead);
  });

  test('maps users to users.manage', () {
    expect(permissionForRoute('GET', '/v1/users'), WaddlePermission.usersManage);
  });

  test('password route has no permission gate', () {
    expect(permissionForRoute('POST', '/v1/users/u1/password'), isNull);
  });
}
