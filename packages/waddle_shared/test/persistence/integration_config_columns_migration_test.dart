import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/config/integration_config_json.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 15 to 16 moves base_url into config_json and drops columns', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  base_url TEXT,
  config_json TEXT,
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
      raw.execute(
        "INSERT INTO integrations "
        "(id, integration_type, enabled, poll_seconds, base_url, config_json, "
        "config_json_schema, example_config_json) "
        "VALUES ('stock_test', 'stock_finnhub', 1, 60, 'https://finnhub.io', "
        "'{\"maxSymbolsPerCollect\":5}', '{}', '{\"sample\":true}')",
      );
      raw.execute('PRAGMA user_version = 15');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final columns = await db.customSelect('PRAGMA table_info(integrations)').get();
    final names = columns.map((c) => c.read<String>('name')).toSet();
    expect(names.contains('base_url'), isFalse);
    expect(names.contains('example_config_json'), isFalse);
    expect(names.contains('config_json'), isTrue);

    final row = await db.customSelect(
      'SELECT config_json FROM integrations WHERE id = ?',
      variables: [const Variable<String>('stock_test')],
    ).getSingle();
    expect(
      integrationBaseUrlFromConfigJson(row.read<String>('config_json')),
      'https://finnhub.io',
    );

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });
}
