import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

import '../helpers/rest_auth_helper.dart';

void main() {
  test('PUT oauth provider client id then GET shows configured', () async {
    final harness = await RestTestHarness.start();
    try {
      final putRes = await http.put(
        Uri.parse('${harness.baseUrl}/v1/oauth-providers/google/client-id'),
        headers: {
          ...harness.authHeaders,
          'content-type': 'application/json',
        },
        body: jsonEncode({'value': 'google-client-id.apps.googleusercontent.com'}),
      );
      expect(putRes.statusCode, 200);

      final getRes = await http.get(
        Uri.parse('${harness.baseUrl}/v1/oauth-providers'),
        headers: harness.authHeaders,
      );
      expect(getRes.statusCode, 200);
      final body = jsonDecode(getRes.body) as Map<String, dynamic>;
      final google = (body['items'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere(
        (e) => e['id'] == 'google',
      );
      expect(google['client_id_configured'], isTrue);

      final stored = await harness.secrets.read(kGoogleClientIdSecretKey);
      expect(stored, 'google-client-id.apps.googleusercontent.com');
    } finally {
      await harness.dispose();
    }
  });
}
