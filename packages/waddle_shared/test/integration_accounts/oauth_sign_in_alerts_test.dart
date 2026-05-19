import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/oauth_sign_in_alerts.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('oauthSignInStatus pending vs expired', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    addTearDown(db.close);
    await db.into(db.integrationAccounts).insertOnConflictUpdate(
          IntegrationAccountsCompanion.insert(
            id: 'work',
            accountType: kIntegrationAccountTypeMicrosoftGraph,
            label: const Value('Work'),
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    await db.into(db.alerts).insert(
          AlertsCompanion.insert(
            title: 'Microsoft sign-in (Work)',
            body: 'Account: Work\nCode: ABCD',
            severity: const Value('auth'),
            priority: const Value(50),
            createdAt: DateTime.now(),
            expiresAt: Value(DateTime.now().add(const Duration(minutes: 15))),
            source: const Value(kMicrosoftGraphOAuthAlertSource),
          ),
        );

    expect(
      await oauthSignInStatusForAccount(
        db,
        accountId: 'work',
        accountTypeId: kIntegrationAccountTypeMicrosoftGraph,
        configured: false,
      ),
      OAuthSignInStatus.pending,
    );
    expect(oauthSignInStatusJson(OAuthSignInStatus.pending), 'pending');

    await dismissOAuthSignInAlertsForAccount(
      db,
      accountId: 'work',
      accountTypeId: kIntegrationAccountTypeMicrosoftGraph,
    );

    expect(
      await oauthSignInStatusForAccount(
        db,
        accountId: 'work',
        accountTypeId: kIntegrationAccountTypeMicrosoftGraph,
        configured: false,
      ),
      OAuthSignInStatus.expired,
    );
    expect(
      await oauthSignInStatusForAccount(
        db,
        accountId: 'work',
        accountTypeId: kIntegrationAccountTypeMicrosoftGraph,
        configured: true,
      ),
      isNull,
    );
  });

  test('activeOAuthSignInAlertsForAccount ignores expired rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    addTearDown(db.close);
    await db.into(db.integrationAccounts).insertOnConflictUpdate(
          IntegrationAccountsCompanion.insert(
            id: 'work',
            accountType: kIntegrationAccountTypeMicrosoftGraph,
            label: const Value('Work'),
            createdAtMs: 0,
          ),
        );
    await db.into(db.alerts).insert(
          AlertsCompanion.insert(
            title: 'Microsoft sign-in (Work)',
            body: 'Account: Work',
            severity: const Value('auth'),
            priority: const Value(50),
            createdAt: DateTime.utc(2020),
            expiresAt: Value(DateTime.utc(2020, 1, 1)),
            source: const Value(kMicrosoftGraphOAuthAlertSource),
          ),
        );

    final active = await activeOAuthSignInAlertsForAccount(
      db,
      accountId: 'work',
      alertSource: kMicrosoftGraphOAuthAlertSource,
      now: DateTime.utc(2026),
    );
    expect(active, isEmpty);
  });
}
