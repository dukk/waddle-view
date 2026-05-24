import 'package:drift/drift.dart';

import '../integration_accounts/integration_accounts_configured_sql.dart';
import 'database.dart';
import 'display_overlay_sql.dart';
import 'reject_term_defaults.dart';

/// Fresh Postgres schema (version 1): Drift tables + views/indexes/seeds.
Future<void> applyPostgresOnCreate(Migrator m, AppDatabase db) async {
  await m.createAll();
  await db.customStatement('''
CREATE VIEW IF NOT EXISTS v_alert_active_candidates AS
SELECT *
FROM alerts
WHERE dismissed_at IS NULL
ORDER BY priority DESC, created_at DESC;
''');
  await db.customStatement(kEnsureOverlayTypesTableSql);
  await db.customStatement('''
CREATE UNIQUE INDEX IF NOT EXISTS integrations_key_value_integration_id_key
ON integrations_key_value (integration_id, key)
WHERE integration_id IS NOT NULL;
''');
  await db.customStatement('''
CREATE UNIQUE INDEX IF NOT EXISTS integrations_key_value_account_id_key
ON integrations_key_value (account_id, key)
WHERE account_id IS NOT NULL;
''');
  await ensureDefaultRejectTerms(db);
  await db.customStatement(kCreateIntegrationTypeRequiredAccountsTableSql);
  await seedIntegrationTypeRequiredAccounts(db);
  await db.customStatement(kCreateVIntegrationAccountsConfiguredViewSql);
}

Future<void> applyPostgresBeforeOpen(AppDatabase db) async {
  await db.customStatement(kCreateVIntegrationAccountsConfiguredViewSql);
  final migrator = Migrator(db);
  await migrator.createTable(db.adoptionPending);
  await migrator.createTable(db.apiClients);
  await db.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS api_clients_identifier '
    'ON api_clients (identifier)',
  );
  await db.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS api_clients_api_key_hash '
    'ON api_clients (api_key_hash)',
  );
  await db.customStatement(
    "UPDATE interests_stock_symbols SET category = 'general' "
    "WHERE category IS NULL OR trim(category) = ''",
  );
}
