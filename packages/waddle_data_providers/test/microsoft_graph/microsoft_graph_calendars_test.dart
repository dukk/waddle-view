import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_calendars.dart';

void main() {
  test('listMicrosoftGraphCalendars parses calendar pages', () async {
    final client = _FakeClient([
      http.Response(
        jsonEncode({
          'value': [
            {'id': 'cal-1', 'name': 'Work'},
            {'id': 'cal-2', 'name': 'Personal'},
          ],
        }),
        200,
      ),
    ]);
    final items = await listMicrosoftGraphCalendars(
      httpClient: client,
      graphBaseUrl: 'https://graph.microsoft.com/v1.0/',
      userPath: 'me',
      accessToken: 'tok',
    );
    expect(items.length, 2);
    expect(items[0].id, 'cal-1');
    expect(items[0].name, 'Work');
    expect(client.urls.single.path, '/v1.0/me/calendars');
  });

  test('listMicrosoftGraphCalendars follows odata nextLink', () async {
    final client = _FakeClient([
      http.Response(
        jsonEncode({
          'value': [
            {'id': 'a', 'name': 'A'},
          ],
          '@odata.nextLink':
              'https://graph.microsoft.com/v1.0/me/calendars?\$skiptoken=page2',
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'value': [
            {'id': 'b', 'name': 'B'},
          ],
        }),
        200,
      ),
    ]);
    final items = await listMicrosoftGraphCalendars(
      httpClient: client,
      graphBaseUrl: 'https://graph.microsoft.com/v1.0',
      userPath: 'me',
      accessToken: 'tok',
    );
    expect(items.map((c) => c.id).toList(), ['a', 'b']);
    expect(client.urls.length, 2);
  });

  test('listMicrosoftGraphCalendars throws on non-200', () async {
    final client = _FakeClient([http.Response('{"error":{}}', 401)]);
    expect(
      () => listMicrosoftGraphCalendars(
        httpClient: client,
        graphBaseUrl: 'https://graph.microsoft.com/v1.0',
        userPath: 'me',
        accessToken: 'bad',
      ),
      throwsA(isA<MicrosoftGraphCalendarsException>()),
    );
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._responses);

  final List<http.Response> _responses;
  final urls = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    urls.add(request.url);
    final res = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      reasonPhrase: res.reasonPhrase,
    );
  }
}
