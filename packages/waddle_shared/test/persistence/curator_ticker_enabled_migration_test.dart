import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 11 to 12 adds curator_configurations.ticker_enabled default true', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE curator_configurations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  layer TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  program_duration_seconds INTEGER NOT NULL DEFAULT 180,
  history_depth INTEGER NOT NULL DEFAULT 5,
  require_news_photo_for_screens INTEGER NOT NULL DEFAULT 1,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO curator_configurations (id, name, layer) "
        "VALUES ('evening', 'Evening', 'base')",
      );
      raw.execute('PRAGMA user_version = 11');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final row = await db.customSelect(
      'SELECT ticker_enabled FROM curator_configurations WHERE id = ?',
      variables: [Variable<String>('evening')],
    ).getSingle();
    expect(row.read<int>('ticker_enabled'), 1);

    await db.close();
  });
}
