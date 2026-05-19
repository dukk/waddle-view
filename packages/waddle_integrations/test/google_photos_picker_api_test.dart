import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/google_photos/google_photos_picker_api.dart';

void main() {
  test('createSession parses pickerUri', () async {
    final client = http.Client();
    final api = GooglePhotosPickerApi(
      httpClient: _SingleResponseClient(
        http.Response(
          jsonEncode({
            'id': 'sess-1',
            'pickerUri': 'https://photos.google.com/picker/v1/sess-1',
            'mediaItemsSet': false,
          }),
          200,
        ),
      ),
    );
    final session = await api.createSession(accessToken: 'tok');
    expect(session.id, 'sess-1');
    expect(session.pickerUri, contains('photos.google.com'));
    client.close();
  });

  test('PickedMediaItem fromJson', () {
    final item = GooglePhotosPickedMediaItem.fromJson({
      'id': 'm1',
      'type': 'PHOTO',
      'mediaFile': {
        'baseUrl': 'https://example.com/p/1',
        'mimeType': 'image/jpeg',
        'filename': 'a.jpg',
        'mediaFileMetadata': {'width': 100, 'height': 200},
      },
    });
    expect(item, isNotNull);
    expect(item!.isPhoto, isTrue);
    expect(item.width, 100);
  });
}

class _SingleResponseClient extends http.BaseClient {
  _SingleResponseClient(this.response);

  final http.Response response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
