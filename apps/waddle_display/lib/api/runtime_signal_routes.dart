import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/runtime/runtime_signal_repository.dart';

void registerRuntimeSignalRoutes(
  Router r, {
  required RuntimeSignalRepository signals,
  Future<void> Function()? onSignalsChanged,
}) {
  r.get('/v1/runtime/signals', (Request req) async {
    final snap = await signals.snapshot();
    return Response.ok(
      jsonEncode({'items': snap}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.put('/v1/runtime/signals/<id>', (Request req, String id) async {
    final body = await req.readAsString();
    Object value = true;
    if (body.trim().isNotEmpty) {
      value = jsonDecode(body);
    }
    final pluginHeader = req.headers['x-waddle-plugin-id'];
    await signals.upsert(
      id: id,
      value: value is Map<String, dynamic> && value.containsKey('value')
          ? value['value']
          : value,
      sourcePluginId: pluginHeader,
    );
    if (onSignalsChanged != null) {
      await onSignalsChanged();
    }
    return Response.ok(
      jsonEncode({'id': id.trim(), 'ok': true}),
      headers: {'content-type': 'application/json'},
    );
  });
}
