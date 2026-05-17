import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/config/adoption_allowed_roles.dart';
import 'package:waddle_shared/config/adoption_allow_new_requests.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('readAdoptionAllowedRoles defaults to all roles when keys absent', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    expect(
      await readAdoptionAllowedRoles(db),
      equals(kValidUserRoles),
    );
    expect(await readAdoptionAllowNewRequests(db), isTrue);
  });

  test('legacy adoption.allow_new_requests false blocks all roles', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowNewRequestsKvKey,
            value: 'false',
          ),
        );
    expect(await readAdoptionAllowedRoles(db), isEmpty);
    expect(await readAdoptionAllowNewRequests(db), isFalse);
  });

  test('adoption.allowed_roles kv restricts by role', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowedRolesKvKey,
            value: encodeAdoptionAllowedRoles({kUserRoleViewer}),
          ),
        );
    expect(await readAdoptionAllowedRoles(db), {kUserRoleViewer});
    expect(await isAdoptionRoleAllowed(db, kUserRoleViewer), isTrue);
    expect(await isAdoptionRoleAllowed(db, kUserRoleAdmin), isFalse);
  });

  test('encodeAdoptionAllowedRoles sorts in display order', () {
    expect(
      encodeAdoptionAllowedRoles({kUserRoleAdmin, kUserRoleViewer}),
      '["viewer","admin"]',
    );
  });
}
