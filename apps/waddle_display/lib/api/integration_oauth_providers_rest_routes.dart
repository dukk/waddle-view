import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

const _jsonHeaders = {'content-type': 'application/json'};

void registerIntegrationOAuthProvidersRestRoutes(
  Router r, {
  required SecretStore secrets,
}) {
  r.get('/v1/oauth-providers', (Request req) async {
    final items = await oauthProvidersStatusJson(secrets);
    return Response.ok(
      jsonEncode({'items': items}),
      headers: _jsonHeaders,
    );
  });

  r.put('/v1/oauth-providers/<providerId>/client-id',
      (Request req, String providerId) async {
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}', headers: _jsonHeaders);
      }
      map = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}', headers: _jsonHeaders);
    }
    final raw = map['value'];
    if (raw is! String) {
      return Response(400,
          body: '{"error":"value_must_be_string"}', headers: _jsonHeaders);
    }
    try {
      await putOAuthProviderClientId(secrets, providerId, raw);
    } on ArgumentError catch (e) {
      final code = e.message?.toString() ?? 'invalid_request';
      return Response(400, body: '{"error":"$code"}', headers: _jsonHeaders);
    }
    return Response.ok('{}', headers: _jsonHeaders);
  });
}
