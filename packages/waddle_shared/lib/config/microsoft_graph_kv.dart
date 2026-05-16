import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Legacy [AppDatabase.configKeyValues] key for the Graph app client id
/// (removed in schema **37**; use [waddleMicrosoftGraphClientIdEnv] in
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

/// [AppDatabase.configKeyValues] key for persisted Graph `@odata.deltaLink` per
/// account and normalized folder path (empty path = whole default drive).
String kOneDriveMediaDeltaLinkKvKey(
  String graphAccountKey,
  String normalizedPath,
) {
  final pathTag = normalizedPath.isEmpty
      ? '_root_'
      : sha256.convert(utf8.encode(normalizedPath)).toString();
  return 'provider.media_onedrive.delta_link.$graphAccountKey.$pathTag';
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
    'provider.calendar_outlook.last_collect_ms';

/// Throttle device-code prompts per Graph account.
String kOutlookCalendarLastDevicePromptKvKey(String graphAccountKey) =>
    'provider.calendar_outlook.last_device_prompt_ms.$graphAccountKey';

/// Prefix for [CalendarEvents.source] rows produced by Outlook sync.
String outlookCalendarEventSource(String graphAccountKey) =>
    'outlook_calendar:$graphAccountKey';
