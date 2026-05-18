import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:waddle_display/api/api_key_auth.dart';
import 'package:waddle_shared/auth/adoption_crypto.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  const instanceId = 'api-key-auth-test-instance-id-0123456789ab';

  test('apiKeyAuth rejects missing bearer', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final adoption = AdoptionRepository(db, instanceId: instanceId);
    final handler = apiKeyAuth(adoption)((Request req) async {
      return Response.ok('ok');
    });
    final res = await handler(
      Request('GET', Uri.parse('http://localhost/v1/screens')),
    );
    expect(res.statusCode, 401);
  });

  test('apiKeyAuth rejects invalid bearer', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    final adoption = AdoptionRepository(db, instanceId: instanceId);
    final handler = apiKeyAuth(adoption)((Request req) async {
      return Response.ok('ok');
    });
    final res = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/v1/screens'),
        headers: {'Authorization': 'Bearer not-a-real-key'},
      ),
    );
    expect(res.statusCode, 401);
  });

  test('apiKeyAuth accepts valid bearer', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    const apiKey = 'test-api-key-value';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.apiClients).insert(
      ApiClientsCompanion.insert(
        id: 'c1',
        identifier: 'laptop',
        role: kUserRoleOperator,
        apiKeyHash: hashAdoptionApiKey(apiKey),
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    final adoption = AdoptionRepository(db, instanceId: instanceId);
    final handler = apiKeyAuth(adoption)((Request req) async {
      expect(apiClientRole(req), kUserRoleOperator);
      expect(apiClientIdentifier(req), 'laptop');
      return Response.ok('ok');
    });
    final res = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/v1/screens'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ),
    );
    expect(res.statusCode, 200);
  });
}
