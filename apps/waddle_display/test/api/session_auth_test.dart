import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:waddle_display/api/session_auth.dart';
import 'package:waddle_shared/auth/user_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart' show openMemoryDatabase, warmDatabase;

void main() {
  test('sessionAuth rejects missing bearer', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final users = UserRepository(db);
    var called = false;
    final handler = sessionAuth(users)((Request req) async {
      called = true;
      return Response.ok('ok');
    });
    final res = await handler(Request('GET', Uri.parse('http://x/v1/integrations')));
    expect(res.statusCode, 401);
    expect(called, isFalse);
    await db.close();
  });

  test('sessionAuth rejects invalid bearer', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final users = UserRepository(db);
    var called = false;
    final handler = sessionAuth(users)((Request req) async {
      called = true;
      return Response.ok('ok');
    });
    final res = await handler(
      Request(
        'GET',
        Uri.parse('http://x/v1/integrations'),
        headers: {'authorization': 'Bearer not-a-real-token'},
      ),
    );
    expect(res.statusCode, 401);
    expect(called, isFalse);
    await db.close();
  });

  test('sessionAuth accepts valid bearer', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final users = UserRepository(db);
    final user = await users.createNamedUser(
      username: 'sessuser',
      password: 'password-12chars',
      role: kUserRoleViewer,
    );
    await users.createSession(
      userId: user.id,
      token: 'valid-tok',
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    );
    final handler = sessionAuth(users)((Request req) async {
      expect(authUser(req)?.username, 'sessuser');
      return Response.ok('ok');
    });
    final res = await handler(
      Request(
        'GET',
        Uri.parse('http://x/v1/integrations'),
        headers: {'authorization': 'Bearer valid-tok'},
      ),
    );
    expect(res.statusCode, 200);
    await db.close();
  });
}
