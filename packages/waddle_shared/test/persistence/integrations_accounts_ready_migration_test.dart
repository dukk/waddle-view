import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 22 legacy integrations migrate to configured view', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  config_json TEXT,
  config_json_schema TEXT
);
''');
      raw.execute(
        "INSERT INTO integrations (id, integration_type, enabled) "
        "VALUES ('news_rss', 'news_rss', 1)",
      );
      raw.execute(
        "INSERT INTO integrations (id, integration_type, enabled) "
        "VALUES ('cal_google', 'calendar_google', 0)",
      );
      raw.execute('PRAGMA user_version = 22');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final integrationColumns = await db.customSelect(
      'PRAGMA table_info(integrations)',
    ).get();
    final names = integrationColumns.map((c) => c.read<String>('name')).toSet();
    expect(names.contains('accounts_ready'), isFalse);
    expect(names.contains('requires_accounts'), isFalse);
    expect(names.contains('config_json_schema'), isFalse);

    final calType = await db.customSelect(
      'SELECT requires_accounts FROM integration_types WHERE integration_type = ?',
      variables: [const Variable<String>('calendar_google')],
    ).getSingle();
    expect(calType.read<int>('requires_accounts'), 1);

    final calendar = await db.customSelect(
      'SELECT enabled FROM integrations WHERE id = ?',
      variables: [const Variable<String>('cal_google')],
    ).getSingle();
    expect(calendar.read<int>('enabled'), 0);

    final view = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'view' "
      "AND name = 'v_integration_accounts_configured'",
    ).get();
    expect(view, isNotEmpty);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });
}
