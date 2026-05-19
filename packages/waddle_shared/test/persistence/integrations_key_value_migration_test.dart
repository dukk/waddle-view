import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/theme/display_program_history_kv.dart';

void main() {
  test('schema 20 to 21 migrates integration KV from config_key_values', () async {
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
CREATE TABLE integration_accounts (
  id TEXT NOT NULL PRIMARY KEY,
  account_type TEXT NOT NULL,
  label TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
      raw.execute('''
CREATE TABLE integration_account_links (
  integration_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  PRIMARY KEY (integration_id, account_id)
);
''');
      raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
      raw.execute(
        "INSERT INTO integrations (id, integration_type) "
        "VALUES ('default_photo_pexels', 'photo_pexels')",
      );
      raw.execute(
        "INSERT INTO integrations (id, integration_type) "
        "VALUES ('default_photo_onedrive', 'photo_onedrive')",
      );
      raw.execute(
        "INSERT INTO integration_accounts (id, account_type, created_at_ms) "
        "VALUES ('ms_acct', 'microsoft_graph', 1)",
      );
      raw.execute(
        "INSERT INTO integration_account_links (integration_id, account_id) "
        "VALUES ('default_photo_onedrive', 'ms_acct')",
      );
      raw.execute(
        "INSERT INTO config_key_values (key, value) VALUES "
        "('provider.default_photo_pexels.last_collect_ms', '12345')",
      );
      raw.execute(
        "INSERT INTO config_key_values (key, value) VALUES "
        "('microsoft.graph.access_token_expires_at_ms.ms_acct', '99999')",
      );
      raw.execute(
        "INSERT INTO config_key_values (key, value) VALUES "
        "('provider.media_onedrive.delta_link.ms_acct._root_', 'https://delta')",
      );
      raw.execute(
        "INSERT INTO config_key_values (key, value) VALUES "
        "('display.timezone', 'America/Chicago')",
      );
      raw.execute('PRAGMA user_version = 20');
    });

    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final migrated = await db.select(db.integrationsKeyValue).get();
    expect(migrated.length, 3);

    final collect = migrated.singleWhere(
      (r) => r.integrationId == 'default_photo_pexels',
    );
    expect(collect.key, kIntegrationLastCollectKey);
    expect(collect.value, '12345');
    expect(collect.valueType, kIntegrationKvTypeIntMs);

    final expires = migrated.singleWhere((r) => r.accountId == 'ms_acct');
    expect(expires.key, kIntegrationAccessTokenExpiresAtKey);
    expect(expires.value, '99999');

    final delta = migrated.singleWhere(
      (r) => r.integrationId == 'default_photo_onedrive',
    );
    expect(delta.key, 'delta_link._root_');
    expect(delta.value, 'https://delta');

    final legacy = await db.select(db.configKeyValues).get();
    expect(
      legacy.map((r) => r.key).toSet(),
      {
        'display.timezone',
        kDisplayProgramHistoryDepthKvKey,
      },
    );

    await db.close();
  });
}
