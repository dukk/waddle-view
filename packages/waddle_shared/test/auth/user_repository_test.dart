import 'package:test/test.dart';
import 'package:waddle_shared/auth/user_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart' show openMemoryDatabase;

void main() {
  test('createNamedUser disables bootstrap after first user', () async {
    final db = openMemoryDatabase();
    final users = UserRepository(db);
    await users.ensureBootstrapUser(instanceIdPassword: 'inst');
    expect(await users.bootstrapLoginAllowed(), isTrue);

    await users.createNamedUser(
      username: 'alice',
      password: 'password-12chars',
      role: kUserRoleAdmin,
    );
    expect(await users.bootstrapLoginAllowed(), isFalse);
    final display = await users.findByUsername(kBootstrapUsername);
    expect(display!.disabledAtMs, isNotNull);
    await db.close();
  });

  test('verifyLoginPassword rejects disabled user', () async {
    final db = openMemoryDatabase();
    final users = UserRepository(db);
    final u = await users.createNamedUser(
      username: 'disabled_user',
      password: 'password-12chars',
      role: kUserRoleViewer,
    );
    await users.updateUser(id: u.id, disabled: true);
    expect(await users.verifyLoginPassword(u, 'password-12chars'), isFalse);
    await db.close();
  });

  test('createNamedUser rejects display username', () async {
    final db = openMemoryDatabase();
    final users = UserRepository(db);
    expect(
      () => users.createNamedUser(
        username: kBootstrapUsername,
        password: 'password-12chars',
        role: kUserRoleAdmin,
      ),
      throwsA(isA<ArgumentError>()),
    );
    await db.close();
  });
}
