import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../alerts/alert_repository.dart';
import '../debug/app_debug_log.dart';
import '../debug/operator_telemetry_hub.dart';
import '../display/display_navigation_bus.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/blob/display_blob_read.dart';
import 'package:waddle_shared/curation/reject_rescan.dart';
import 'package:waddle_shared/persistence/content_suppression_repository.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';
import '../ticker/ticker_curated_repository.dart';
import 'adoption_rest_routes.dart';
import 'api_key_auth.dart';
import 'caller_origin.dart';
import 'content_catalog_rest_routes.dart';
import 'cors_policy.dart';
import 'operator_rest_routes.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/auth/cors_origin_repository.dart';

Handler buildProtectedApiRouter({
  required AppDatabase db,
  required AlertRepository alerts,
  required TickerCuratedRepository ticker,
  required BlobStore blobs,
  required Future<void> Function() onConfigChanged,
  OperatorTelemetryHub? telemetryHub,
  DisplayNavigationBus? navigationBus,
}) {
  final r = Router();
  final suppression = ContentSuppressionRepository(db);

  r.patch('/v1/content/jokes/<id>', (Request req, String id) async {
    return _patchContentSuppressed(req, (b) => suppression.setJokeSuppressed(id, b));
  });
  r.patch('/v1/content/rss-articles/<id>', (Request req, String id) async {
    return _patchContentSuppressed(
      req,
      (b) => suppression.setRssArticleSuppressed(id, b),
    );
  });
  r.patch('/v1/content/photos/<id>', (Request req, String id) async {
    return _patchContentSuppressed(req, (b) => suppression.setPhotoSuppressed(id, b));
  });
  r.patch('/v1/content/videos/<id>', (Request req, String id) async {
    return _patchContentSuppressed(req, (b) => suppression.setVideoSuppressed(id, b));
  });
  r.patch('/v1/content/trivia/<id>', (Request req, String id) async {
    return _patchContentSuppressed(
      req,
      (b) => suppression.setTriviaQuestionSuppressed(id, b),
    );
  });

  registerContentCatalogRoutes(r, db: db);

  final rejectRepo = RejectTermRepository(db);

  r.get('/v1/reject-terms', (Request req) async {
    final rows = await rejectRepo.listAll();
    final fmtRow = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(kRejectCensorFormatKvKey)))
        .getSingleOrNull();
    return Response.ok(
      jsonEncode({
        'items': [
          for (final r in rows)
            {
              'id': r.id,
              'term': r.term,
              'action': r.action,
              'created_at_ms': r.createdAtMs,
              'updated_at_ms': r.updatedAtMs,
            },
        ],
        'censor_format': fmtRow?.value ?? kRejectCensorFormatAsterisksFull,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/reject-terms', (Request req) async {
    return _upsertRejectTerm(req, rejectRepo, db);
  });

  r.patch('/v1/reject-terms/<id>', (Request req, String id) async {
    return _upsertRejectTerm(req, rejectRepo, db, id: id);
  });

  r.delete('/v1/reject-terms/<id>', (Request req, String id) async {
    final n = await rejectRepo.deleteById(id);
    if (n == 0) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.put('/v1/reject-terms/format', (Request req) async {
    return _setRejectCensorFormat(req, db);
  });

  r.post('/v1/reject-terms/rescan', (Request req) async {
    final result = await rescanContentForBlockTerms(db);
    return Response.ok(
      jsonEncode({
        'rss_articles_marked': result.rssArticlesMarked,
        'jokes_marked': result.jokesMarked,
        'trivia_questions_marked': result.triviaQuestionsMarked,
        'photos_marked': result.photosMarked,
        'videos_marked': result.videosMarked,
        'total_marked': result.totalMarked,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/integrations', (Request req) async {
    final rows = await db.select(db.integrations).get();
    final list = rows
        .map(
          (e) => {
            'id': e.id,
            'integration_type': e.providerType,
            'enabled': e.enabled,
            'poll_seconds': e.pollSeconds,
            'base_url': e.baseUrl,
            'config_json': _jsonDecodeLoose(e.configJson),
            'config_json_schema': _jsonDecodeLoose(e.configJsonSchema),
            'example_config_json': _jsonDecodeLoose(e.exampleConfigJson),
          },
        )
        .toList();
    return Response.ok(
      jsonEncode({'items': list}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/screens', (Request req) async {
    final rows = await db.select(db.screens).get();
    final dataKeyLimitRows =
        await db.select(db.curatorDataKeyProgramLimits).get();
    final dataKeyLimits = <String, CuratorDataKeyProgramLimit>{
      for (final row in dataKeyLimitRows) row.dataKey: row,
    };
    final list = rows
        .map(
          (e) => <String, dynamic>{
            'id': e.id,
            'name': e.name,
            'description': e.description,
            'enabled': e.enabled,
            'screen_type': e.screenType,
            'config_json': e.configJson,
            'config_json_schema': e.configJsonSchema,
            'example_config_json': e.exampleConfigJson,
            'dwell_seconds': e.dwellSeconds,
            'frequency_weight': e.frequencyWeight,
            'min_gap_between_shows_seconds': e.minGapBetweenShowsSeconds,
            'min_placements_per_program': e.minPlacementsPerProgram,
            'max_placements_per_program': e.maxPlacementsPerProgram,
            'data_key': e.dataKey,
            'data_key_min_placements_per_program':
                e.dataKey.isEmpty
                    ? null
                    : dataKeyLimits[e.dataKey]?.minPlacementsPerProgram,
            'data_key_max_placements_per_program':
                e.dataKey.isEmpty
                    ? null
                    : dataKeyLimits[e.dataKey]?.maxPlacementsPerProgram,
          },
        )
        .toList();
    return Response.ok(
      jsonEncode({'items': list}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/ticker/items', (Request req) async {
    final rows = await ticker.snapshot();
    final list = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final e = rows[i];
      list.add({
        'ordinal': i,
        'kind': e.kind,
        'body': e.body,
      });
    }
    return Response.ok(
      jsonEncode({'items': list}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/alerts', (Request req) async {
    final rows = await db.select(db.alerts).get();
    return Response.ok(
      jsonEncode({'items': rows.map(_alertJson).toList()}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/alerts', (Request req) async {
    final body = await req.readAsString();
    final map = jsonDecode(body) as Map<String, dynamic>;
    final id = await alerts.insertAlert(
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      qrPayload: map['qr_payload'] as String?,
      severity: map['severity'] as String? ?? 'info',
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      expiresAtMs: (map['expires_at'] as num?)?.toInt(),
    );
    return Response.ok(
      jsonEncode({'id': id}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.delete('/v1/alerts/<id>', (Request req, String id) async {
    await alerts.dismiss(int.parse(id, radix: 10));
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.get('/v1/display/overlays', (Request req) async {
    await ensureOverlaysTableExists(db);
    final rows = await fetchDisplayOverlaySchedules(db);
    return Response.ok(
      jsonEncode({'items': rows.map(overlayScheduleToJson).toList()}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/display/overlays', (Request req) async {
    final map = await _readOverlayJson(req);
    if (map == null) {
      return Response(
        400,
        body: '{"error":"invalid_json_body"}',
        headers: {'content-type': 'application/json'},
      );
    }
    final id = map['id'] as String?;
    if (id == null || id.trim().isEmpty) {
      return Response(
        400,
        body: '{"error":"id_required"}',
        headers: {'content-type': 'application/json'},
      );
    }
    try {
      await upsertOverlaySchedule(
        db,
        id: id,
        enabled: _readBoolOverlay(map['enabled'], defaultIfAbsent: true),
        overlayType: _readOverlayTypeFromMap(map),
        label: map['label'] as String? ?? '',
        configJson: _effectiveOverlayConfigFromBody(map),
        repeatAnnually: _readBoolOverlay(map['repeat_annually'], defaultIfAbsent: true),
        yearExact: _readNullableIntOverlay(map['year_exact']),
        startMonth: _readIntOverlay(map['start_month']),
        startDay: _readIntOverlay(map['start_day']),
        endMonth: _readNullableIntOverlay(map['end_month']),
        endDay: _readNullableIntOverlay(map['end_day']),
        nthWeekOfMonth: _readNullableIntOverlay(map['nth_week_of_month']),
        nthWeekday: _readNullableIntOverlay(map['nth_weekday']),
      );
    } on FormatException catch (e) {
      return Response(
        400,
        body: jsonEncode({'error': e.message}),
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.patch('/v1/display/overlays/<id>', (Request req, String pathId) async {
    await ensureOverlaysTableExists(db);
    final existing = await overlayScheduleById(db, pathId);
    if (existing == null) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    final map = await _readOverlayJson(req);
    if (map == null) {
      return Response(
        400,
        body: '{"error":"invalid_json_body"}',
        headers: {'content-type': 'application/json'},
      );
    }
    try {
      await upsertOverlaySchedule(
        db,
        id: pathId,
        enabled: map.containsKey('enabled')
            ? _readBoolOverlay(map['enabled'], defaultIfAbsent: true)
            : existing.enabled,
        overlayType: _patchOverlayType(existing, map),
        label: map.containsKey('label')
            ? map['label'] as String? ?? ''
            : existing.label,
        configJson: _patchOverlayConfigJson(existing, map),
        repeatAnnually: map.containsKey('repeat_annually')
            ? _readBoolOverlay(map['repeat_annually'], defaultIfAbsent: true)
            : existing.repeatAnnually,
        yearExact:
            map.containsKey('year_exact')
                ? _readNullableIntOverlay(map['year_exact'])
                : existing.yearExact,
        startMonth:
            map.containsKey('start_month')
                ? _readIntOverlay(map['start_month'])
                : existing.startMonth,
        startDay:
            map.containsKey('start_day')
                ? _readIntOverlay(map['start_day'])
                : existing.startDay,
        endMonth:
            map.containsKey('end_month')
                ? _readNullableIntOverlay(map['end_month'])
                : existing.endMonth,
        endDay:
            map.containsKey('end_day')
                ? _readNullableIntOverlay(map['end_day'])
                : existing.endDay,
        nthWeekOfMonth:
            map.containsKey('nth_week_of_month')
                ? _readNullableIntOverlay(map['nth_week_of_month'])
                : existing.nthWeekOfMonth,
        nthWeekday:
            map.containsKey('nth_weekday')
                ? _readNullableIntOverlay(map['nth_weekday'])
                : existing.nthWeekday,
      );
    } on FormatException catch (e) {
      return Response(
        400,
        body: jsonEncode({'error': e.message}),
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.delete('/v1/display/overlays/<id>', (Request req, String id) async {
    await ensureOverlaysTableExists(db);
    final row = await overlayScheduleById(db, id);
    if (row == null) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    await deleteOverlaySchedule(db, id);
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.get('/v1/media/blob-by-key', (Request req) async {
    final key = req.url.queryParameters['key']?.trim() ?? '';
    if (!_isSafeBlobLookupKey(key)) {
      return Response(
        400,
        body: '{"error":"invalid_key"}',
        headers: {'content-type': 'application/json'},
      );
    }
    final row = await (db.select(db.blobMetadata)
          ..where((t) => t.blobKey.equals(key)))
        .getSingleOrNull();
    if (row == null) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    final read = await readDisplayBlobBytes(blobs, BlobRef(row.relativePath));
    if (!read.isOk) {
      return Response(
        404,
        body: '{"error":"blob_unavailable"}',
        headers: {'content-type': 'application/json'},
      );
    }
    final mime = row.mimeType?.trim();
    return Response.ok(
      read.bytes!,
      headers: {
        'content-type':
            (mime != null && mime.isNotEmpty) ? mime : 'application/octet-stream',
        'cache-control': 'private, max-age=60',
      },
    );
  });

  r.get('/v1/media/rss-articles/<id>', (Request req, String id) async {
    final row = await (db.select(db.rssArticles)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.suppressed) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.ok(
      jsonEncode({
        'id': row.id,
        'feed_id': row.feedId,
        'title': row.title,
        'summary': row.summary,
        'link': row.link,
        'image_blob_key': row.imageBlobKey,
        'published_at_ms': row.publishedAt.millisecondsSinceEpoch,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/media/photos/<id>', (Request req, String id) async {
    final row = await (db.select(db.photos)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.suppressed) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.ok(
      jsonEncode({
        'id': row.id,
        'category': row.category,
        'data_provider': row.dataProvider,
        'alt_text': row.altText,
        'photographer_name': row.photographerName,
        'photographer_url': row.photographerUrl,
        'pexels_page_url': row.pexelsPageUrl,
        'media_blob_key': row.mediaBlobKey,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/media/videos/<id>', (Request req, String id) async {
    final row = await (db.select(db.videos)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.suppressed) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.ok(
      jsonEncode({
        'id': row.id,
        'category': row.category,
        'data_provider': row.dataProvider,
        'alt_text': row.altText,
        'photographer_name': row.photographerName,
        'photographer_url': row.photographerUrl,
        'pexels_page_url': row.pexelsPageUrl,
        'media_blob_key': row.mediaBlobKey,
        'duration_seconds': row.durationSeconds,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/media/jokes/<id>', (Request req, String id) async {
    final row = await (db.select(db.jokes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.suppressed) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.ok(
      jsonEncode({
        'id': row.id,
        'category_id': row.categoryId,
        'setup': row.setup,
        'punchline': row.punchline,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/media/trivia/<id>', (Request req, String id) async {
    final row = await (db.select(db.triviaQuestions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.suppressed) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.ok(
      jsonEncode({
        'id': row.id,
        'category_id': row.categoryId,
        'question': row.question,
        'option_a': row.optionA,
        'option_b': row.optionB,
        'option_c': row.optionC,
        'option_d': row.optionD,
        'correct_option': row.correctOption,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/media/weather-at-location/<id>', (Request req, String id) async {
    final loc = await (db.select(db.weatherLocations)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (loc == null) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: {'content-type': 'application/json'},
      );
    }
    final cur = await (db.select(db.weatherCurrent)..where((t) => t.locationId.equals(id)))
        .getSingleOrNull();
    return Response.ok(
      jsonEncode({
        'location_id': loc.id,
        'location_name': loc.name,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'enabled': loc.enabled,
        'observed_at_ms': cur?.observedAtMs.millisecondsSinceEpoch,
        'current_temp_c': cur?.currentTemp,
        'current_description': cur?.currentDescription,
        'current_icon_blob_key': cur?.currentIconBlobKey,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  registerOperatorRestRoutes(
    r,
    db: db,
    onConfigChanged: onConfigChanged,
    telemetryHub: telemetryHub,
    navigationBus: navigationBus,
  );

  return r.call;
}

dynamic _jsonDecodeLoose(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(raw);
  } catch (_) {
    return raw;
  }
}

Map<String, dynamic> _alertJson(DashboardAlert a) => {
  'id': a.id,
  'title': a.title,
  'body': a.body,
  'severity': a.severity,
  'priority': a.priority,
  'qr_payload': a.qrPayload,
};

Future<Map<String, dynamic>?> _readOverlayJson(Request req) async {
  try {
    final decoded = jsonDecode(await req.readAsString());
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

String _readOverlayTypeFromMap(Map<String, dynamic> map) {
  final t = map['overlay_type'];
  if (t is String && t.trim().isNotEmpty) {
    return t.trim();
  }
  final k = map['overlay_kind'];
  if (k is String && k.trim().isNotEmpty) {
    return k.trim();
  }
  return '';
}

String _mergeLegacyMessagesJsonIntoConfigJson(
  String configJson,
  Map<String, dynamic> map,
) {
  if (!map.containsKey('messages_json')) {
    return configJson;
  }
  final legacyListJson = _messagesJsonArg(map);
  Map<String, dynamic> cfg;
  try {
    final d = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
    cfg = d is Map
        ? Map<String, dynamic>.from(d.map((k, v) => MapEntry(k.toString(), v)))
        : <String, dynamic>{};
  } catch (_) {
    cfg = <String, dynamic>{};
  }
  List<dynamic> raw;
  try {
    final decoded = jsonDecode(legacyListJson);
    raw = decoded is List ? decoded : <dynamic>[];
  } catch (_) {
    raw = <dynamic>[];
  }
  final msgs = <String>[
    for (final e in raw)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
  cfg['messages'] = msgs;
  return jsonEncode(cfg);
}

String _effectiveOverlayConfigFromBody(Map<String, dynamic> map) {
  final base = _configJsonArg(map);
  return _mergeLegacyMessagesJsonIntoConfigJson(base, map);
}

String _shallowMergeOverlayConfigJson(String existing, String patch) {
  Map<String, dynamic> e;
  Map<String, dynamic> p;
  try {
    final d = jsonDecode(existing.trim().isEmpty ? '{}' : existing);
    e = d is Map
        ? Map<String, dynamic>.from(d.map((k, v) => MapEntry(k.toString(), v)))
        : <String, dynamic>{};
  } catch (_) {
    e = <String, dynamic>{};
  }
  try {
    final d = jsonDecode(patch.trim().isEmpty ? '{}' : patch);
    p = d is Map
        ? Map<String, dynamic>.from(d.map((k, v) => MapEntry(k.toString(), v)))
        : <String, dynamic>{};
  } catch (_) {
    p = <String, dynamic>{};
  }
  return jsonEncode(<String, dynamic>{...e, ...p});
}

String _patchOverlayType(
  DisplayOverlayScheduleRow existing,
  Map<String, dynamic> map,
) {
  if (map.containsKey('overlay_type')) {
    return (map['overlay_type'] as String?)?.trim() ?? '';
  }
  if (map.containsKey('overlay_kind')) {
    return (map['overlay_kind'] as String?)?.trim() ?? '';
  }
  return existing.overlayType;
}

String _patchOverlayConfigJson(
  DisplayOverlayScheduleRow existing,
  Map<String, dynamic> map,
) {
  if (!map.containsKey('config_json') && !map.containsKey('messages_json')) {
    return existing.configJson;
  }
  var base = existing.configJson;
  if (map.containsKey('config_json')) {
    base = _shallowMergeOverlayConfigJson(base, _configJsonArg(map));
  }
  return _mergeLegacyMessagesJsonIntoConfigJson(base, map);
}

String _messagesJsonArg(Map<String, dynamic> map) {
  final v = map['messages_json'];
  if (v == null) {
    return '[]';
  }
  if (v is String) {
    return v;
  }
  if (v is List) {
    return jsonEncode([
      for (final e in v) e is String ? e : e.toString(),
    ]);
  }
  return '[]';
}

String _configJsonArg(Map<String, dynamic> map) {
  final v = map['config_json'];
  if (v == null) {
    return '{}';
  }
  if (v is String) {
    return v;
  }
  if (v is Map) {
    return jsonEncode(v);
  }
  return '{}';
}

bool _readBoolOverlay(Object? v, {required bool defaultIfAbsent}) {
  if (v == null) {
    return defaultIfAbsent;
  }
  if (v is bool) {
    return v;
  }
  if (v is String) {
    switch (v.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
        return true;
      case '0':
      case 'false':
      case 'no':
        return false;
      default:
        return defaultIfAbsent;
    }
  }
  if (v is num) {
    return v != 0;
  }
  return defaultIfAbsent;
}

int? _readNullableIntOverlay(Object? v) {
  if (v == null) {
    return null;
  }
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  return null;
}

int _readIntOverlay(Object? v, {String missingError = 'numeric_field_required'}) {
  final n = _readNullableIntOverlay(v);
  if (n == null) {
    throw FormatException(missingError);
  }
  return n;
}

Future<Response> _upsertRejectTerm(
  Request req,
  RejectTermRepository repo,
  AppDatabase db, {
  String? id,
}) async {
  Map<String, dynamic> body;
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return Response(400,
          body: '{"error":"expected_json_object"}',
          headers: {'content-type': 'application/json'});
    }
    body = decoded;
  } catch (_) {
    return Response(400,
        body: '{"error":"invalid_json"}',
        headers: {'content-type': 'application/json'});
  }
  final input = RejectTermInput.parse(
    rawTerm: body['term'] is String ? body['term'] as String : null,
    rawAction: body['action'] is String ? body['action'] as String : null,
  );
  if (input == null) {
    return Response(400,
        body: '{"error":"invalid_term_or_action"}',
        headers: {'content-type': 'application/json'});
  }
  final savedId = await repo.upsert(input, id: id);
  unawaited(rescanContentForBlockTerms(db));
  return Response.ok(
    jsonEncode({
      'id': savedId,
      'term': input.term,
      'action': input.action,
    }),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _setRejectCensorFormat(Request req, AppDatabase db) async {
  Map<String, dynamic> body;
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return Response(400,
          body: '{"error":"expected_json_object"}',
          headers: {'content-type': 'application/json'});
    }
    body = decoded;
  } catch (_) {
    return Response(400,
        body: '{"error":"invalid_json"}',
        headers: {'content-type': 'application/json'});
  }
  final raw = body['format'];
  if (raw is! String) {
    return Response(400,
        body: '{"error":"format_must_be_string"}',
        headers: {'content-type': 'application/json'});
  }
  const allowed = {
    kRejectCensorFormatAsterisksFull,
    kRejectCensorFormatAsterisksFixed,
    kRejectCensorFormatFirstLast,
    kRejectCensorFormatBracketedToken,
  };
  if (!allowed.contains(raw)) {
    return Response(400,
        body: '{"error":"unknown_format"}',
        headers: {'content-type': 'application/json'});
  }
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kRejectCensorFormatKvKey,
          value: raw,
        ),
      );
  return Response.ok(
    jsonEncode({'format': raw}),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _patchContentSuppressed(
  Request req,
  Future<int> Function(bool suppressed) apply,
) async {
  Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return Response(
        400,
        body: '{"error":"expected_json_object"}',
        headers: {'content-type': 'application/json'},
      );
    }
    map = decoded;
  } catch (_) {
    return Response(
      400,
      body: '{"error":"invalid_json"}',
      headers: {'content-type': 'application/json'},
    );
  }
  final suppressed = map['suppressed'];
  if (suppressed is! bool) {
    return Response(
      400,
      body: '{"error":"suppressed_must_be_bool"}',
      headers: {'content-type': 'application/json'},
    );
  }
  final n = await apply(suppressed);
  if (n == 0) {
    return Response(
      404,
      body: '{"error":"not_found"}',
      headers: {'content-type': 'application/json'},
    );
  }
  return Response.ok('{}', headers: {'content-type': 'application/json'});
}

bool _isSafeBlobLookupKey(String key) {
  if (key.isEmpty || key.length > 512) {
    return false;
  }
  if (key.contains('..')) {
    return false;
  }
  return true;
}

Handler buildRootHandler({
  required AppDatabase db,
  required AlertRepository alerts,
  required AdoptionRepository? adoption,
  required CorsOriginRepository corsOrigins,
  required TickerCuratedRepository ticker,
  required BlobStore blobs,
  required Future<void> Function() onConfigChanged,
  required Map<String, String> env,
  OperatorTelemetryHub? telemetryHub,
  DisplayNavigationBus? navigationBus,
  CorsPolicy? corsPolicy,
}) {
  final effectiveCorsPolicy = corsPolicy ?? CorsPolicy();
  Response health(Request req) =>
      Response.ok('{"status":"ok"}', headers: {'content-type': 'application/json'});

  final adoptionPublic = Router();
  registerAdoptionRoutes(
    adoptionPublic,
    adoption: adoption,
    alerts: alerts,
    corsOrigins: corsOrigins,
  );

  final Handler apiProtected;
  if (adoption != null) {
    apiProtected = Pipeline()
        .addMiddleware(apiKeyAuth(adoption))
        .addMiddleware(routePermissionGuard())
        .addHandler(
          buildProtectedApiRouter(
            db: db,
            alerts: alerts,
            ticker: ticker,
            blobs: blobs,
            onConfigChanged: onConfigChanged,
            telemetryHub: telemetryHub,
            navigationBus: navigationBus,
          ),
        );
  } else {
    apiProtected = (Request req) => Response(
      503,
      body: '{"error":"api_unavailable"}',
      headers: {'content-type': 'application/json'},
    );
  }

  FutureOr<Response> root(Request req) {
    final path = req.requestedUri.path;
    if (path == '/v1/health' || path == 'v1/health') {
      return health(req);
    }
    if (path.startsWith('/admin') || path.startsWith('admin')) {
      return Response(
        410,
        body: '{"error":"admin_ui_removed"}',
        headers: {'content-type': 'application/json'},
      );
    }
    if (path.startsWith('/v1/adoption') || path.startsWith('v1/adoption')) {
      return adoptionPublic(req);
    }
    return apiProtected(req);
  }

  final handler = withDebugRequestLogging(
    _dynamicCorsWrap(
      root,
      corsPolicy: effectiveCorsPolicy,
      corsOrigins: corsOrigins,
    ),
  );
  return handler;
}

Handler _dynamicCorsWrap(
  Handler inner, {
  required CorsPolicy corsPolicy,
  required CorsOriginRepository corsOrigins,
}) {
  return (Request req) async {
    final origin = callerOriginFromRequest(req);
    final path = req.requestedUri.path;
    final allowed = isAdoptionPath(path)
        ? await corsPolicy.isAdoptionOriginAllowed(origin)
        : await corsPolicy.isProtectedOriginAllowed(origin, corsOrigins);

    if (allowed && origin != null && req.method == 'OPTIONS') {
      return Response(204, headers: _corsHeaders(origin));
    }
    final res = await inner(req);
    if (!allowed || origin == null) {
      return res;
    }
    return res.change(headers: _corsHeaders(origin));
  };
}

Map<String, String> _corsHeaders(String origin) => {
  'access-control-allow-origin': origin,
  'access-control-allow-methods':
      'GET,POST,PATCH,PUT,DELETE,OPTIONS',
  'access-control-allow-headers': 'Content-Type, Authorization',
  'access-control-max-age': '86400',
};

/// Logs method, path, and status in debug only (never logs headers or body).
Handler withDebugRequestLogging(Handler inner) {
  return (Request req) async {
    if (kDebugMode) {
      AppDebugLog.api('${req.method} ${req.requestedUri.path}');
    }
    final res = await inner(req);
    if (kDebugMode) {
      AppDebugLog.api(
        '${req.method} ${req.requestedUri.path} -> ${res.statusCode}',
      );
    }
    return res;
  };
}

class LocalRestServer {
  LocalRestServer._(this._server, this._host, this._port);

  final HttpServer _server;
  final String _host;
  final int _port;

  String get baseUrl => 'http://$_host:$_port';
  String get displayBaseUrl => 'http://${_displayHost ?? _host}:$_port';
  String? _displayHost;

  Future<void> close() => _server.close(force: true);

  static Future<LocalRestServer> bind({
    required Handler handler,
    InternetAddress? address,
    int port = 8787,
    String? displayHost,
  }) async {
    final addr = address ?? InternetAddress.loopbackIPv4;
    final server = await shelf_io.serve(
      handler,
      addr,
      port,
    );
    final out = LocalRestServer._(server, server.address.address, server.port);
    out._displayHost = displayHost;
    return out;
  }
}

