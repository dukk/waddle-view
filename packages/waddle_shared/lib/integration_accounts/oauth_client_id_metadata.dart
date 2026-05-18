import 'dart:convert';

import 'package:http/http.dart' as http;

import 'oauth_provider_catalog.dart';

/// Public metadata resolved from the cloud provider (best-effort).
class OAuthClientIdMetadata {
  const OAuthClientIdMetadata({
    this.applicationName,
    this.owner,
    this.lookupStatus = 'unavailable',
    this.lookupError,
  });

  final String? applicationName;
  final String? owner;

  /// `ok` when at least one field was resolved; `unavailable` when lookup ran but
  /// found nothing; `error` when the HTTP/parsing step failed.
  final String lookupStatus;
  final String? lookupError;

  Map<String, dynamic> toJson() => {
        if (applicationName != null) 'application_name': applicationName,
        if (owner != null) 'owner': owner,
        'lookup_status': lookupStatus,
        if (lookupError != null) 'lookup_error': lookupError,
      };

  static OAuthClientIdMetadata unavailable([String? reason]) =>
      OAuthClientIdMetadata(
        lookupStatus: 'unavailable',
        lookupError: reason,
      );

  static OAuthClientIdMetadata ok({
    String? applicationName,
    String? owner,
  }) =>
      OAuthClientIdMetadata(
        applicationName: applicationName,
        owner: owner,
        lookupStatus: (applicationName != null || owner != null) ? 'ok' : 'unavailable',
      );

  static OAuthClientIdMetadata error(String message) => OAuthClientIdMetadata(
        lookupStatus: 'error',
        lookupError: message,
      );
}

const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Best-effort lookup of OAuth app registration metadata from the provider.
Future<OAuthClientIdMetadata> lookupOAuthClientIdMetadata({
  required String providerId,
  required String clientId,
  http.Client? httpClient,
}) async {
  final trimmed = clientId.trim();
  if (trimmed.isEmpty) {
    return OAuthClientIdMetadata.unavailable('empty_client_id');
  }
  switch (providerId) {
    case kOAuthProviderIdGoogle:
      return _lookupGoogle(trimmed, httpClient: httpClient);
    case kOAuthProviderIdMicrosoftGraph:
      return _lookupMicrosoft(trimmed, httpClient: httpClient);
    default:
      return OAuthClientIdMetadata.unavailable('unsupported_provider');
  }
}

Future<OAuthClientIdMetadata> _lookupGoogle(
  String clientId, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;
  try {
    final uri = Uri.https(
      'accounts.google.com',
      '/signin/oauth/error',
      {
        'client_id': clientId,
        'flowName': 'GeneralOAuthFlow',
      },
    );
    final response = await client
        .get(uri, headers: {'User-Agent': _browserUserAgent})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      return OAuthClientIdMetadata.error('http_${response.statusCode}');
    }
    final body = response.body;
    final brand = _firstMatch(
      RegExp(r'data-client-auth-config-brand="([^"]+)"'),
      body,
    );
    final appName = _firstMatch(
      RegExp(r'"application_name"\s*:\s*"([^"]+)"'),
      body,
    );
    final owner = _firstMatch(
      RegExp(r'"owner_name"\s*:\s*"([^"]+)"'),
      body,
    );
    if (brand != null || appName != null || owner != null) {
      return OAuthClientIdMetadata.ok(
        applicationName: brand ?? appName,
        owner: owner,
      );
    }
    final projectNumber = _googleProjectNumber(clientId);
    if (projectNumber != null) {
      return OAuthClientIdMetadata.ok(
        applicationName: 'Google Cloud project $projectNumber',
      );
    }
    return OAuthClientIdMetadata.unavailable();
  } catch (e) {
    return OAuthClientIdMetadata.error(e.toString());
  } finally {
    if (ownsClient) {
      client.close();
    }
  }
}

Future<OAuthClientIdMetadata> _lookupMicrosoft(
  String clientId, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;
  try {
    final uri = Uri.https(
      'login.microsoftonline.com',
      '/common/oauth2/v2.0/authorize',
      {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': 'https://localhost',
        'scope': 'openid',
      },
    );
    final response = await client
        .get(uri, headers: {'User-Agent': _browserUserAgent})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      return OAuthClientIdMetadata.error('http_${response.statusCode}');
    }
    final config = _parseMicrosoftLoginConfig(response.body);
    if (config == null) {
      return OAuthClientIdMetadata.unavailable('config_not_found');
    }
    final appName = _pickString(config, const [
      'strAppDisplayName',
      'sAppName',
      'strAppName',
    ]);
    final owner = _pickString(config, const [
      'strPublisherName',
      'sCompanyDisplayName',
      'strPublisher',
    ]);
    if (appName != null || owner != null) {
      return OAuthClientIdMetadata.ok(applicationName: appName, owner: owner);
    }
    return OAuthClientIdMetadata.unavailable();
  } catch (e) {
    return OAuthClientIdMetadata.error(e.toString());
  } finally {
    if (ownsClient) {
      client.close();
    }
  }
}

Map<String, dynamic>? _parseMicrosoftLoginConfig(String html) {
  final marker = r'$Config=';
  final start = html.indexOf(marker);
  if (start < 0) {
    return null;
  }
  final jsonStart = start + marker.length;
  final brace = html.indexOf('{', jsonStart);
  if (brace < 0) {
    return null;
  }
  var depth = 0;
  for (var i = brace; i < html.length; i++) {
    final ch = html[i];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        try {
          final decoded = jsonDecode(html.substring(brace, i + 1));
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {
          return null;
        }
        break;
      }
    }
  }
  return null;
}

String? _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
  }
  return null;
}

String? _firstMatch(RegExp pattern, String body) {
  final match = pattern.firstMatch(body);
  if (match == null || match.groupCount < 1) {
    return null;
  }
  final value = match.group(1)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String? _googleProjectNumber(String clientId) {
  final match = RegExp(r'^(\d+)\.apps\.googleusercontent\.com$').firstMatch(clientId);
  return match?.group(1);
}
