import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 22 to 23 adds requires_accounts and accounts_ready columns', () async {
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
      raw.execute('''
CREATE TABLE integration_account_links (
  integration_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  PRIMARY KEY (integration_id, account_id)
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

    final news = await db.customSelect(
      'SELECT requires_accounts, accounts_ready FROM integrations WHERE id = ?',
      variables: [const Variable<String>('news_rss')],
    ).getSingle();
    expect(news.read<int>('requires_accounts'), 0);
    expect(news.read<int>('accounts_ready'), 1);

    final calendar = await db.customSelect(
      'SELECT requires_accounts, accounts_ready FROM integrations WHERE id = ?',
      variables: [const Variable<String>('cal_google')],
    ).getSingle();
    expect(calendar.read<int>('requires_accounts'), 1);
    expect(calendar.read<int>('accounts_ready'), 0);

    final indexRows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name = 'idx_integrations_enabled_accounts'",
    ).get();
    expect(indexRows, isNotEmpty);

    await db.close();
  });
}
