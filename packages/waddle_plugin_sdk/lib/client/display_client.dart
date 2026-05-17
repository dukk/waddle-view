import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../contracts/alert_contract.dart';
import '../contracts/signal_contract.dart';
import 'display_client_config.dart';

class DisplayClient {
  DisplayClient(this.config, {http.Client? client})
      : _client = client ?? http.Client();

  final DisplayClientConfig config;
  final http.Client _client;

  Map<String, String> _headers({bool jsonBody = false}) {
    final h = <String, String>{
      if (jsonBody) 'content-type': 'application/json',
      if (config.bearerToken != null && config.bearerToken!.isNotEmpty)
        'authorization': 'Bearer ${config.bearerToken}',
      if (config.pluginId != null && config.pluginId!.isNotEmpty)
        'x-waddle-plugin-id': config.pluginId!,
    };
    return h;
  }

  Future<void> putSignal(String id, RuntimeSignalUpdate value) async {
    final uri = Uri.parse('${config.baseUrl}/v1/runtime/signals/$id');
    final res = await _client.put(
      uri,
      headers: _headers(jsonBody: true),
      body: jsonEncode(value.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('putSignal failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> putBoolSignal(String id, bool value) =>
      putSignal(id, RuntimeSignalUpdate.boolValue(value));

  Future<Map<String, dynamic>> getSignals() async {
    final uri = Uri.parse('${config.baseUrl}/v1/runtime/signals');
    final res = await _client.get(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw HttpException('getSignals failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(body['items'] as Map? ?? {});
  }

  Future<int> createAlert(AlertCreateRequest alert) async {
    final uri = Uri.parse('${config.baseUrl}/v1/alerts');
    final res = await _client.post(
      uri,
      headers: _headers(jsonBody: true),
      body: jsonEncode(alert.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('createAlert failed: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['id'] as int;
  }
}
