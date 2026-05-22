import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/theme/display_custom_themes.dart';
import 'package:waddle_shared/theme/display_custom_themes_store.dart';

const _jsonHeaders = {'content-type': 'application/json'};

Response _validationError(DisplayThemeValidationException e) {
  return Response(
    400,
    body: jsonEncode({
      'error': e.code,
      if (e.detail != null) 'detail': e.detail,
    }),
    headers: _jsonHeaders,
  );
}

void registerDisplayThemesRestRoutes(
  Router r, {
  required AppDatabase db,
  required Future<void> Function() onConfigChanged,
}) {
  r.get('/v1/display/themes', (Request req) async {
    final themes = await readDisplayCustomThemes(db);
    return Response.ok(
      jsonEncode({'items': displayCustomThemesToJson(themes)}),
      headers: _jsonHeaders,
    );
  });

  r.post('/v1/display/themes', (Request req) async {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}', headers: _jsonHeaders);
      }
      body = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}', headers: _jsonHeaders);
    }
    try {
      final label = '${body['label']}';
      final previewRaw = body['preview'];
      if (previewRaw is! Map<String, dynamic>) {
        throw DisplayThemeValidationException(
          'invalid_display_theme_preview',
          'preview required',
        );
      }
      final chrome = parseDisplayThemeChromeGroups(previewRaw);
      final theme = await createDisplayCustomTheme(
        db,
        label: label,
        chrome: chrome,
      );
      await onConfigChanged();
      return Response.ok(
        jsonEncode(theme.toJson()),
        headers: _jsonHeaders,
      );
    } on DisplayThemeValidationException catch (e) {
      return _validationError(e);
    }
  });

  r.patch('/v1/display/themes/<id>', (Request req, String id) async {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}', headers: _jsonHeaders);
      }
      body = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}', headers: _jsonHeaders);
    }
    try {
      DisplayThemeChromeGroups? chrome;
      if (body.containsKey('preview')) {
        final previewRaw = body['preview'];
        if (previewRaw is! Map<String, dynamic>) {
          throw DisplayThemeValidationException(
            'invalid_display_theme_preview',
            'preview must be an object',
          );
        }
        chrome = parseDisplayThemeChromeGroups(previewRaw);
      }
      final theme = await updateDisplayCustomTheme(
        db,
        id,
        label: body.containsKey('label') ? '${body['label']}' : null,
        chrome: chrome,
      );
      await onConfigChanged();
      return Response.ok(
        jsonEncode(theme.toJson()),
        headers: _jsonHeaders,
      );
    } on DisplayThemeValidationException catch (e) {
      final status = e.code == 'display_theme_not_found' ? 404 : 400;
      return Response(
        status,
        body: jsonEncode({
          'error': e.code,
          if (e.detail != null) 'detail': e.detail,
        }),
        headers: _jsonHeaders,
      );
    }
  });

  r.delete('/v1/display/themes/<id>', (Request req, String id) async {
    try {
      await deleteDisplayCustomTheme(db, id);
      await onConfigChanged();
      return Response.ok('{}', headers: _jsonHeaders);
    } on DisplayThemeValidationException catch (e) {
      final status = e.code == 'display_theme_not_found' ? 404 : 400;
      return Response(
        status,
        body: jsonEncode({'error': e.code}),
        headers: _jsonHeaders,
      );
    }
  });
}
