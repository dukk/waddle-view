import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_base_url.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_calendars.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_oauth.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

import 'integration_account_oauth_probe.dart';

const _jsonHeaders = {'content-type': 'application/json'};

const String kIntegrationAccountSecretSlotAccessToken = 'access_token';

void registerIntegrationAccountsRestRoutes(
  Router r, {
  required AppDatabase db,
  required SecretStore secrets,
  http.Client? httpClient,
}) {
  final graphHttp = httpClient ?? http.Client();
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

  r.post('/v1/integration-accounts', (Request req) async {
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
    final accountType = (map['account_type'] as String?)?.trim() ?? '';
    if (accountType.isEmpty) {
      return Response(400,
          body: '{"error":"account_type_required"}', headers: _jsonHeaders);
    }
    final accountKey = (map['account_key'] as String?)?.trim();
    final label = (map['label'] as String?)?.trim();
    try {
      final accountId = await createOperatorIntegrationAccount(
        db,
        secrets,
        accountTypeId: accountType,
        accountKey: accountKey?.isNotEmpty == true ? accountKey : null,
        label: label?.isNotEmpty == true ? label : null,
      );
      return Response.ok(
        jsonEncode({'account_id': accountId}),
        headers: _jsonHeaders,
      );
    } on ArgumentError catch (e) {
      final code = e.message?.toString() ?? 'invalid_request';
      return Response(400, body: '{"error":"$code"}', headers: _jsonHeaders);
    } on StateError catch (e) {
      final code = e.message;
      return Response(400, body: '{"error":"$code"}', headers: _jsonHeaders);
    }
  });

  r.delete('/v1/integration-accounts/<accountId>',
      (Request req, String accountId) async {
    final confirmParam = req.url.queryParameters['confirm']?.trim().toLowerCase();
    final confirm = confirmParam == 'true' || confirmParam == '1';
    try {
      final result = await deleteOperatorIntegrationAccount(
        db,
        secrets,
        accountId: accountId,
        confirm: confirm,
      );
      return Response.ok(
        jsonEncode({
          'disabled_integration_ids': result.disabledIntegrationIds,
        }),
        headers: _jsonHeaders,
      );
    } on IntegrationAccountInUseException catch (e) {
      return Response(
        409,
        body: jsonEncode({
          'error': 'account_in_use',
          'integration_ids': e.integrationIds,
        }),
        headers: _jsonHeaders,
      );
    } on ArgumentError catch (e) {
      final code = e.message?.toString() ?? 'invalid_request';
      final status = code == 'not_found' ? 404 : 400;
      return Response(status, body: '{"error":"$code"}', headers: _jsonHeaders);
    }
  });

  r.patch('/v1/integration-accounts/<accountId>', (Request req, String accountId) async {
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
    final label = (map['label'] as String?)?.trim() ?? '';
    if (label.isEmpty) {
      return Response(400,
          body: '{"error":"label_required"}', headers: _jsonHeaders);
    }
    try {
      await updateOperatorIntegrationAccountLabel(db, accountId, label: label);
    } on ArgumentError catch (e) {
      final code = e.message?.toString() ?? 'invalid_request';
      final status = code == 'not_found' ? 404 : 400;
      return Response(status, body: '{"error":"$code"}', headers: _jsonHeaders);
    }
    return Response.ok('{}', headers: _jsonHeaders);
  });

  r.get('/v1/integration-accounts/<accountId>/secrets',
      (Request req, String accountId) async {
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(accountId)))
        .getSingleOrNull();
    if (account == null) {
      return Response(404,
          body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final def = kIntegrationAccountTypes[account.accountType];
    if (def == null) {
      return Response(404,
          body: '{"error":"unknown_account_type"}', headers: _jsonHeaders);
    }
    final access = await secrets.read(def.accessTokenSecretKey(accountId));
    return Response.ok(
      jsonEncode({
        'slots': [
          {
            'id': kIntegrationAccountSecretSlotAccessToken,
            'label': def.label,
            'configured': access != null && access.trim().isNotEmpty,
          },
        ],
      }),
      headers: _jsonHeaders,
    );
  });

  r.put('/v1/integration-accounts/<accountId>/secrets/<slotId>',
      (Request req, String accountId, String slotId) async {
    if (slotId != kIntegrationAccountSecretSlotAccessToken) {
      return Response(404,
          body: '{"error":"unknown_secret_slot"}', headers: _jsonHeaders);
    }
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(accountId)))
        .getSingleOrNull();
    if (account == null) {
      return Response(404,
          body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final def = kIntegrationAccountTypes[account.accountType];
    if (def == null) {
      return Response(404,
          body: '{"error":"unknown_account_type"}', headers: _jsonHeaders);
    }
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
    final value = raw.trim();
    if (value.isEmpty) {
      return Response(400,
          body: '{"error":"value_must_be_non_empty"}', headers: _jsonHeaders);
    }
    await secrets.write(def.accessTokenSecretKey(accountId), value);
    return Response.ok('{}', headers: _jsonHeaders);
  });

  r.delete('/v1/integration-accounts/<accountId>/secrets/<slotId>',
      (Request req, String accountId, String slotId) async {
    if (slotId != kIntegrationAccountSecretSlotAccessToken) {
      return Response(404,
          body: '{"error":"unknown_secret_slot"}', headers: _jsonHeaders);
    }
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(accountId)))
        .getSingleOrNull();
    if (account == null) {
      return Response(404,
          body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final def = kIntegrationAccountTypes[account.accountType];
    if (def == null) {
      return Response(404,
          body: '{"error":"unknown_account_type"}', headers: _jsonHeaders);
    }
    await secrets.delete(def.accessTokenSecretKey(accountId));
    return Response.ok('{}', headers: _jsonHeaders);
  });

  r.post('/v1/integration-accounts/<accountId>/request-sign-in',
      (Request req, String accountId) async {
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(accountId)))
        .getSingleOrNull();
    if (account == null) {
      return Response(404,
          body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final def = kIntegrationAccountTypes[account.accountType];
    if (def == null || !def.supportsOAuthSignIn) {
      return Response(400,
          body: '{"error":"oauth_sign_in_not_supported"}',
          headers: _jsonHeaders);
    }
    await requestOAuthSignInForAccount(db, accountId);
    return Response.ok('{}', headers: _jsonHeaders);
  });

  r.post('/v1/integration-accounts/<accountId>/oauth-probe',
      (Request req, String accountId) async {
    return handleIntegrationAccountOAuthProbe(
      db: db,
      secrets: secrets,
      httpClient: graphHttp,
      accountId: accountId,
    );
  });

  r.get(
    '/v1/integration-accounts/<accountId>/microsoft-graph/calendars',
    (Request req, String accountId) async {
      final account = await (db.select(db.integrationAccounts)
            ..where((t) => t.id.equals(accountId)))
          .getSingleOrNull();
      if (account == null) {
        return Response(404,
            body: '{"error":"not_found"}', headers: _jsonHeaders);
      }
      if (account.accountType != kIntegrationAccountTypeMicrosoftGraph) {
        return Response(400,
            body: '{"error":"not_microsoft_graph_account"}',
            headers: _jsonHeaders);
      }
      final clientId =
          await readMicrosoftGraphClientIdFromStore(secrets);
      if (clientId == null || clientId.isEmpty) {
        return Response(503,
            body: '{"error":"microsoft_graph_client_id_not_configured"}',
            headers: _jsonHeaders);
      }
      final oauth = MicrosoftGraphOAuth(httpClient: graphHttp);
      final token = await oauth.ensureAccessToken(
        db: db,
        secrets: secrets,
        clientId: clientId,
        graphAccountKey: accountId,
      );
      if (token == null || token.isEmpty) {
        return Response(503,
            body: '{"error":"access_token_unavailable"}', headers: _jsonHeaders);
      }
      final mailbox = req.url.queryParameters['mailbox']?.trim() ?? 'me';
      if (mailbox.isEmpty) {
        return Response(400,
            body: '{"error":"mailbox_required"}', headers: _jsonHeaders);
      }
      final outlookRow = await (db.select(db.integrations)
            ..where((t) => t.id.equals(kDefaultCalendarOutlookIntegrationId)))
          .getSingleOrNull();
      final graphBase = normalizeMicrosoftGraphBaseUrl(outlookRow?.baseUrl);
      try {
        final calendars = await listMicrosoftGraphCalendars(
          httpClient: graphHttp,
          graphBaseUrl: graphBase,
          userPath: mailbox,
          accessToken: token,
        );
        return Response.ok(
          jsonEncode({
            'items': [
              for (final c in calendars) {'id': c.id, 'name': c.name},
            ],
          }),
          headers: _jsonHeaders,
        );
      } on MicrosoftGraphCalendarsException catch (e) {
        return Response(
          502,
          body: jsonEncode({
            'error': 'graph_calendars_failed',
            'status': e.statusCode,
          }),
          headers: _jsonHeaders,
        );
      }
    },
  );

  r.get('/v1/integrations/<integrationId>/accounts',
      (Request req, String integrationId) async {
    final existing = await (db.select(db.integrations)
          ..where((t) => t.id.equals(integrationId)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}', headers: _jsonHeaders);
    }
    final linked = await listAccountsForIntegrationJson(
      db,
      secrets,
      integrationId,
    );
    final requiredTypes =
        integrationAccountTypesRequiredForIntegration(existing.integrationType);
    return Response.ok(
      jsonEncode({
        'required_account_types': [
          for (final typeId in requiredTypes)
            {
              'account_type': typeId,
              'account_type_label':
                  kIntegrationAccountTypes[typeId]?.label ?? typeId,
              'signup_url': kIntegrationAccountTypes[typeId]?.signupUrl ?? '',
              'supports_oauth_sign_in':
                  kIntegrationAccountTypes[typeId]?.supportsOAuthSignIn ??
                      false,
            },
        ],
        'linked_accounts': linked,
        'accounts_configured': linked.isNotEmpty &&
            linked.every((a) => a['configured'] == true),
      }),
      headers: _jsonHeaders,
    );
  });
}
