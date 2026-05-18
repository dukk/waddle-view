import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Legacy [AppDatabase.configKeyValues] key for the Graph app client id
/// (use [waddleMicrosoftGraphClientIdEnv] in
/// `package:waddle_shared/config/provider_access_token_env.dart` instead).
const String kMicrosoftGraphClientIdKvKey = 'microsoft.graph.client_id';

/// Redirect URI for public / native OAuth clients (device code + refresh).
///
/// Register this under Entra **Authentication** → **Mobile and desktop
/// applications** for the same application (client) id.
const String kMicrosoftGraphOAuthRedirectUri =
    'https://login.microsoftonline.com/common/oauth2/nativeclient';

/// [Alerts.source] for shared Microsoft Graph device-code sign-in.
const String kMicrosoftGraphOAuthAlertSource = 'microsoft_graph';

/// Last successful OneDrive media provider collect (poll gate).
const String kOneDriveMediaLastCollectKvKey =
    'provider.media_onedrive.last_collect_ms';

/// Path tag for a normalized OneDrive folder (empty path = whole default drive).
String oneDriveMediaDeltaLinkPathTag(String normalizedPath) =>
    normalizedPath.isEmpty
        ? '_root_'
        : sha256.convert(utf8.encode(normalizedPath)).toString();

/// Logical [IntegrationsKeyValue.key] for a Graph delta link on an integration row.
String oneDriveMediaDeltaLinkKey(String normalizedPath) =>
    'delta_link.${oneDriveMediaDeltaLinkPathTag(normalizedPath)}';

/// Legacy config_key_values key (schema 21+ uses [oneDriveMediaDeltaLinkKey]).
@Deprecated('Migrated to integrations_key_value in schema 21')
String kOneDriveMediaDeltaLinkKvKey(
  String graphAccountKey,
  String normalizedPath,
) {
  final pathTag = oneDriveMediaDeltaLinkPathTag(normalizedPath);
  return 'provider.media_onedrive.delta_link.$graphAccountKey.$pathTag';
}

/// Stable [Photos.id] / [Videos.id] for a OneDrive drive item under an account.
String kOneDriveMediaItemRowId(String graphAccountKey, String driveItemId) {
  final bytes = utf8.encode(
    'onedrive_media\x00$graphAccountKey\x00$driveItemId',
  );
  return sha256.convert(bytes).toString();
}

/// Legacy config_key_values key (schema 21+ uses [kIntegrationAccessTokenExpiresAtKey]).
@Deprecated('Migrated to integrations_key_value in schema 21')
String kMicrosoftGraphAccessTokenExpiresAtKvKey(String graphAccountKey) =>
    'microsoft.graph.access_token_expires_at_ms.$graphAccountKey';

/// [SecretStore] access token for a Microsoft identity used by Graph providers.
String microsoftGraphAccessTokenSecret(String graphAccountKey) =>
    'provider:access_token:microsoft_graph:$graphAccountKey';

/// [SecretStore] refresh token for the same identity (never in SQLite).
String microsoftGraphRefreshTokenSecret(String graphAccountKey) =>
    'provider:refresh_token:microsoft_graph:$graphAccountKey';

/// Legacy config_key_values poll gate (schema 21+ uses [kIntegrationLastCollectKey]).
@Deprecated('Migrated to integrations_key_value in schema 21')
const String kOutlookCalendarLastCollectKvKey =
    'provider.calendar_outlook.last_collect_ms';

/// Legacy config_key_values key (schema 21+ uses [kIntegrationLastDevicePromptKey]).
@Deprecated('Migrated to integrations_key_value in schema 21')
String kOutlookCalendarLastDevicePromptKvKey(String graphAccountKey) =>
    'provider.calendar_outlook.last_device_prompt_ms.$graphAccountKey';

/// Prefix for [CalendarEvents.source] rows produced by Outlook sync.
String outlookCalendarEventSource(String graphAccountKey) =>
    'outlook_calendar:$graphAccountKey';
