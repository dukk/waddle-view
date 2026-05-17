import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../plugins/plugin_loader.dart';

void registerPluginRoutes(
  Router r, {
  required PluginLoader loader,
}) {
  r.get('/v1/plugins', (Request req) async {
    return Response.ok(
      jsonEncode({
        'items': [
          for (final p in loader.loaded)
            {
              'id': p.manifest.id,
              'version': p.manifest.version,
              'path': p.path,
              'capabilities': p.manifest.capabilities,
            },
        ],
      }),
      headers: {'content-type': 'application/json'},
    );
  });
}
