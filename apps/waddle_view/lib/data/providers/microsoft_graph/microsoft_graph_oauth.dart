import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../config/microsoft_graph_kv.dart';
import '../../../debug/app_debug_log.dart';
import '../../../persistence/database.dart';
import '../../../secrets/secret_store.dart';

const String _deviceAuthPath = '/common/oauth2/v2.0/devicecode';
const String _tokenPath = '/common/oauth2/v2.0/token';

/// Delegated scopes for calendar read and refresh tokens.
const String kMicrosoftGraphOAuthScopes =
    'offline_access User.Read Calendars.Read';

const String kMicrosoftGraphDeviceSignInTitle = 'Microsoft sign-in';

/// Minimum gap between starting device-code flows for one account.
const int kMicrosoftGraphDevicePromptCooldownMs = 15 * 60 * 1000;

/// Refresh the access token this many ms before it expires.
const int kMicrosoftGraphAccessTokenSkewMs = 5 * 60 * 1000;

/// Interval between token polls during device-code flow (server `interval` is ignored).
const int kMicrosoftGraphDeviceCodePollSeconds = 5;

String _formEncode(Map<String, String> fields) => fields.entries
    .map(
      (e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
    )
    .join('&');

String _responseBodySnippet(String body, [int maxChars = 480]) {
  final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= maxChars) {
    return t;
  }
  return '${t.substring(0, maxChars)}…';
}

/// OAuth2 device code + refresh token for Microsoft Graph (`tenant` = `common`).
class MicrosoftGraphOAuth {
  MicrosoftGraphOAuth({
    http.Client? httpClient,
    int Function()? nowMs,
    Future<void> Function(Duration duration)? sleep,
  }) : _http = httpClient ?? http.Client(),
       _nowMs =
           nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _sleep = sleep ?? Future<void>.delayed;

  final http.Client _http;
  final int Function() _nowMs;
  final Future<void> Function(Duration duration) _sleep;

  Uri _loginBase(String host) => Uri(scheme: 'https', host: host);

  /// Returns a usable access token, or `null` if none could be obtained.
  Future<String?> ensureAccessToken({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String graphAccountKey,
  }) async {
    final accessKey = microsoftGraphAccessTokenSecret(graphAccountKey);
    final refreshKey = microsoftGraphRefreshTokenSecret(graphAccountKey);
    final expiresKv = kMicrosoftGraphAccessTokenExpiresAtKvKey(graphAccountKey);
    final now = _nowMs();

    final existing = await secrets.read(accessKey);
    final expiresRow =
        await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(expiresKv)))
            .getSingleOrNull();
    final expiresAt = int.tryParse(expiresRow?.value ?? '') ?? 0;

    if (existing != null &&
        existing.isNotEmpty &&
        expiresAt > now + kMicrosoftGraphAccessTokenSkewMs) {
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: account=$graphAccountKey using cached access token '
        '(expiresAtMs=$expiresAt skewMs=$kMicrosoftGraphAccessTokenSkewMs)',
      );
      return existing;
    }

    AppDebugLog.engine(
      'MicrosoftGraphOAuth: account=$graphAccountKey need token '
      '(hasAccess=${existing != null && existing.isNotEmpty} '
      'expiresAtMs=$expiresAt nowMs=$now)',
    );

    final refresh = await secrets.read(refreshKey);
    if (refresh != null && refresh.isNotEmpty) {
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: account=$graphAccountKey attempting refresh_token grant',
      );
      final ok = await _refreshAccessToken(
        db: db,
        secrets: secrets,
        clientId: clientId,
        graphAccountKey: graphAccountKey,
        refreshToken: refresh,
      );
      if (ok != null) {
        return ok;
      }
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: account=$graphAccountKey refresh did not yield token, '
        'falling back to device code',
      );
    } else {
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: account=$graphAccountKey no refresh token, device code',
      );
    }

    return _deviceCodeFlow(
      db: db,
      secrets: secrets,
      clientId: clientId,
      graphAccountKey: graphAccountKey,
    );
  }

  Future<String?> _refreshAccessToken({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String graphAccountKey,
    required String refreshToken,
  }) async {
    final uri = _loginBase('login.microsoftonline.com').replace(path: _tokenPath);
    AppDebugLog.engine(
      'MicrosoftGraphOAuth: POST $_tokenPath grant=refresh_token '
      'account=$graphAccountKey',
    );
    final body = _formEncode({
      'client_id': clientId,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'scope': kMicrosoftGraphOAuthScopes,
      'redirect_uri': kMicrosoftGraphOAuthRedirectUri,
    });
    try {
      final res = await _http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
      Map<String, dynamic> m;
      try {
        m = jsonDecode(res.body) as Map<String, dynamic>;
      } on Object {
        AppDebugLog.engine(
          'MicrosoftGraphOAuth: refresh invalid JSON status=${res.statusCode} '
          'body=${_responseBodySnippet(res.body)}',
        );
        return null;
      }
      if (res.statusCode != 200) {
        final desc = m['error_description'];
        AppDebugLog.engine(
          'MicrosoftGraphOAuth: refresh failed status=${res.statusCode} '
          'error=${m['error']} '
          'description=${desc is String ? _responseBodySnippet(desc, 240) : desc}',
        );
        return null;
      }
      final access = m['access_token'];
      if (access is! String || access.isEmpty) {
        AppDebugLog.engine(
          'MicrosoftGraphOAuth: refresh 200 but missing access_token keys=${m.keys.join(',')}',
        );
        return null;
      }
      final newRefresh = m['refresh_token'];
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: refresh ok account=$graphAccountKey '
        'expires_in=${m['expires_in']}',
      );
      await _persistTokenResponse(
        db: db,
        secrets: secrets,
        graphAccountKey: graphAccountKey,
        accessToken: access,
        refreshToken: newRefresh is String && newRefresh.isNotEmpty
            ? newRefresh
            : refreshToken,
        expiresInSec: _asInt(m['expires_in']),
      );
      return access;
    } on Object catch (e, st) {
      AppDebugLog.engineFail('MicrosoftGraphOAuth refresh', e, st);
      return null;
    }
  }

  Future<void> _persistTokenResponse({
    required AppDatabase db,
    required SecretStore secrets,
    required String graphAccountKey,
    required String accessToken,
    required String refreshToken,
    required int expiresInSec,
  }) async {
    final now = _nowMs();
    final expiresAt = now + (expiresInSec > 0 ? expiresInSec * 1000 : 3600 * 1000);
    AppDebugLog.engine(
      'MicrosoftGraphOAuth: persisted tokens account=$graphAccountKey '
      'expiresAtMs=$expiresAt (no token values logged)',
    );
    await secrets.write(
      microsoftGraphAccessTokenSecret(graphAccountKey),
      accessToken,
    );
    await secrets.write(
      microsoftGraphRefreshTokenSecret(graphAccountKey),
      refreshToken,
    );
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey(graphAccountKey),
            value: '$expiresAt',
          ),
        );
  }

  Future<String?> _deviceCodeFlow({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String graphAccountKey,
  }) async {
    final promptKv = kOutlookCalendarLastDevicePromptKvKey(graphAccountKey);
    final lastPromptRow =
        await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(promptKv)))
            .getSingleOrNull();
    final now = _nowMs();
    if (lastPromptRow != null) {
      final lastPrompt = int.tryParse(lastPromptRow.value) ?? 0;
      if (now - lastPrompt < kMicrosoftGraphDevicePromptCooldownMs) {
        AppDebugLog.engine(
          'MicrosoftGraphOAuth: skip device code (cooldown) account=$graphAccountKey',
        );
        return null;
      }
    }

    final startUri = _loginBase(
      'login.microsoftonline.com',
    ).replace(path: _deviceAuthPath);
    try {
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: device code flow start account=$graphAccountKey '
        'POST $_deviceAuthPath',
      );
      final startRes = await _http.post(
        startUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: _formEncode({
          'client_id': clientId,
          'scope': kMicrosoftGraphOAuthScopes,
          'redirect_uri': kMicrosoftGraphOAuthRedirectUri,
        }),
      );
      if (startRes.statusCode != 200) {
        AppDebugLog.engine(
          'MicrosoftGraphOAuth: devicecode start status=${startRes.statusCode} '
          'body=${_responseBodySnippet(startRes.body)}',
        );
        return null;
      }
      final start = jsonDecode(startRes.body) as Map<String, dynamic>;
      final deviceCode = start['device_code'];
      final userCode = start['user_code'];
      final verificationUri = start['verification_uri'];
      final expiresIn = _asInt(start['expires_in']);
      if (deviceCode is! String ||
          userCode is! String ||
          verificationUri is! String) {
        AppDebugLog.engine('MicrosoftGraphOAuth: malformed devicecode JSON');
        return null;
      }

      final verificationComplete = start['verification_uri_complete'];
      final qrUrl = verificationComplete is String &&
              verificationComplete.trim().isNotEmpty
          ? verificationComplete.trim()
          : verificationUri;

      final bodyText = StringBuffer()
        ..writeln('Account: $graphAccountKey')
        ..writeln('Code: $userCode')
        ..writeln('Open: $verificationUri')
        ..writeln('Sign in with your Microsoft account, then approve access.');
      final expiresAtDt = DateTime.fromMillisecondsSinceEpoch(
        now + (expiresIn > 0 ? expiresIn * 1000 : 900 * 1000),
      );
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: devicecode ok user_code=$userCode '
        'expiresInSec=$expiresIn verification_uri=$verificationUri',
      );

      final alertId = await db.into(db.dashboardAlerts).insert(
            DashboardAlertsCompanion.insert(
              title: '$kMicrosoftGraphDeviceSignInTitle ($graphAccountKey)',
              body: bodyText.toString(),
              qrPayload: Value(qrUrl),
              severity: const Value('info'),
              priority: const Value(50),
              createdAt: DateTime.fromMillisecondsSinceEpoch(now),
              expiresAt: Value(expiresAtDt),
              source: const Value('outlook_calendar'),
            ),
          );

      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(key: promptKv, value: '$now'),
          );

      final tokenUri = _loginBase(
        'login.microsoftonline.com',
      ).replace(path: _tokenPath);
      final deadline = now + (expiresIn > 0 ? expiresIn * 1000 : 900 * 1000);
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: sign-in alert id=$alertId poll every '
        '${kMicrosoftGraphDeviceCodePollSeconds}s until deadlineMs=$deadline',
      );
      var polled = false;
      var pollCount = 0;
      while (_nowMs() < deadline) {
        if (polled) {
          await _sleep(
            const Duration(seconds: kMicrosoftGraphDeviceCodePollSeconds),
          );
          if (_nowMs() >= deadline) {
            break;
          }
        }
        polled = true;
        pollCount++;

        final tokRes = await _http.post(
          tokenUri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: _formEncode({
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'client_id': clientId,
            'device_code': deviceCode,
            'redirect_uri': kMicrosoftGraphOAuthRedirectUri,
          }),
        );
        Map<String, dynamic>? tok;
        try {
          tok = jsonDecode(tokRes.body) as Map<String, dynamic>;
        } on Object {
          AppDebugLog.engine(
            'MicrosoftGraphOAuth: token poll #$pollCount status=${tokRes.statusCode} '
            'non-JSON body=${_responseBodySnippet(tokRes.body)}',
          );
          continue;
        }
        final err = tok['error'];
        if (err is String) {
          if (err == 'authorization_pending' || err == 'slow_down') {
            final loud = err == 'slow_down' ||
                pollCount <= 3 ||
                pollCount % 6 == 0;
            if (loud) {
              AppDebugLog.engine(
                'MicrosoftGraphOAuth: token poll #$pollCount '
                'status=${tokRes.statusCode} error=$err',
              );
            }
            continue;
          }
          final desc = tok['error_description'];
          AppDebugLog.engine(
            'MicrosoftGraphOAuth: token poll #$pollCount fatal error=$err '
            'description=${desc is String ? _responseBodySnippet(desc, 240) : desc}',
          );
          return null;
        }
        if (tokRes.statusCode != 200) {
          AppDebugLog.engine(
            'MicrosoftGraphOAuth: token poll #$pollCount status=${tokRes.statusCode} '
            'body=${_responseBodySnippet(tokRes.body)}',
          );
          continue;
        }
        final access = tok['access_token'];
        final refresh = tok['refresh_token'];
        if (access is! String ||
            access.isEmpty ||
            refresh is! String ||
            refresh.isEmpty) {
          AppDebugLog.engine('MicrosoftGraphOAuth: token response missing fields');
          return null;
        }
        AppDebugLog.engine(
          'MicrosoftGraphOAuth: token poll #$pollCount success account=$graphAccountKey '
          'expires_in=${tok['expires_in']}',
        );
        await _persistTokenResponse(
          db: db,
          secrets: secrets,
          graphAccountKey: graphAccountKey,
          accessToken: access,
          refreshToken: refresh,
          expiresInSec: _asInt(tok['expires_in']),
        );
        await _dismissDeviceCodeAlert(db, alertId);
        AppDebugLog.engine(
          'MicrosoftGraphOAuth: dismissed sign-in alert id=$alertId',
        );
        return access;
      }
      AppDebugLog.engine(
        'MicrosoftGraphOAuth: device code expired or deadline reached '
        '(polls=$pollCount deadlineMs=$deadline nowMs=${_nowMs()})',
      );
      return null;
    } on Object catch (e, st) {
      AppDebugLog.engineFail('MicrosoftGraphOAuth device flow', e, st);
      return null;
    }
  }

  Future<void> _dismissDeviceCodeAlert(AppDatabase db, int alertId) async {
    await (db.update(db.dashboardAlerts)..where((t) => t.id.equals(alertId)))
        .write(
          DashboardAlertsCompanion(
            dismissedAt: Value(
              DateTime.fromMillisecondsSinceEpoch(_nowMs()),
            ),
          ),
        );
  }
}

int _asInt(Object? v) {
  if (v is int) {
    return v;
  }
  if (v is String) {
    return int.tryParse(v) ?? 0;
  }
  return 0;
}
