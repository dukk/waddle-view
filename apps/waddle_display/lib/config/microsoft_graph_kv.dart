import 'dart:convert';

import 'package:crypto/crypto.dart';

/// [AppDatabase.configKeyValues] key for the shared Microsoft Entra (Azure AD)
/// application (client) id used by all Graph-based providers.
const String kMicrosoftGraphClientIdKvKey = 'microsoft.graph.client_id';

/// Default public client id for this deployment (overridable via KV).
///
/// Kept non-empty so local/dev + unit tests that seed KV rows can exercise
/// the HTTP paths. Operators should override with the real client id via KV
/// for production use.
const String kDefaultMicrosoftGraphClientId =
    'waddle_view-microsoft-graph-client-id';

/// Redirect URI for public / native OAuth clients (device code + refresh).
///
/// Register this under Entra **Authentication** → **Mobile and desktop
/// applications** for the same application (client) id.
const String kMicrosoftGraphOAuthRedirectUri =
    'https://login.microsoftonline.com/common/oauth2/nativeclient';

/// [DashboardAlerts.source] for shared Microsoft Graph device-code sign-in.
const String kMicrosoftGraphOAuthAlertSource = 'microsoft_graph';

/// Last successful OneDrive media provider collect (poll gate).
const String kOneDriveMediaLastCollectKvKey =
    'provider.onedrive_media.last_collect_ms';

/// [AppDatabase.configKeyValues] key for persisted Graph `@odata.deltaLink` per
/// account and normalized folder path (empty path = whole default drive).
String kOneDriveMediaDeltaLinkKvKey(
  String graphAccountKey,
  String normalizedPath,
) {
  final pathTag = normalizedPath.isEmpty
      ? '_root_'
      : sha256.convert(utf8.encode(normalizedPath)).toString();
  return 'provider.onedrive_media.delta_link.$graphAccountKey.$pathTag';
}

/// Stable [Photos.id] / [Videos.id] for a OneDrive drive item under an account.
String kOneDriveMediaItemRowId(String graphAccountKey, String driveItemId) {
  final bytes = utf8.encode(
    'onedrive_media\x00$graphAccountKey\x00$driveItemId',
  );
  return sha256.convert(bytes).toString();
}

/// Milliseconds since epoch when the Graph access token stops being valid
/// (used to decide when to refresh). One row per `graphAccountKey`.
String kMicrosoftGraphAccessTokenExpiresAtKvKey(String graphAccountKey) =>
    'microsoft.graph.access_token_expires_at_ms.$graphAccountKey';

/// [SecretStore] access token for a Microsoft identity used by Graph providers.
String microsoftGraphAccessTokenSecret(String graphAccountKey) =>
    'provider:access_token:microsoft_graph:$graphAccountKey';

/// [SecretStore] refresh token for the same identity (never in SQLite).
String microsoftGraphRefreshTokenSecret(String graphAccountKey) =>
    'provider:refresh_token:microsoft_graph:$graphAccountKey';

/// Last successful Outlook calendar provider collect (poll gate).
const String kOutlookCalendarLastCollectKvKey =
    'provider.outlook_calendar.last_collect_ms';

/// Throttle device-code prompts per Graph account.
String kOutlookCalendarLastDevicePromptKvKey(String graphAccountKey) =>
    'provider.outlook_calendar.last_device_prompt_ms.$graphAccountKey';

/// Prefix for [CalendarEvents.source] rows produced by Outlook sync.
String outlookCalendarEventSource(String graphAccountKey) =>
    'outlook_calendar:$graphAccountKey';
