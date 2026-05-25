import 'package:drift/drift.dart';

import '../persistence/database.dart';
import 'integration_account_catalog.dart';

/// SQL `CASE` mapping [IntegrationAccounts.accountType] + id to [SecretStore] key.
///
/// Must stay aligned with [kIntegrationAccountTypes] access-token key builders
/// (enforced by [integration_account_access_token_secret_key_test.dart]).
const String kIntegrationAccountAccessTokenSecretKeySqlCase = '''
CASE a.account_type
  WHEN 'google' THEN 'provider:access_token:google:' || a.id
  WHEN 'microsoft_graph' THEN 'provider:access_token:microsoft_graph:' || a.id
  WHEN 'facebook' THEN 'provider:access_token:facebook:' || a.id
  WHEN 'twitter' THEN 'provider:access_token:twitter:' || a.id
  WHEN 'linkedin' THEN 'provider:access_token:linkedin:' || a.id
  ELSE 'provider:access_token:' || a.id
END''';

const String kCreateIntegrationTypeRequiredAccountsTableSql = '''
CREATE TABLE IF NOT EXISTS integration_type_required_accounts (
  integration_type TEXT NOT NULL,
  account_type TEXT NOT NULL,
  PRIMARY KEY (integration_type, account_type)
)
''';

const String _vIntegrationAccountsConfiguredViewSelectSql =
    '''
SELECT
  i.id AS integration_id,
  CASE
    WHEN COALESCE(it.requires_accounts, 0) = 0 THEN 1
    WHEN NOT EXISTS (
      SELECT 1
      FROM integration_type_required_accounts r
      WHERE r.integration_type = i.integration_type
    ) THEN 0
    WHEN NOT EXISTS (
      SELECT 1
      FROM integration_type_required_accounts r
      WHERE r.integration_type = i.integration_type
        AND NOT EXISTS (
          SELECT 1
          FROM integration_account_links l
          INNER JOIN integration_accounts a
            ON a.id = l.account_id AND a.account_type = r.account_type
          INNER JOIN integration_secrets s
            ON s.secret_key = $kIntegrationAccountAccessTokenSecretKeySqlCase
          WHERE l.integration_id = i.id
            AND length(s.ciphertext) > 0
        )
    ) THEN 1
    ELSE 0
  END AS accounts_configured
FROM integrations i
LEFT JOIN integration_types it ON it.integration_type = i.integration_type
''';

/// SQLite baseline DDL ([CREATE VIEW IF NOT EXISTS] is not valid on Postgres).
const String kCreateVIntegrationAccountsConfiguredViewSql =
    'CREATE VIEW IF NOT EXISTS v_integration_accounts_configured AS\n'
    '$_vIntegrationAccountsConfiguredViewSelectSql';

/// Postgres baseline DDL ([CREATE OR REPLACE VIEW]).
const String kCreateVIntegrationAccountsConfiguredViewPostgresSql =
    'CREATE OR REPLACE VIEW v_integration_accounts_configured AS\n'
    '$_vIntegrationAccountsConfiguredViewSelectSql';

/// Inserts rows from [kIntegrationAccountRequirementsByType].
Future<void> seedIntegrationTypeRequiredAccounts(AppDatabase db) async {
  for (final entry in kIntegrationAccountRequirementsByType.entries) {
    for (final accountType in entry.value) {
      await db
          .into(db.integrationTypeRequiredAccounts)
          .insert(
            IntegrationTypeRequiredAccountsCompanion.insert(
              integrationType: entry.key,
              accountType: accountType,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}

/// Whether [integrationId] has all required linked accounts with access-token rows.
Future<bool> integrationAccountsConfiguredFromView(
  AppDatabase db,
  String integrationId,
) async {
  final row = await db
      .customSelect(
        'SELECT accounts_configured FROM v_integration_accounts_configured '
        'WHERE integration_id = ?',
        variables: [Variable<String>(integrationId)],
      )
      .getSingleOrNull();
  if (row == null) {
    return false;
  }
  return row.read<int>('accounts_configured') == 1;
}

/// All integration ids → configured flag from [kCreateVIntegrationAccountsConfiguredViewSql].
Future<Map<String, bool>> integrationAccountsConfiguredViewMap(
  AppDatabase db,
) async {
  final rows = await db
      .customSelect(
        'SELECT integration_id, accounts_configured '
        'FROM v_integration_accounts_configured',
      )
      .get();
  return {
    for (final row in rows)
      row.read<String>('integration_id'):
          row.read<int>('accounts_configured') == 1,
  };
}
