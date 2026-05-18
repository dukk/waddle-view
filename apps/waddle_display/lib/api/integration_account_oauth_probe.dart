import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:waddle_data_providers/calendar_google/google_oauth.dart';
import 'package:waddle_data_providers/calendar_google/google_user_profile.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_base_url.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_oauth.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_profile.dart';
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';
import 'package:waddle_shared/persistence/database.dart'
    show AppDatabase, kDefaultCalendarOutlookIntegrationId;
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

const _jsonHeaders = {'content-type': 'application/json'};

/// Ensures OAuth tokens for [accountId] and returns profile JSON when signed in.
///
/// When sign-in is required, starts the device-code flow on the display (auth
/// alert) and returns HTTP 202 without blocking for operator completion.
Future<Response> handleIntegrationAccountOAuthProbe({
  required AppDatabase db,
  required SecretStore secrets,
  required http.Client httpClient,
  required String accountId,
}) async {
  final account = await (db.select(db.integrationAccounts)
        ..where((t) => t.id.equals(accountId)))
      .getSingleOrNull();
  if (account == null) {
    return Response(404, body: '{"error":"not_found"}', headers: _jsonHeaders);
  }
  final def = kIntegrationAccountTypes[account.accountType];
  if (def == null || !def.supportsOAuthSignIn) {
    return Response(400,
        body: '{"error":"oauth_sign_in_not_supported"}', headers: _jsonHeaders);
  }

  await requestOAuthSignInForAccount(db, accountId);

  switch (account.accountType) {
    case kIntegrationAccountTypeGoogle:
      return _probeGoogle(
        db: db,
        secrets: secrets,
        httpClient: httpClient,
        accountId: accountId,
      );
    case kIntegrationAccountTypeMicrosoftGraph:
      return _probeMicrosoftGraph(
        db: db,
        secrets: secrets,
        httpClient: httpClient,
        accountId: accountId,
      );
    default:
      return Response(400,
          body: '{"error":"oauth_probe_not_supported"}', headers: _jsonHeaders);
  }
}

Future<Response> _probeGoogle({
  required AppDatabase db,
  required SecretStore secrets,
  required http.Client httpClient,
  required String accountId,
}) async {
  final clientId = await readGoogleClientIdFromStore(secrets);
  if (clientId == null || clientId.isEmpty) {
    return Response(503,
        body: '{"error":"google_client_id_not_configured"}',
        headers: _jsonHeaders);
  }
  final oauth = GoogleOAuth(httpClient: httpClient);
  final token = await oauth.ensureAccessToken(
    db: db,
    secrets: secrets,
    clientId: clientId,
    googleAccountKey: accountId,
    pollDeviceCode: false,
  );
  if (token == null || token.isEmpty) {
    return _signInRequiredResponse(db, kGoogleOAuthAlertSource, accountId);
  }
  try {
    final profile = await fetchGoogleUserProfile(
      httpClient: httpClient,
      accessToken: token,
    );
    return Response.ok(
      jsonEncode({
        'configured': true,
        'account_type': kIntegrationAccountTypeGoogle,
        'profile': profile.toJson(),
      }),
      headers: _jsonHeaders,
    );
  } on GoogleUserProfileException catch (e) {
    return Response(
      502,
      body: jsonEncode({
        'error': 'google_profile_failed',
        'status': e.statusCode,
      }),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _probeMicrosoftGraph({
  required AppDatabase db,
  required SecretStore secrets,
  required http.Client httpClient,
  required String accountId,
}) async {
  final clientId = await readMicrosoftGraphClientIdFromStore(secrets);
  if (clientId == null || clientId.isEmpty) {
    return Response(503,
        body: '{"error":"microsoft_graph_client_id_not_configured"}',
        headers: _jsonHeaders);
  }
  final oauth = MicrosoftGraphOAuth(httpClient: httpClient);
  final token = await oauth.ensureAccessToken(
    db: db,
    secrets: secrets,
    clientId: clientId,
    graphAccountKey: accountId,
    pollDeviceCode: false,
  );
  if (token == null || token.isEmpty) {
    return _signInRequiredResponse(db, kMicrosoftGraphOAuthAlertSource, accountId);
  }
  final outlookRow = await (db.select(db.integrations)
        ..where((t) => t.id.equals(kDefaultCalendarOutlookIntegrationId)))
      .getSingleOrNull();
  final graphBase = normalizeMicrosoftGraphBaseUrl(outlookRow?.baseUrl);
  try {
    final profile = await fetchMicrosoftGraphUserProfile(
      httpClient: httpClient,
      graphBaseUrl: graphBase,
      accessToken: token,
    );
    return Response.ok(
      jsonEncode({
        'configured': true,
        'account_type': kIntegrationAccountTypeMicrosoftGraph,
        'profile': profile.toJson(),
      }),
      headers: _jsonHeaders,
    );
  } on MicrosoftGraphProfileException catch (e) {
    return Response(
      502,
      body: jsonEncode({
        'error': 'microsoft_graph_profile_failed',
        'status': e.statusCode,
      }),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _signInRequiredResponse(
  AppDatabase db,
  String alertSource,
  String accountId,
) async {
  final hasAlert = await _hasActiveOAuthSignInAlert(
    db,
    source: alertSource,
    accountId: accountId,
  );
  return Response(
    202,
    body: jsonEncode({
      'configured': false,
      'status': 'sign_in_required',
      'sign_in_alert_active': hasAlert,
    }),
    headers: _jsonHeaders,
  );
}

Future<bool> _hasActiveOAuthSignInAlert(
  AppDatabase db, {
  required String source,
  required String accountId,
}) async {
  final now = DateTime.now();
  final rows = await (db.select(db.alerts)
        ..where((t) => t.source.equals(source))
        ..where((t) => t.dismissedAt.isNull()))
      .get();
  for (final row in rows) {
    if (row.expiresAt != null && !row.expiresAt!.isAfter(now)) {
      continue;
    }
    if (row.title.contains(accountId) || row.body.contains(accountId)) {
      return true;
    }
  }
  return false;
}
