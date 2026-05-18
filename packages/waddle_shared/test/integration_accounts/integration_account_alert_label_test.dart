import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/integration_account_alert_label.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('integrationAccountAlertLabel prefers operator label', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrationAccounts).insert(
          IntegrationAccountsCompanion.insert(
            id: 'work-ms',
            accountType: kIntegrationAccountTypeMicrosoftGraph,
            label: const Value('Work Microsoft'),
            createdAtMs: 0,
          ),
        );
    expect(
      await integrationAccountAlertLabel(db, 'work-ms'),
      'Work Microsoft',
    );
    await db.close();
  });

  test('integrationAccountAlertLabel falls back to account id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrationAccounts).insert(
          IntegrationAccountsCompanion.insert(
            id: 'personal',
            accountType: kIntegrationAccountTypeGoogle,
            createdAtMs: 0,
          ),
        );
    expect(await integrationAccountAlertLabel(db, 'personal'), 'personal');
    await db.close();
  });
}
