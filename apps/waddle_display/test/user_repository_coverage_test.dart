import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/auth/user_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';

import 'helpers/memory_database.dart';

void main() {
  test('session expiry and re-enable user', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final users = UserRepository(db);
    final u = await users.createNamedUser(
      username: 'reenable',
      password: 'password-12chars',
      role: kUserRoleViewer,
    );
    await users.createSession(
      userId: u.id,
      token: 'expired-tok',
      expiresAtMs: DateTime.now().millisecondsSinceEpoch - 1,
    );
    expect(await users.userForSessionToken('expired-tok'), isNull);

    await users.updateUser(id: u.id, disabled: true);
    await users.updateUser(id: u.id, disabled: false);
    expect((await users.findById(u.id))!.disabledAtMs, isNull);

    final listed = await users.listUsers();
    expect(listed.any((e) => e.username == 'reenable'), isTrue);

    expect(await users.setPassword(id: 'missing', newPassword: 'x'), isFalse);

    final admin = await users.createNamedUser(
      username: 'adminpw',
      password: 'password-12chars',
      role: kUserRoleAdmin,
    );
    final session = await users.createSession(
      userId: admin.id,
      token: 'admin-session',
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    );
    expect(session, isNotEmpty);
    await users.setPassword(id: u.id, newPassword: 'new-password-12');
    expect(await users.userForSessionToken('admin-session'), isNotNull);

    await db.close();
  });

  test('ensureBootstrapUser updates hash', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final users = UserRepository(db);
    await users.ensureBootstrapUser(instanceIdPassword: 'first');
    await users.ensureBootstrapUser(instanceIdPassword: 'second');
    final row = await users.findByUsername(kBootstrapUsername);
    expect(row, isNotNull);
    expect(await users.verifyLoginPassword(row!, 'second'), isTrue);
    await db.close();
  });

  test('findByUsername is case insensitive', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final users = UserRepository(db);
    await users.createNamedUser(
      username: 'CaseUser',
      password: 'password-12chars',
      role: kUserRoleViewer,
    );
    expect(await users.findByUsername('caseuser'), isNotNull);
    await db.close();
  });
}
