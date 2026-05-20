import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_plugin_sdk/client/display_client.dart';
import 'package:waddle_plugin_sdk/client/display_client_config.dart';
import 'package:waddle_plugin_sdk/contracts/alert_contract.dart';
import 'package:waddle_plugin_sdk/contracts/signal_contract.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await handler(request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      request: request,
    );
  }
}

void main() {
  test('putBoolSignal sends bearer and plugin headers', () async {
    http.Request? captured;
    final client = DisplayClient(
      DisplayClientConfig(
        baseUrl: 'http://127.0.0.1:9',
        bearerToken: 'secret',
        pluginId: 'demo_plugin',
      ),
      client: _FakeClient((req) async {
        captured = req as http.Request;
        return http.Response('', 204);
      }),
    );

    await client.putBoolSignal('room.motion_detected', true);

    expect(captured, isNotNull);
    expect(captured!.method, 'PUT');
    expect(captured!.url.path, '/v1/runtime/signals/room.motion_detected');
    expect(captured!.headers['authorization'], 'Bearer secret');
    expect(captured!.headers['x-waddle-plugin-id'], 'demo_plugin');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['bool'], isTrue);
  });

  test('getSignals throws HttpException on non-200', () async {
    final client = DisplayClient(
      const DisplayClientConfig(baseUrl: 'http://127.0.0.1:9'),
      client: _FakeClient((_) async => http.Response('nope', 500)),
    );

    expect(client.getSignals(), throwsA(isA<HttpException>()));
  });

  test('createAlert returns id from JSON body', () async {
    final client = DisplayClient(
      const DisplayClientConfig(baseUrl: 'http://127.0.0.1:9'),
      client: _FakeClient(
        (_) async => http.Response(jsonEncode({'id': 42}), 201),
      ),
    );

    final id = await client.createAlert(
      const AlertCreateRequest(title: 'T', body: 'B'),
    );
    expect(id, 42);
  });
}
