import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_profile.dart';

void main() {
  test('fetchMicrosoftGraphUserProfile parses me', () async {
    final client = _FakeClient([
      http.Response(
        jsonEncode({
          'id': 'user-1',
          'displayName': 'Test User',
          'mail': 'test@example.com',
          'userPrincipalName': 'test@contoso.com',
        }),
        200,
      ),
    ]);
    final profile = await fetchMicrosoftGraphUserProfile(
      httpClient: client,
      graphBaseUrl: 'https://graph.microsoft.com/v1.0/',
      accessToken: 'tok',
    );
    expect(profile.id, 'user-1');
    expect(profile.displayName, 'Test User');
    expect(profile.mail, 'test@example.com');
    expect(profile.userPrincipalName, 'test@contoso.com');
    expect(profile.toJson()['display_name'], 'Test User');
    expect(client.urls.single.path, '/v1.0/me');
  });

  test('fetchMicrosoftGraphUserProfile throws on non-200', () async {
    final client = _FakeClient([http.Response('{"error":{}}', 401)]);
    expect(
      () => fetchMicrosoftGraphUserProfile(
        httpClient: client,
        graphBaseUrl: 'https://graph.microsoft.com/v1.0',
        accessToken: 'bad',
      ),
      throwsA(isA<MicrosoftGraphProfileException>()),
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
