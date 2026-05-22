import 'dart:convert';

import 'package:http/http.dart' as http;

import 'google_calendar_data_provider.dart';

/// One calendar from Google Calendar API `calendarList`.
class GoogleCalendarInfo {
  const GoogleCalendarInfo({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

/// Lists calendars for the authenticated user via Calendar API v3.
Future<List<GoogleCalendarInfo>> listGoogleCalendars({
  required http.Client httpClient,
  required String calendarApiBaseUrl,
  required String accessToken,
}) async {
  final base = calendarApiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) {
    throw GoogleCalendarsException(statusCode: 0, body: 'empty_base_url');
  }
  final out = <GoogleCalendarInfo>[];
  var url = '$base/users/me/calendarList?maxResults=250';
  while (true) {
    final res = await httpClient.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      throw GoogleCalendarsException(
        statusCode: res.statusCode,
        body: res.body,
      );
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final items = m['items'];
    if (items is List<dynamic>) {
      for (final e in items) {
        if (e is! Map<String, dynamic>) {
          continue;
        }
        final id = e['id'];
        if (id is! String || id.isEmpty) {
          continue;
        }
        final summary = e['summary'];
        out.add(
          GoogleCalendarInfo(
            id: id,
            name: summary is String && summary.isNotEmpty ? summary : id,
          ),
        );
      }
    }
    final next = m['nextPageToken'];
    if (next is String && next.isNotEmpty) {
      url =
          '$base/users/me/calendarList?maxResults=250&pageToken=${Uri.encodeQueryComponent(next)}';
    } else {
      break;
    }
  }
  if (!out.any((c) => c.id == 'primary')) {
    out.insert(0, const GoogleCalendarInfo(id: 'primary', name: 'Primary'));
  }
  return out;
}

String normalizeGoogleCalendarBaseUrl(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) {
    return kDefaultGoogleCalendarBaseUrl;
  }
  return t.replaceAll(RegExp(r'/+$'), '');
}

/// Google calendarList request failed.
class GoogleCalendarsException implements Exception {
  GoogleCalendarsException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() => 'GoogleCalendarsException($statusCode)';
}
