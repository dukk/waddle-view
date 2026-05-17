import 'package:test/test.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('admin has users.manage', () {
    expect(userHasPermission(kUserRoleAdmin, WaddlePermission.usersManage), isTrue);
  });

  test('power_viewer can read telemetry, navigate, and browse catalog (not moderate)', () {
    expect(
      userHasPermission(kUserRolePowerViewer, WaddlePermission.telemetryRead),
      isTrue,
    );
    expect(
      userHasPermission(kUserRolePowerViewer, WaddlePermission.navigationControl),
      isTrue,
    );
    expect(
      userHasPermission(kUserRolePowerViewer, WaddlePermission.contentCatalogRead),
      isTrue,
    );
    expect(
      userHasPermission(kUserRolePowerViewer, WaddlePermission.interestsRead),
      isTrue,
    );
    expect(
      userHasPermission(kUserRolePowerViewer, WaddlePermission.interestsWrite),
      isFalse,
    );
    expect(userHasPermission(kUserRolePowerViewer, WaddlePermission.contentModerate), isFalse);
    expect(userHasPermission(kUserRolePowerViewer, WaddlePermission.screensRead), isFalse);
    expect(userHasPermission(kUserRolePowerViewer, WaddlePermission.usersManage), isFalse);
    expect(
      userHasPermission(kUserRolePowerViewer, WaddlePermission.rejectTermsManage),
      isFalse,
    );
  });

  test('viewer cannot write screens or read operator surfaces', () {
    expect(userHasPermission(kUserRoleViewer, WaddlePermission.screensWrite), isFalse);
    expect(userHasPermission(kUserRoleViewer, WaddlePermission.screensRead), isFalse);
    expect(userHasPermission(kUserRoleViewer, WaddlePermission.integrationsRead), isFalse);
    expect(userHasPermission(kUserRoleViewer, WaddlePermission.curatorRead), isFalse);
    expect(userHasPermission(kUserRoleViewer, WaddlePermission.navigationControl), isFalse);
  });

  test('viewer can read telemetry and media (programs)', () {
    expect(userHasPermission(kUserRoleViewer, WaddlePermission.telemetryRead), isTrue);
  });

  test('operator has navigation', () {
    expect(
      userHasPermission(kUserRoleOperator, WaddlePermission.navigationControl),
      isTrue,
    );
  });
}
