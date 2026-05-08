import 'dart:convert';

import 'package:crypto/crypto.dart';

/// [AppDatabase.configKeyValues] key for shared Google OAuth client id.
const String kGoogleClientIdKvKey = 'google.client_id';

/// Default for a fresh database: operators set a real id via admin or KV; never commit secrets here.
const String kDefaultGoogleClientId = '';

/// [DashboardAlerts.source] for Google device-code sign-in prompts.
const String kGoogleOAuthAlertSource = 'google_calendar';

/// Recommended scope for calendar read-only synchronization.
const String kGoogleCalendarOAuthScopes =
    'openid email https://www.googleapis.com/auth/calendar.readonly';

/// Last successful Google Calendar collect (poll gate).
const String kGoogleCalendarLastCollectKvKey =
    'provider.google_calendar.last_collect_ms';

/// Milliseconds since epoch when the Google access token expires.
String kGoogleAccessTokenExpiresAtKvKey(String googleAccountKey) =>
    'google.access_token_expires_at_ms.$googleAccountKey';

/// Throttle device-code prompts per account.
String kGoogleCalendarLastDevicePromptKvKey(String googleAccountKey) =>
    'provider.google_calendar.last_device_prompt_ms.$googleAccountKey';

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
