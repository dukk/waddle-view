import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_integrations/microsoft_graph/microsoft_graph_drive_children.dart';

void main() {
  test('listMicrosoftGraphDriveChildren parses folders at root', () async {
    final client = _FakeGraphClient(
      responses: {
        'https://graph.microsoft.com/v1.0/me/drive/root/children': jsonEncode({
          'value': [
            {
              'id': 'abc',
              'name': 'Pictures',
              'folder': <String, dynamic>{},
            },
            {
              'id': 'def',
              'name': 'doc.pdf',
              'file': <String, dynamic>{},
            },
          ],
        }),
      },
    );
    final items = await listMicrosoftGraphDriveChildren(
      httpClient: client,
      graphBaseUrl: 'https://graph.microsoft.com/v1.0',
      accessToken: 'tok',
      folderPath: '',
    );
    expect(items.length, 2);
    final folders = items.where((i) => i.isFolder).toList();
    expect(folders.length, 1);
    expect(folders.single.name, 'Pictures');
    expect(folders.single.path, '/Pictures');
  });
}

class _FakeGraphClient extends http.BaseClient {
  _FakeGraphClient({required this.responses});

  final Map<String, String> responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final key = request.url.toString().split('?').first;
    String? body;
    for (final e in responses.entries) {
      if (key.contains(e.key)) {
        body = e.value;
        break;
      }
    }
    if (body == null) {
      return http.StreamedResponse(Stream.value([]), 404);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'Content-Type': 'application/json'},
    );
  }
}
