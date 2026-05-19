import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_configured_sql.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/db_encrypted_secret_store.dart';
import 'package:waddle_shared/secrets/platform/in_memory_dek_protector.dart';

import '../helpers/memory_database.dart';

void main() {
  test('schema 31 to 32 drops accounts_ready and adds configured view', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE integration_types (
  integration_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT,
  requires_accounts INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO integration_types (integration_type, label, requires_accounts) "
        "VALUES ('calendar_outlook', 'Outlook Calendar', 1)",
      );
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  config_json TEXT,
  accounts_ready INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO integrations (id, integration_type, enabled, accounts_ready) "
        "VALUES ('outlook_home', 'calendar_outlook', 0, 0)",
      );
      raw.execute('''
CREATE TABLE integration_accounts (
  id TEXT NOT NULL PRIMARY KEY,
  account_type TEXT NOT NULL,
  label TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
      raw.execute(
        "INSERT INTO integration_accounts (id, account_type, created_at_ms) "
        "VALUES ('ms-user', 'microsoft_graph', 1)",
      );
      raw.execute('''
CREATE TABLE integration_account_links (
  integration_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  PRIMARY KEY (integration_id, account_id)
);
''');
      raw.execute(
        "INSERT INTO integration_account_links (integration_id, account_id) "
        "VALUES ('outlook_home', 'ms-user')",
      );
      raw.execute('''
CREATE TABLE integration_secrets (
  secret_key TEXT NOT NULL PRIMARY KEY,
  ciphertext BLOB NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
      raw.execute('''
CREATE TABLE secret_store_meta (
  id TEXT NOT NULL PRIMARY KEY,
  wrapped_dek BLOB NOT NULL,
  algorithm_version INTEGER NOT NULL
);
''');
      raw.execute('PRAGMA user_version = 31');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final columns = await db.customSelect('PRAGMA table_info(integrations)').get();
    final names = columns.map((c) => c.read<String>('name')).toSet();
    expect(names.contains('accounts_ready'), isFalse);

    final view = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'view' "
      "AND name = 'v_integration_accounts_configured'",
    ).get();
    expect(view, isNotEmpty);

    final requirements = await db.customSelect(
      'SELECT account_type FROM integration_type_required_accounts '
      "WHERE integration_type = 'calendar_outlook'",
    ).get();
    expect(
      requirements.map((r) => r.read<String>('account_type')).toList(),
      [kIntegrationAccountTypeMicrosoftGraph],
    );

    var configured = await integrationAccountsConfiguredFromView(db, 'outlook_home');
    expect(configured, isFalse);

    final secrets = DbEncryptedSecretStore(
      db: db,
      protector: InMemoryDekProtector(),
    );
    await secrets.write(microsoftGraphAccessTokenSecret('ms-user'), 'token-value');

    configured = await integrationAccountsConfiguredFromView(db, 'outlook_home');
    expect(configured, isTrue);

    await db.close();
  });
}
