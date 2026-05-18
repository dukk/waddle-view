import 'dart:convert';

import 'package:http/http.dart' as http;

import 'microsoft_graph_base_url.dart';

/// One calendar returned from Microsoft Graph `GET .../calendars`.
class MicrosoftGraphCalendarInfo {
  const MicrosoftGraphCalendarInfo({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

/// Lists calendars for [userPath] (`me` or `users/{upn}`) via Graph.
Future<List<MicrosoftGraphCalendarInfo>> listMicrosoftGraphCalendars({
  required http.Client httpClient,
  required String graphBaseUrl,
  required String userPath,
  required String accessToken,
}) async {
  final graphBase = normalizeMicrosoftGraphBaseUrl(graphBaseUrl);
  final segment = _userPathSegment(userPath);
  final out = <MicrosoftGraphCalendarInfo>[];
  var url = '$graphBase/$segment/calendars?\$top=200';
  while (true) {
    final res = await httpClient.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      throw MicrosoftGraphCalendarsException(
        statusCode: res.statusCode,
        body: res.body,
      );
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final values = m['value'];
    if (values is List<dynamic>) {
      for (final e in values) {
        if (e is Map<String, dynamic>) {
          final id = e['id'];
          final name = e['name'];
          if (id is String && id.isNotEmpty) {
            out.add(
              MicrosoftGraphCalendarInfo(
                id: id,
                name: name is String && name.isNotEmpty ? name : id,
              ),
            );
          }
        }
      }
    }
    final next = m['@odata.nextLink'];
    if (next is String && next.isNotEmpty) {
      url = next;
    } else {
      break;
    }
  }
  return out;
}

String _userPathSegment(String mailbox) {
  final m = mailbox.trim();
  if (m.toLowerCase() == 'me') {
    return 'me';
  }
  return 'users/${Uri.encodeComponent(m)}';
}

/// Graph list-calendars request failed.
class MicrosoftGraphCalendarsException implements Exception {
  MicrosoftGraphCalendarsException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() => 'MicrosoftGraphCalendarsException($statusCode)';
}
