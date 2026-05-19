import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:waddle_integrations/calendar_google/google_oauth.dart';
import 'package:waddle_integrations/google_photos/google_photos_picker_api.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

const _jsonHeaders = {'content-type': 'application/json'};

Future<String?> _googleAccessToken({
  required AppDatabase db,
  required SecretStore secrets,
  required http.Client httpClient,
  required String accountId,
}) async {
  final account = await (db.select(db.integrationAccounts)
        ..where((t) => t.id.equals(accountId)))
      .getSingleOrNull();
  if (account == null || account.accountType != kIntegrationAccountTypeGoogle) {
    return null;
  }
  final clientId = await readGoogleClientIdFromStore(secrets);
  if (clientId == null || clientId.isEmpty) {
    return null;
  }
  final oauth = GoogleOAuth(httpClient: httpClient);
  return oauth.ensureAccessToken(
    db: db,
    secrets: secrets,
    clientId: clientId,
    googleAccountKey: accountId,
    pollDeviceCode: false,
  );
}

Future<Response?> _googleAccountGuard(
  AppDatabase db,
  String accountId,
) async {
  final account = await (db.select(db.integrationAccounts)
        ..where((t) => t.id.equals(accountId)))
      .getSingleOrNull();
  if (account == null) {
    return Response(404, body: '{"error":"not_found"}', headers: _jsonHeaders);
  }
  if (account.accountType != kIntegrationAccountTypeGoogle) {
    return Response(400,
        body: '{"error":"not_google_account"}', headers: _jsonHeaders);
  }
  return null;
}

Future<Response> handleGooglePhotosPickerCreateSession({
  required AppDatabase db,
  required SecretStore secrets,
  required http.Client httpClient,
  required String accountId,
  String? requestId,
}) async {
  final guard = await _googleAccountGuard(db, accountId);
  if (guard != null) {
    return guard;
  }
  final clientId = await readGoogleClientIdFromStore(secrets);
  if (clientId == null || clientId.isEmpty) {
    return Response(503,
        body: '{"error":"google_client_id_not_configured"}',
        headers: _jsonHeaders);
  }
  final token = await _googleAccessToken(
    db: db,
    secrets: secrets,
    httpClient: httpClient,
    accountId: accountId,
  );
  if (token == null || token.isEmpty) {
    return Response(503,
        body: '{"error":"access_token_unavailable"}', headers: _jsonHeaders);
  }
  try {
    final api = GooglePhotosPickerApi(httpClient: httpClient);
    final session = await api.createSession(
      accessToken: token,
      requestId: requestId,
    );
    return Response.ok(
      jsonEncode({
        'sessionId': session.id,
        'pickerUri': session.pickerUri,
        'mediaItemsSet': session.mediaItemsSet,
        if (session.recommendedPollIntervalMs != null)
          'recommendedPollIntervalMs': session.recommendedPollIntervalMs,
        if (session.recommendedTimeoutMs != null)
          'recommendedTimeoutMs': session.recommendedTimeoutMs,
      }),
      headers: _jsonHeaders,
    );
  } on GooglePhotosPickerApiException catch (e) {
    return Response(
      502,
      body: jsonEncode({
        'error': 'google_photos_picker_create_failed',
        'status': e.statusCode,
      }),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> handleGooglePhotosPickerGetSession({
  required AppDatabase db,
  required SecretStore secrets,
  required http.Client httpClient,
  required String accountId,
  required String sessionId,
}) async {
  final guard = await _googleAccountGuard(db, accountId);
  if (guard != null) {
    return guard;
  }
  final token = await _googleAccessToken(
    db: db,
    secrets: secrets,
    httpClient: httpClient,
    accountId: accountId,
  );
  if (token == null || token.isEmpty) {
    return Response(503,
        body: '{"error":"access_token_unavailable"}', headers: _jsonHeaders);
  }
  try {
    final api = GooglePhotosPickerApi(httpClient: httpClient);
    final session = await api.getSession(
      accessToken: token,
      sessionId: sessionId,
    );
    return Response.ok(
      jsonEncode({
        'sessionId': session.id,
        'pickerUri': session.pickerUri,
        'mediaItemsSet': session.mediaItemsSet,
        if (session.recommendedPollIntervalMs != null)
          'recommendedPollIntervalMs': session.recommendedPollIntervalMs,
        if (session.recommendedTimeoutMs != null)
          'recommendedTimeoutMs': session.recommendedTimeoutMs,
      }),
      headers: _jsonHeaders,
    );
  } on GooglePhotosPickerApiException catch (e) {
    return Response(
      502,
      body: jsonEncode({
        'error': 'google_photos_picker_get_failed',
        'status': e.statusCode,
      }),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> handleGooglePhotosPickerListMediaItems({
  required AppDatabase db,
  required SecretStore secrets,
  required http.Client httpClient,
  required String accountId,
  required String sessionId,
  String? pageToken,
}) async {
  final guard = await _googleAccountGuard(db, accountId);
  if (guard != null) {
    return guard;
  }
  final token = await _googleAccessToken(
    db: db,
    secrets: secrets,
    httpClient: httpClient,
    accountId: accountId,
  );
  if (token == null || token.isEmpty) {
    return Response(503,
        body: '{"error":"access_token_unavailable"}', headers: _jsonHeaders);
  }
  try {
    final api = GooglePhotosPickerApi(httpClient: httpClient);
    final page = await api.listMediaItems(
      accessToken: token,
      sessionId: sessionId,
      pageToken: pageToken,
    );
    return Response.ok(
      jsonEncode({
        'items': [
          for (final item in page.items)
            {
              'id': item.id,
              'mimeType': item.mimeType,
              'filename': item.filename,
              'type': item.type,
              if (item.width != null) 'width': item.width,
              if (item.height != null) 'height': item.height,
            },
        ],
        if (page.nextPageToken != null) 'nextPageToken': page.nextPageToken,
      }),
      headers: _jsonHeaders,
    );
  } on GooglePhotosPickerApiException catch (e) {
    return Response(
      502,
      body: jsonEncode({
        'error': 'google_photos_picker_list_failed',
        'status': e.statusCode,
      }),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> handleGooglePhotosPickerDeleteSession({
  required AppDatabase db,
  required SecretStore secrets,
  required http.Client httpClient,
  required String accountId,
  required String sessionId,
}) async {
  final guard = await _googleAccountGuard(db, accountId);
  if (guard != null) {
    return guard;
  }
  final token = await _googleAccessToken(
    db: db,
    secrets: secrets,
    httpClient: httpClient,
    accountId: accountId,
  );
  if (token == null || token.isEmpty) {
    return Response(503,
        body: '{"error":"access_token_unavailable"}', headers: _jsonHeaders);
  }
  try {
    final api = GooglePhotosPickerApi(httpClient: httpClient);
    await api.deleteSession(accessToken: token, sessionId: sessionId);
    return Response.ok('{}', headers: _jsonHeaders);
  } on GooglePhotosPickerApiException catch (e) {
    return Response(
      502,
      body: jsonEncode({
        'error': 'google_photos_picker_delete_failed',
        'status': e.statusCode,
      }),
      headers: _jsonHeaders,
    );
  }
}
