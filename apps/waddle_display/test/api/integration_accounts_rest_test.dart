import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart'
    show
        IntegrationAccountLinksCompanion,
        IntegrationAccountsCompanion,
        IntegrationsCompanion,
        kDefaultCalendarGoogleIntegrationId,
        kDefaultPhotoPexelsIntegrationId;
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

import '../helpers/rest_auth_helper.dart';

void main() {
  test('GET integration-accounts lists synced accounts and catalog', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.db.into(harness.db.integrations).insertOnConflictUpdate(
            IntegrationsCompanion.insert(
              id: kDefaultCalendarGoogleIntegrationId,
              integrationType: 'calendar_google',
              configJson: Value(
                '{"accounts":[{"googleAccountKey":"personal","sources":[]}]}',
              ),
            ),
          );
      await harness.secrets.write(
        googleAccessTokenSecret('personal'),
        'access-token',
      );

      final res = await http.get(
        Uri.parse('${harness.baseUrl}/v1/integration-accounts'),
        headers: harness.authHeaders,
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      final personal = items.cast<Map<String, dynamic>>().firstWhere(
            (e) => e['id'] == 'personal',
          );
      expect(personal['account_type'], kIntegrationAccountTypeGoogle);
      expect(personal['configured'], isTrue);

      final requirements = body['requirements'] as List<dynamic>;
      expect(
        requirements.cast<Map<String, dynamic>>().any(
              (r) =>
                  r['integration_type'] == 'calendar_google' &&
                  r['account_type'] == kIntegrationAccountTypeGoogle,
            ),
        isTrue,
      );

      final integrationsRes = await http.get(
        Uri.parse('${harness.baseUrl}/v1/integrations'),
        headers: harness.authHeaders,
      );
      final integrationsBody =
          jsonDecode(integrationsRes.body) as Map<String, dynamic>;
      final googleRow = (integrationsBody['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == kDefaultCalendarGoogleIntegrationId);
      final required = googleRow['required_account_types'] as List<dynamic>;
      expect(required, isNotEmpty);
      expect(required.single['account_type'], kIntegrationAccountTypeGoogle);
    } finally {
      await harness.dispose();
    }
  });

  test('PUT integration account secret stores api key', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.db.into(harness.db.integrations).insertOnConflictUpdate(
            IntegrationsCompanion.insert(
              id: kDefaultPhotoPexelsIntegrationId,
              integrationType: 'photo_pexels',
            ),
          );

      final accountsRes = await http.get(
        Uri.parse(
          '${harness.baseUrl}/v1/integrations/'
          '${Uri.encodeComponent(kDefaultPhotoPexelsIntegrationId)}/accounts',
        ),
        headers: harness.authHeaders,
      );
      expect(accountsRes.statusCode, 200);
      final accountsBody = jsonDecode(accountsRes.body) as Map<String, dynamic>;
      final linked = accountsBody['linked_accounts'] as List<dynamic>;
      expect(linked, isNotEmpty);
      final accountId = linked.first['account_id'] as String;

      final putRes = await http.put(
        Uri.parse(
          '${harness.baseUrl}/v1/integration-accounts/'
          '${Uri.encodeComponent(accountId)}/secrets/access_token',
        ),
        headers: {
          ...harness.authHeaders,
          'content-type': 'application/json',
        },
        body: jsonEncode({'value': 'pexels-test-key'}),
      );
      expect(putRes.statusCode, 200);

      final stored = await harness.secrets.read(
        'provider:access_token:$accountId',
      );
      expect(stored, 'pexels-test-key');
    } finally {
      await harness.dispose();
    }
  });

  test('PATCH integration-accounts updates account label', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.db.into(harness.db.integrationAccounts).insertOnConflictUpdate(
            IntegrationAccountsCompanion.insert(
              id: 'pexels_home',
              accountType: kIntegrationAccountTypeApiKeyPexels,
              label: const Value('Old label'),
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final patchRes = await http.patch(
        Uri.parse(
          '${harness.baseUrl}/v1/integration-accounts/'
          '${Uri.encodeComponent('pexels_home')}',
        ),
        headers: {
          ...harness.authHeaders,
          'content-type': 'application/json',
        },
        body: jsonEncode({'label': 'Pexels home'}),
      );
      expect(patchRes.statusCode, 200);

      final row = await (harness.db.select(harness.db.integrationAccounts)
            ..where((t) => t.id.equals('pexels_home')))
          .getSingle();
      expect(row.label, 'Pexels home');
    } finally {
      await harness.dispose();
    }
  });

  test('POST integration-accounts creates oauth account when client id set', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.secrets.write(
        'provider:client_id:google',
        'google-client-id.apps.googleusercontent.com',
      );
      await harness.db.into(harness.db.integrations).insertOnConflictUpdate(
            IntegrationsCompanion.insert(
              id: kDefaultCalendarGoogleIntegrationId,
              integrationType: 'calendar_google',
            ),
          );

      final postRes = await http.post(
        Uri.parse('${harness.baseUrl}/v1/integration-accounts'),
        headers: {
          ...harness.authHeaders,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'account_type': kIntegrationAccountTypeGoogle,
          'account_key': 'work',
          'label': 'Work Google',
        }),
      );
      expect(postRes.statusCode, 200);
      final postBody = jsonDecode(postRes.body) as Map<String, dynamic>;
      expect(postBody['account_id'], 'work');

      final listRes = await http.get(
        Uri.parse('${harness.baseUrl}/v1/integration-accounts'),
        headers: harness.authHeaders,
      );
      final listBody = jsonDecode(listRes.body) as Map<String, dynamic>;
      final items = listBody['items'] as List<dynamic>;
      expect(
        items.cast<Map<String, dynamic>>().any((e) => e['id'] == 'work'),
        isTrue,
      );
    } finally {
      await harness.dispose();
    }
  });

  test('GET microsoft-graph calendars requires configured token', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.secrets.write(kMicrosoftGraphClientIdSecretKey, 'ms-client');
      await harness.db.into(harness.db.integrationAccounts).insertOnConflictUpdate(
            IntegrationAccountsCompanion.insert(
              id: 'work',
              accountType: kIntegrationAccountTypeMicrosoftGraph,
              label: const Value('Work'),
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final res = await http.get(
        Uri.parse(
          '${harness.baseUrl}/v1/integration-accounts/work/microsoft-graph/calendars',
        ),
        headers: harness.authHeaders,
      );
      expect(res.statusCode, 503);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['error'], 'access_token_unavailable');
    } finally {
      await harness.dispose();
    }
  });

  test('POST oauth-probe rejects non-oauth account types', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.db.into(harness.db.integrationAccounts).insertOnConflictUpdate(
            IntegrationAccountsCompanion.insert(
              id: 'pexels_home',
              accountType: kIntegrationAccountTypeApiKeyPexels,
              label: const Value('Home'),
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final res = await http.post(
        Uri.parse(
          '${harness.baseUrl}/v1/integration-accounts/pexels_home/oauth-probe',
        ),
        headers: harness.authHeaders,
      );
      expect(res.statusCode, 400);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['error'], 'oauth_sign_in_not_supported');
    } finally {
      await harness.dispose();
    }
  });

  test('DELETE integration-accounts returns 409 when account is in use', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.secrets.write(
        'provider:client_id:google',
        'google-client-id.apps.googleusercontent.com',
      );
      await harness.db.into(harness.db.integrations).insertOnConflictUpdate(
            IntegrationsCompanion.insert(
              id: kDefaultCalendarGoogleIntegrationId,
              integrationType: 'calendar_google',
              enabled: const Value(true),
              configJson: Value(
                '{"accounts":[{"googleAccountKey":"personal","sources":[]}]}',
              ),
            ),
          );
      await harness.db.into(harness.db.integrationAccounts).insertOnConflictUpdate(
            IntegrationAccountsCompanion.insert(
              id: 'personal',
              accountType: kIntegrationAccountTypeGoogle,
              label: const Value('Personal'),
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await harness.db.into(harness.db.integrationAccountLinks).insertOnConflictUpdate(
            IntegrationAccountLinksCompanion.insert(
              integrationId: kDefaultCalendarGoogleIntegrationId,
              accountId: 'personal',
            ),
          );

      final res = await http.delete(
        Uri.parse(
          '${harness.baseUrl}/v1/integration-accounts/personal',
        ),
        headers: harness.authHeaders,
      );
      expect(res.statusCode, 409);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['error'], 'account_in_use');
      expect(body['integration_ids'], contains(kDefaultCalendarGoogleIntegrationId));
    } finally {
      await harness.dispose();
    }
  });

  test('DELETE integration-accounts with confirm removes account and disables integrations',
      () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.secrets.write(
        'provider:client_id:google',
        'google-client-id.apps.googleusercontent.com',
      );
      await harness.secrets.write(googleAccessTokenSecret('personal'), 'tok');
      await harness.db.into(harness.db.integrations).insertOnConflictUpdate(
            IntegrationsCompanion.insert(
              id: kDefaultCalendarGoogleIntegrationId,
              integrationType: 'calendar_google',
              enabled: const Value(true),
              configJson: Value(
                '{"accounts":[{"googleAccountKey":"personal","sources":[]}]}',
              ),
            ),
          );
      await harness.db.into(harness.db.integrationAccounts).insertOnConflictUpdate(
            IntegrationAccountsCompanion.insert(
              id: 'personal',
              accountType: kIntegrationAccountTypeGoogle,
              label: const Value('Personal'),
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await harness.db.into(harness.db.integrationAccountLinks).insertOnConflictUpdate(
            IntegrationAccountLinksCompanion.insert(
              integrationId: kDefaultCalendarGoogleIntegrationId,
              accountId: 'personal',
            ),
          );

      final res = await http.delete(
        Uri.parse(
          '${harness.baseUrl}/v1/integration-accounts/personal?confirm=true',
        ),
        headers: harness.authHeaders,
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(
        body['disabled_integration_ids'],
        [kDefaultCalendarGoogleIntegrationId],
      );
      expect(
        await (harness.db.select(harness.db.integrationAccounts)
              ..where((t) => t.id.equals('personal')))
            .get(),
        isEmpty,
      );
      final row = await (harness.db.select(harness.db.integrations)
            ..where((t) => t.id.equals(kDefaultCalendarGoogleIntegrationId)))
          .getSingle();
      expect(row.enabled, isFalse);
    } finally {
      await harness.dispose();
    }
  });

  test('GET microsoft-graph calendars rejects non-Microsoft accounts', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.db.into(harness.db.integrationAccounts).insertOnConflictUpdate(
            IntegrationAccountsCompanion.insert(
              id: 'personal',
              accountType: kIntegrationAccountTypeGoogle,
              label: const Value('Personal'),
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final res = await http.get(
        Uri.parse(
          '${harness.baseUrl}/v1/integration-accounts/personal/microsoft-graph/calendars',
        ),
        headers: harness.authHeaders,
      );
      expect(res.statusCode, 400);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['error'], 'not_microsoft_graph_account');
    } finally {
      await harness.dispose();
    }
  });
}
