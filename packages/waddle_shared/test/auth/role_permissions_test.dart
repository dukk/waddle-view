import 'package:test/test.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('admin has users.manage', () {
    expect(userHasPermission(kUserRoleAdmin, WaddlePermission.usersManage), isTrue);
  });

  test('viewer cannot write screens', () {
    expect(userHasPermission(kUserRoleViewer, WaddlePermission.screensWrite), isFalse);
    expect(userHasPermission(kUserRoleViewer, WaddlePermission.screensRead), isTrue);
  });

  test('operator has navigation', () {
    expect(
      userHasPermission(kUserRoleOperator, WaddlePermission.navigationControl),
      isTrue,
    );
  });
}
