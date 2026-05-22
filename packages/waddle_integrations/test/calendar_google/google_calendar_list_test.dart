import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/calendar_google/google_calendar_list.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.Response> Function(http.Request req) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await _handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      request: request,
    );
  }
}

void main() {
  test('listGoogleCalendars parses calendarList items', () async {
    final client = _FakeClient((req) async {
      expect(req.url.path, '/calendar/v3/users/me/calendarList');
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'cal-1', 'summary': 'Work'},
          ],
        }),
        200,
      );
    });
    final items = await listGoogleCalendars(
      httpClient: client,
      calendarApiBaseUrl: 'https://www.googleapis.com/calendar/v3',
      accessToken: 'token',
    );
    expect(items.any((c) => c.id == 'cal-1' && c.name == 'Work'), isTrue);
    expect(items.any((c) => c.id == 'primary'), isTrue);
  });

  test('listGoogleCalendars throws on non-200', () async {
    final client = _FakeClient((_) async => http.Response('err', 401));
    expect(
      () => listGoogleCalendars(
        httpClient: client,
        calendarApiBaseUrl: 'https://www.googleapis.com/calendar/v3',
        accessToken: 'token',
      ),
      throwsA(isA<GoogleCalendarsException>()),
    );
  });
}
