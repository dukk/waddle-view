import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

const _jsonHeaders = {'content-type': 'application/json'};

void registerIntegrationAccountsRestRoutes(
  Router r, {
  required AppDatabase db,
  required SecretStore secrets,
}) {
  r.get('/v1/integration-accounts', (Request req) async {
    final items = await listIntegrationAccountsJson(db, secrets);
    return Response.ok(
      jsonEncode({
        'account_types': integrationAccountTypesCatalogJson(),
        'requirements': integrationAccountRequirementsCatalogJson(),
        'items': items,
      }),
      headers: _jsonHeaders,
    );
  });
}
