import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../config/google_kv.dart';
import '../../../debug/app_debug_log.dart';
import '../../../persistence/database.dart';
import '../../../secrets/secret_store.dart';

const String kGoogleDeviceSignInTitle = 'Google sign-in';
const int kGoogleDevicePromptCooldownMs = 15 * 60 * 1000;
const int kGoogleAccessTokenSkewMs = 5 * 60 * 1000;
const int kGoogleDeviceCodePollSeconds = 5;

String _formEncode(Map<String, String> fields) => fields.entries
    .map(
      (e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
    )
    .join('&');

class GoogleOAuth {
  GoogleOAuth({
    http.Client? httpClient,
    int Function()? nowMs,
    Future<void> Function(Duration duration)? sleep,
  }) : _http = httpClient ?? http.Client(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _sleep = sleep ?? Future<void>.delayed;

  final http.Client _http;
  final int Function() _nowMs;
  final Future<void> Function(Duration duration) _sleep;

  Future<String?> ensureAccessToken({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String googleAccountKey,
  }) async {
    final accessKey = googleAccessTokenSecret(googleAccountKey);
    final refreshKey = googleRefreshTokenSecret(googleAccountKey);
    final expiresKv = kGoogleAccessTokenExpiresAtKvKey(googleAccountKey);
    final now = _nowMs();

    final existing = await secrets.read(accessKey);
    final expiresRow = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(expiresKv)))
        .getSingleOrNull();
    final expiresAt = int.tryParse(expiresRow?.value ?? '') ?? 0;
    if (existing != null &&
        existing.isNotEmpty &&
        expiresAt > now + kGoogleAccessTokenSkewMs) {
      return existing;
    }

    final refresh = await secrets.read(refreshKey);
    if (refresh != null && refresh.isNotEmpty) {
      final refreshed = await _refreshAccessToken(
        db: db,
        secrets: secrets,
        clientId: clientId,
        googleAccountKey: googleAccountKey,
        refreshToken: refresh,
      );
      if (refreshed != null) {
        return refreshed;
      }
    }

    return _deviceCodeFlow(
      db: db,
      secrets: secrets,
      clientId: clientId,
      googleAccountKey: googleAccountKey,
    );
  }

  Future<String?> _refreshAccessToken({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String googleAccountKey,
    required String refreshToken,
  }) async {
    final uri = Uri.parse('https://oauth2.googleapis.com/token');
    try {
      final res = await _http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: _formEncode({
          'client_id': clientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        }),
      );
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        return null;
      }
      final access = m['access_token'];
      if (access is! String || access.isEmpty) {
        return null;
      }
      final newRefresh = m['refresh_token'];
      await _persistTokenResponse(
        db: db,
        secrets: secrets,
        googleAccountKey: googleAccountKey,
        accessToken: access,
        refreshToken: newRefresh is String && newRefresh.isNotEmpty
            ? newRefresh
            : refreshToken,
        expiresInSec: _asInt(m['expires_in']),
      );
      return access;
    } on Object catch (e, st) {
      AppDebugLog.engineFail('GoogleOAuth refresh', e, st);
      return null;
    }
  }

  Future<String?> _deviceCodeFlow({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String googleAccountKey,
  }) async {
    final promptKv = kGoogleCalendarLastDevicePromptKvKey(googleAccountKey);
    final lastPromptRow = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(promptKv)))
        .getSingleOrNull();
    final now = _nowMs();
    if (lastPromptRow != null) {
      final lastPrompt = int.tryParse(lastPromptRow.value) ?? 0;
      if (now - lastPrompt < kGoogleDevicePromptCooldownMs) {
        return null;
      }
    }

    try {
      final startRes = await _http.post(
        Uri.parse('https://oauth2.googleapis.com/device/code'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: _formEncode({
          'client_id': clientId,
          'scope': kGoogleCalendarOAuthScopes,
        }),
      );
      if (startRes.statusCode != 200) {
        return null;
      }
      final start = jsonDecode(startRes.body) as Map<String, dynamic>;
      final deviceCode = start['device_code'];
      final userCode = start['user_code'];
      final verificationUrl = start['verification_url'];
      final expiresIn = _asInt(start['expires_in']);
      if (deviceCode is! String ||
          userCode is! String ||
          verificationUrl is! String) {
        return null;
      }

      final alertId = await db.into(db.dashboardAlerts).insert(
            DashboardAlertsCompanion.insert(
              title: '$kGoogleDeviceSignInTitle ($googleAccountKey)',
              body:
                  'Account: $googleAccountKey\nCode: $userCode\nOpen: $verificationUrl\n'
                  'Sign in with your Google account, then approve access.',
              qrPayload: Value(verificationUrl),
              severity: const Value('info'),
              priority: const Value(50),
              createdAt: DateTime.fromMillisecondsSinceEpoch(now),
              expiresAt: Value(
                DateTime.fromMillisecondsSinceEpoch(
                  now + (expiresIn > 0 ? expiresIn * 1000 : 900 * 1000),
                ),
              ),
              source: const Value(kGoogleOAuthAlertSource),
            ),
          );
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(key: promptKv, value: '$now'),
          );

      final deadline = now + (expiresIn > 0 ? expiresIn * 1000 : 900 * 1000);
      var polled = false;
      while (_nowMs() < deadline) {
        if (polled) {
          await _sleep(const Duration(seconds: kGoogleDeviceCodePollSeconds));
        }
        polled = true;
        final tokRes = await _http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: _formEncode({
            'client_id': clientId,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'device_code': deviceCode,
          }),
        );
        final tok = jsonDecode(tokRes.body) as Map<String, dynamic>;
        final err = tok['error'];
        if (err is String) {
          if (err == 'authorization_pending' || err == 'slow_down') {
            continue;
          }
          return null;
        }
        if (tokRes.statusCode != 200) {
          continue;
        }
        final access = tok['access_token'];
        if (access is! String || access.isEmpty) {
          return null;
        }
        final refresh = tok['refresh_token'];
        if (refresh is! String || refresh.isEmpty) {
          return null;
        }
        await _persistTokenResponse(
          db: db,
          secrets: secrets,
          googleAccountKey: googleAccountKey,
          accessToken: access,
          refreshToken: refresh,
          expiresInSec: _asInt(tok['expires_in']),
        );
        await (db.update(db.dashboardAlerts)..where((t) => t.id.equals(alertId)))
            .write(
              DashboardAlertsCompanion(
                dismissedAt: Value(DateTime.fromMillisecondsSinceEpoch(_nowMs())),
              ),
            );
        return access;
      }
      return null;
    } on Object catch (e, st) {
      AppDebugLog.engineFail('GoogleOAuth device flow', e, st);
      return null;
    }
  }

  Future<void> _persistTokenResponse({
    required AppDatabase db,
    required SecretStore secrets,
    required String googleAccountKey,
    required String accessToken,
    required String refreshToken,
    required int expiresInSec,
  }) async {
    final now = _nowMs();
    final expiresAt = now + (expiresInSec > 0 ? expiresInSec * 1000 : 3600 * 1000);
    await secrets.write(googleAccessTokenSecret(googleAccountKey), accessToken);
    await secrets.write(googleRefreshTokenSecret(googleAccountKey), refreshToken);
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kGoogleAccessTokenExpiresAtKvKey(googleAccountKey),
            value: '$expiresAt',
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
