import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 25 legacy integrations migrate through integration_types trim', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  config_json TEXT,
  config_json_schema TEXT,
  requires_accounts INTEGER NOT NULL DEFAULT 0,
  accounts_ready INTEGER NOT NULL DEFAULT 1
);
''');
      raw.execute(
        "INSERT INTO integrations "
        "(id, integration_type, enabled, poll_seconds, config_json, "
        "config_json_schema, requires_accounts, accounts_ready) "
        "VALUES ('news_rss', 'news_rss', 1, 3600, '{}', "
        "'{\"type\":\"object\"}', 0, 1)",
      );
      raw.execute(
        "INSERT INTO integrations "
        "(id, integration_type, enabled, poll_seconds, config_json, "
        "config_json_schema, requires_accounts, accounts_ready) "
        "VALUES ('cal_google', 'calendar_google', 0, 60, '{}', "
        "NULL, 1, 0)",
      );
      raw.execute('''
CREATE TABLE calendar_event_categories (
  event_id TEXT NOT NULL,
  category_id TEXT NOT NULL,
  PRIMARY KEY (event_id, category_id)
);
''');
      raw.execute('PRAGMA user_version = 25');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final typeRows = await db.customSelect(
      'SELECT integration_type, label, requires_accounts, config_json_schema '
      'FROM integration_types ORDER BY integration_type',
    ).get();
    expect(typeRows.length >= 2, isTrue);

    final newsType = typeRows.firstWhere(
      (r) => r.read<String>('integration_type') == 'news_rss',
    );
    expect(newsType.read<int>('requires_accounts'), 0);
    expect(newsType.read<String>('label'), isNotEmpty);
    expect(newsType.read<String?>('config_json_schema'), contains('object'));

    final calType = typeRows.firstWhere(
      (r) => r.read<String>('integration_type') == 'calendar_google',
    );
    expect(calType.read<int>('requires_accounts'), 1);

    final integrationColumns = await db.customSelect(
      'PRAGMA table_info(integrations)',
    ).get();
    final names = integrationColumns.map((c) => c.read<String>('name')).toSet();
    expect(names.contains('config_json_schema'), isFalse);
    expect(names.contains('requires_accounts'), isFalse);
    expect(names.contains('accounts_ready'), isFalse);

    final calRow = await db.customSelect(
      'SELECT enabled FROM integrations WHERE id = ?',
      variables: [const Variable<String>('cal_google')],
    ).getSingle();
    expect(calRow.read<int>('enabled'), 0);

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
