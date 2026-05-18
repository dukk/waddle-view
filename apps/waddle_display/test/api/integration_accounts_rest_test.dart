import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';

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
}
