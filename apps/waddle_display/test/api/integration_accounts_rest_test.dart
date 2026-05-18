import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart'
    show
        IntegrationAccountsCompanion,
        IntegrationsCompanion,
        kDefaultCalendarGoogleIntegrationId,
        kDefaultPhotoPexelsIntegrationId;

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
}
