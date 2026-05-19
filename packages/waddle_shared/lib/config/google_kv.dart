import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Legacy [AppDatabase.configKeyValues] key for Google OAuth client id
/// (use [waddleGoogleClientIdEnv] in
/// `package:waddle_shared/config/provider_access_token_env.dart` instead).
const String kGoogleClientIdKvKey = 'google.client_id';

/// [Alerts.source] for Google device-code sign-in prompts.
const String kGoogleOAuthAlertSource = 'google';

/// Legacy alert source value (pre-unified Google OAuth).
const String kGoogleOAuthAlertSourceLegacy = 'google_calendar';

/// Google Photos Picker API (read picked media items / sessions).
const String kGooglePhotosPickerScope =
    'https://www.googleapis.com/auth/photospicker.mediaitems.readonly';

/// Recommended scope for calendar read-only synchronization.
const String kGoogleCalendarOAuthScopes =
    'openid email https://www.googleapis.com/auth/calendar.readonly';

/// Device-code and refresh flows for Calendar + Photos Picker integrations.
const String kGoogleOAuthScopes =
    '$kGoogleCalendarOAuthScopes $kGooglePhotosPickerScope';

/// Picker API base URL.
const String kGooglePhotosPickerApiBaseUrl =
    'https://photospicker.googleapis.com/v1';

/// Legacy config_key_values key for Google Calendar poll gate (schema 21+ uses
/// [IntegrationsKeyValue] with [kIntegrationLastCollectKey] per integration id).
@Deprecated('Migrated to integrations_key_value in schema 21')
const String kGoogleCalendarLastCollectKvKey =
    'provider.calendar_google.last_collect_ms';

/// Legacy config_key_values key (schema 21+ uses [kIntegrationAccessTokenExpiresAtKey]
/// in [IntegrationsKeyValue] scoped by account id).
@Deprecated('Migrated to integrations_key_value in schema 21')
String kGoogleAccessTokenExpiresAtKvKey(String googleAccountKey) =>
    'google.access_token_expires_at_ms.$googleAccountKey';

/// Legacy config_key_values key (schema 21+ uses [kIntegrationLastDevicePromptKey]).
@Deprecated('Migrated to integrations_key_value in schema 21')
String kGoogleCalendarLastDevicePromptKvKey(String googleAccountKey) =>
    'provider.calendar_google.last_device_prompt_ms.$googleAccountKey';

/// [SecretStore] access token for one Google identity.
String googleAccessTokenSecret(String googleAccountKey) =>
    'provider:access_token:google:$googleAccountKey';

/// [SecretStore] refresh token for one Google identity.
String googleRefreshTokenSecret(String googleAccountKey) =>
    'provider:refresh_token:google:$googleAccountKey';

/// Prefix for [CalendarEvents.source] rows produced by Google sync.
String googleCalendarEventSource(String googleAccountKey) =>
    'google_calendar:$googleAccountKey';

/// Stable [CalendarEvents.id] for a Google calendar event under an account.
String googleCalendarEventRowId(
  String googleAccountKey,
  String calendarId,
  String eventId,
) {
  final bytes = utf8.encode(
    'google_cal\x00$googleAccountKey\x00$calendarId\x00$eventId',
  );
  return sha256.convert(bytes).toString();
}

/// Stable [Photos.id] for a Google Photos Picker item under an account.
String googlePhotosPhotoRowId(String googleAccountKey, String mediaItemId) {
  final bytes = utf8.encode(
    'google_photos_photo\x00$googleAccountKey\x00$mediaItemId',
  );
  return sha256.convert(bytes).toString();
}

/// Stable [Videos.id] for a Google Photos Picker item under an account.
String googlePhotosVideoRowId(String googleAccountKey, String mediaItemId) {
  final bytes = utf8.encode(
    'google_photos_video\x00$googleAccountKey\x00$mediaItemId',
  );
  return sha256.convert(bytes).toString();
}
