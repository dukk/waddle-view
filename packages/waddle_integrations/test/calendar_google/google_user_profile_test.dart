import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_data_providers/calendar_google/google_user_profile.dart';

void main() {
  test('fetchGoogleUserProfile parses userinfo', () async {
    final client = _FakeClient([
      http.Response(
        jsonEncode({
          'sub': 'google-sub',
          'name': 'Google User',
          'email': 'user@gmail.com',
          'picture': 'https://example.com/p.jpg',
        }),
        200,
      ),
    ]);
    final profile = await fetchGoogleUserProfile(
      httpClient: client,
      accessToken: 'tok',
    );
    expect(profile.sub, 'google-sub');
    expect(profile.name, 'Google User');
    expect(profile.email, 'user@gmail.com');
    expect(profile.toJson()['id'], 'google-sub');
    expect(client.urls.single.host, 'www.googleapis.com');
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
