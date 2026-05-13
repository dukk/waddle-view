import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('Drift dateTime columns round-trip instants (INTEGER ms in SQLite)', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final t = DateTime.utc(2024, 3, 15, 14, 30, 5);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'dt_test',
            sha256: 'x',
            relativePath: 'p/x',
            bytes: 1,
            capturedAt: t,
          ),
        );
    final row = await (db.select(db.blobMetadata)
          ..where((b) => b.blobKey.equals('dt_test')))
        .getSingle();
    expect(row.capturedAt.millisecondsSinceEpoch, t.millisecondsSinceEpoch);
    await db.close();
  });
}
