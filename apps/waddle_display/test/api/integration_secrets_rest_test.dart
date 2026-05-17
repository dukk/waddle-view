import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

import '../helpers/rest_auth_helper.dart';

void main() {
  test('PUT secret then GET slots shows configured without returning value',
      () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.db.into(harness.db.integrations).insertOnConflictUpdate(
            IntegrationsCompanion.insert(
              id: kDefaultJokeOpenAiIntegrationId,
              integrationType: 'joke_openai',
            ),
          );

      final putRes = await http.put(
        Uri.parse(
          '${harness.baseUrl}/v1/integrations/$kDefaultJokeOpenAiIntegrationId/secrets/api_key',
        ),
        headers: harness.authHeaders,
        body: jsonEncode({'value': 'sk-test-key'}),
      );
      expect(putRes.statusCode, 200);

      final getRes = await http.get(
        Uri.parse(
          '${harness.baseUrl}/v1/integrations/$kDefaultJokeOpenAiIntegrationId/secrets',
        ),
        headers: harness.authHeaders,
      );
      expect(getRes.statusCode, 200);
      final body = jsonDecode(getRes.body) as Map<String, dynamic>;
      final slots = body['slots'] as List<dynamic>;
      expect(slots.length, 1);
      expect(slots.single['configured'], isTrue);
      expect(slots.single.containsKey('value'), isFalse);
      expect(body.toString(), isNot(contains('sk-test-key')));

      final stored = await harness.secrets.read(
        providerAccessTokenSecretKey(kDefaultJokeOpenAiIntegrationId),
      );
      expect(stored, 'sk-test-key');
    } finally {
      await harness.dispose();
    }
  });

  test('PATCH enable fails when required secrets missing', () async {
    final harness = await RestTestHarness.start();
    try {
      await harness.db.into(harness.db.integrations).insertOnConflictUpdate(
            IntegrationsCompanion.insert(
              id: kDefaultPhotoPexelsIntegrationId,
              integrationType: 'photo_pexels',
            ),
          );

      final patchRes = await http.patch(
        Uri.parse(
          '${harness.baseUrl}/v1/integrations/$kDefaultPhotoPexelsIntegrationId',
        ),
        headers: harness.authHeaders,
        body: jsonEncode({'enabled': true}),
      );
      expect(patchRes.statusCode, 400);
      expect(patchRes.body, contains('secrets_required_before_enable'));
    } finally {
      await harness.dispose();
    }
  });
}
