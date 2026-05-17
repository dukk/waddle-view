import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/auth/cors_origin_repository.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  late AppDatabase db;
  late CorsOriginRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CorsOriginRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('rememberAdoptionOrigin inserts once', () async {
    const now = 1_000_000;
    await repo.rememberAdoptionOrigin('http://localhost:5173', nowMs: now);
    await repo.rememberAdoptionOrigin('http://localhost:5173', nowMs: now + 1);
    final origins = await repo.loadAllOrigins();
    expect(origins, {'http://localhost:5173'});
    final row = await (db.select(db.corsAllowedOrigins)
          ..where((t) => t.origin.equals('http://localhost:5173')))
        .getSingle();
    expect(row.source, kCorsOriginSourceAdoption);
  });

  test('seedEnvOrigins and isOriginAllowed', () async {
    const now = 2_000_000;
    await repo.seedEnvOrigins(['http://127.0.0.1:5173'], nowMs: now);
    expect(await repo.isOriginAllowed('http://127.0.0.1:5173'), isTrue);
    expect(await repo.isOriginAllowed('http://evil.example:5173'), isFalse);
  });
}
