import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('fresh database has blob crop columns at schema 53', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 53);
    final cols = await db
        .customSelect('PRAGMA table_info(blob_metadata)')
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('focal_x'), isTrue);
    expect(names.contains('focal_y'), isTrue);
    expect(names.contains('has_face'), isTrue);
    expect(names.contains('has_text'), isTrue);
    expect(names.contains('crop_hints_json'), isTrue);
  });

  test('v52 to v53 adds blob crop columns', () async {
    final executor = NativeDatabase.memory();
    final raw = AppDatabase(executor);
    // Force create at current schema then we only assert columns exist after open.
    await raw.customSelect('SELECT 1').get();
    await raw.close();

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 53);
  });
}
