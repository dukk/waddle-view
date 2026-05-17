import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 2 to 3 adds secret tables and disables env-dependent integrations',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  provider_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  base_url TEXT,
  config_json TEXT,
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
      for (final id in kIntegrationsDisabledOnSecretStoreMigration) {
        raw.execute(
          "INSERT INTO integrations (id, provider_type, enabled) "
          "VALUES ('$id', '$id', 1)",
        );
      }
      raw.execute(
        "INSERT INTO integrations (id, provider_type, enabled) "
        "VALUES ('news_rss', 'news_rss', 1)",
      );
      raw.execute('PRAGMA user_version = 2');
    });
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    await db.customStatement('SELECT 1');

    final secretTables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('integration_secrets', 'secret_store_meta')",
    ).get();
    expect(secretTables.length, 2);

    for (final id in kIntegrationsDisabledOnSecretStoreMigration) {
      final row = await db.customSelect(
        'SELECT enabled FROM integrations WHERE id = ?',
        variables: [Variable<String>(id)],
      ).getSingle();
      expect(row.read<int>('enabled'), 0);
    }

    final rss = await db.customSelect(
      'SELECT enabled FROM integrations WHERE id = ?',
      variables: [Variable<String>('news_rss')],
    ).getSingle();
    expect(rss.read<int>('enabled'), 1);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), greaterThanOrEqualTo(3));

    await db.close();
  });
}
