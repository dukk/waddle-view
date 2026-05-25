import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/catalog_defaults_reset.dart';

const _jsonHeaders = {'content-type': 'application/json'};

void registerCatalogResetRestRoutes(
  Router r, {
  required AppDatabase db,
  required Future<void> Function() onConfigChanged,
  BlobStore? blobs,
}) {
  r.post('/v1/display/catalog/reset-defaults', (Request req) async {
    if (req.url.queryParameters['confirm'] != 'yes') {
      return Response(
        400,
        body: '{"error":"confirm_required","hint":"Add ?confirm=yes"}',
        headers: _jsonHeaders,
      );
    }
    final result = await resetCatalogToSystemDefaults(db, blobs: blobs);
    await onConfigChanged();
    return Response.ok(jsonEncode(result.toJson()), headers: _jsonHeaders);
  });
}
