import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../debug/operator_telemetry_hub.dart';
import '../display/display_navigation_bus.dart';
import '../theme/display_theme.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

dynamic _jsonFieldDecode(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(raw);
  } catch (_) {
    return raw;
  }
}

void registerOperatorRestRoutes(
  Router r, {
  required AppDatabase db,
  required Future<void> Function() onConfigChanged,
  OperatorTelemetryHub? telemetryHub,
  DisplayNavigationBus? navigationBus,
}) {
  r.get('/v1/telemetry/providers', (Request req) async {
    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 200;
    final sinceMs = int.tryParse(req.url.queryParameters['since_ms'] ?? '');
    final items = telemetryHub?.snapshotProviderLines(
          limit: limit.clamp(1, 2000),
          sinceMs: sinceMs,
        ) ??
        const <Map<String, Object?>>[];
    return Response.ok(
      jsonEncode({'items': items}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/telemetry/programs', (Request req) async {
    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 50;
    final sinceMs = int.tryParse(req.url.queryParameters['since_ms'] ?? '');
    final items = telemetryHub?.snapshotScreenPrograms(
          limit: limit.clamp(1, 500),
          sinceMs: sinceMs,
        ) ??
        const <Map<String, Object?>>[];
    return Response.ok(
      jsonEncode({'items': items}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/telemetry/ticker-programs', (Request req) async {
    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 50;
    final sinceMs = int.tryParse(req.url.queryParameters['since_ms'] ?? '');
    final items = telemetryHub?.snapshotTickerPrograms(
          limit: limit.clamp(1, 500),
          sinceMs: sinceMs,
        ) ??
        const <Map<String, Object?>>[];
    return Response.ok(
      jsonEncode({'items': items}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/display/navigation', (Request req) async {
    if (navigationBus == null) {
      return Response(
        503,
        body: '{"error":"navigation_unavailable"}',
        headers: {'content-type': 'application/json'},
      );
    }
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}',
            headers: {'content-type': 'application/json'});
      }
      map = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}',
          headers: {'content-type': 'application/json'});
    }
    final surface = map['surface'] as String?;
    final direction = map['direction'] as String?;
    final delta = switch (direction) {
      'back' => -1,
      'forward' => 1,
      _ => null,
    };
    if (delta == null) {
      return Response(400,
          body: '{"error":"direction_must_be_back_or_forward"}',
          headers: {'content-type': 'application/json'});
    }
    switch (surface) {
      case 'screen':
        navigationBus.enqueueScreenNav(delta);
      case 'ticker':
        navigationBus.enqueueTickerNav(delta);
      default:
        return Response(400,
            body: '{"error":"surface_must_be_screen_or_ticker"}',
            headers: {'content-type': 'application/json'});
    }
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.get('/v1/meta/screen-types', (Request req) async {
    final items = <Map<String, Object?>>[];
    for (final t in kScreenLayoutWidgetTypes) {
      final doc = screenConfigJsonDocForType(t);
      items.add({
        'screen_type': t,
        'config_json_schema': _jsonFieldDecode(doc.schema),
        'example_config_json': _jsonFieldDecode(doc.example),
      });
    }
    return Response.ok(
      jsonEncode({'items': items}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/ticker/definitions', (Request req) async {
    final rows = await (db.select(db.tickerDefinitions)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return Response.ok(
      jsonEncode({
        'items': [
          for (final e in rows)
            {
              'id': e.id,
              'name': e.name,
              'description': e.description,
              'enabled': e.enabled,
              'ticker_type': e.tickerType,
              'frequency_weight': e.frequencyWeight,
              'sort_order': e.sortOrder,
              'config_key': e.configKey,
              'config_json_schema': _jsonFieldDecode(e.configJsonSchema),
              'example_config_json': _jsonFieldDecode(e.exampleConfigJson),
            },
        ],
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.patch('/v1/ticker/definitions/<id>', (Request req, String id) async {
    final existing = await (db.select(db.tickerDefinitions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}',
            headers: {'content-type': 'application/json'});
      }
      map = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}',
          headers: {'content-type': 'application/json'});
    }
    final enabled =
        map.containsKey('enabled') ? map['enabled'] as bool? : existing.enabled;
    final weight = map.containsKey('frequency_weight')
        ? (map['frequency_weight'] as num?)?.toInt()
        : existing.frequencyWeight;
    final sortOrder = map.containsKey('sort_order')
        ? (map['sort_order'] as num?)?.toInt()
        : existing.sortOrder;
    final configKey = map.containsKey('config_key')
        ? map['config_key'] as String?
        : existing.configKey;
    if (enabled == null || weight == null || sortOrder == null) {
      return Response(400,
          body: '{"error":"invalid_fields"}',
          headers: {'content-type': 'application/json'});
    }
    await (db.update(db.tickerDefinitions)..where((t) => t.id.equals(id))).write(
      TickerDefinitionsCompanion(
        enabled: Value(enabled),
        frequencyWeight: Value(weight),
        sortOrder: Value(sortOrder),
        configKey: configKey == null
            ? const Value.absent()
            : Value(configKey.isEmpty ? null : configKey),
      ),
    );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.get('/v1/curator/settings', (Request req) async {
    final kvRows = await db.select(db.configKeyValues).get();
    final kv = {for (final r in kvRows) r.key: r.value};
    final programDurationSeconds = int.tryParse(
          kv[kCuratorProgramDurationSecondsKvKey]?.trim() ?? '',
        ) ??
        180;
    final historyDepth =
        int.tryParse(kv[kCuratorHistoryDepthKvKey]?.trim() ?? '') ?? 5;
    final tickerPx = kv['curator.ticker.newsPixelsPerSecond'] ?? '80';
    final requireNewsPhotoForScreens =
        kv[kRequireNewsPhotoForScreensKvKey] ?? 'true';
    final themeId = normalizeDisplayThemeId(kv[kDisplayThemeIdKvKey]);
    final screenTextScale = normalizeDisplayTextScaleOption(
      kv[kDisplayTextScaleScreenKvKey],
    );
    final tickerTextScale = normalizeDisplayTextScaleOption(
      kv[kDisplayTextScaleTickerKvKey],
    );
    return Response.ok(
      jsonEncode({
        'program_duration_seconds': programDurationSeconds,
        'history_depth': historyDepth,
        'ticker_pixels_per_second': tickerPx,
        'require_news_photo_for_screens': requireNewsPhotoForScreens != 'false',
        'display_theme_id': themeId,
        'display_text_scale_screen': screenTextScale,
        'display_text_scale_ticker': tickerTextScale,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.put('/v1/curator/settings', (Request req) async {
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
    final duration = (body['program_duration_seconds'] as num?)?.toInt() ??
        int.tryParse('${body['program_duration_seconds'] ?? ''}');
    final depth = (body['history_depth'] as num?)?.toInt() ??
        int.tryParse('${body['history_depth'] ?? ''}');
    if (duration == null || depth == null) {
      return Response(400,
          body: '{"error":"program_duration_seconds_and_history_depth_required"}',
          headers: {'content-type': 'application/json'});
    }
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kCuratorProgramDurationSecondsKvKey,
            value: '$duration',
          ),
        );
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kCuratorHistoryDepthKvKey,
            value: '$depth',
          ),
        );
    final tickerPx = (body['ticker_pixels_per_second'] as String?)?.trim() ??
        (body['ticker_pixels_per_second'] as num?)?.toString();
    if (tickerPx != null && tickerPx.isNotEmpty) {
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: 'curator.ticker.newsPixelsPerSecond',
              value: tickerPx,
            ),
          );
    }
    if (body.containsKey('require_news_photo_for_screens')) {
      final v = body['require_news_photo_for_screens'];
      final flag = v is bool ? v : v?.toString().toLowerCase() == 'true';
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kRequireNewsPhotoForScreensKvKey,
              value: flag ? 'true' : 'false',
            ),
          );
    }
    if (body.containsKey('display_theme_id')) {
      final themeId = normalizeDisplayThemeId('${body['display_theme_id']}');
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kDisplayThemeIdKvKey,
              value: themeId,
            ),
          );
    }
    if (body.containsKey('display_text_scale_screen')) {
      final screenTextScale = normalizeDisplayTextScaleOption(
        '${body['display_text_scale_screen']}',
      );
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kDisplayTextScaleScreenKvKey,
              value: screenTextScale,
            ),
          );
    }
    if (body.containsKey('display_text_scale_ticker')) {
      final tickerTextScale = normalizeDisplayTextScaleOption(
        '${body['display_text_scale_ticker']}',
      );
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kDisplayTextScaleTickerKvKey,
              value: tickerTextScale,
            ),
          );
    }
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.patch('/v1/providers/<id>', (Request req, String id) async {
    final existing = await (db.select(db.providerSettings)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}',
            headers: {'content-type': 'application/json'});
      }
      map = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}',
          headers: {'content-type': 'application/json'});
    }
    final poll = map.containsKey('poll_seconds')
        ? (map['poll_seconds'] as num?)?.toInt()
        : existing.pollSeconds;
    if (poll == null) {
      return Response(400,
          body: '{"error":"invalid_poll_seconds"}',
          headers: {'content-type': 'application/json'});
    }
    final enabled =
        map.containsKey('enabled') ? map['enabled'] as bool? : existing.enabled;
    if (enabled == null) {
      return Response(400,
          body: '{"error":"invalid_enabled"}',
          headers: {'content-type': 'application/json'});
    }
    String? baseUrl = existing.baseUrl;
    if (map.containsKey('base_url')) {
      final raw = map['base_url'];
      if (raw == null) {
        baseUrl = null;
      } else {
        final s = '$raw'.trim();
        baseUrl = s.isEmpty ? null : s;
      }
    }
    String? configJson = existing.configJson;
    if (map.containsKey('config_json')) {
      final v = map['config_json'];
      if (v == null) {
        configJson = null;
      } else if (v is String) {
        final t = v.trim();
        configJson = t.isEmpty ? null : t;
      } else if (v is Map) {
        configJson = jsonEncode(v);
      } else {
        return Response(400,
            body: '{"error":"config_json_must_be_string_or_object"}',
            headers: {'content-type': 'application/json'});
      }
    }
    await (db.update(db.providerSettings)..where((t) => t.id.equals(id))).write(
      ProviderSettingsCompanion(
        enabled: Value(enabled),
        pollSeconds: Value(poll),
        baseUrl: Value(baseUrl),
        configJson: Value(configJson),
      ),
    );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.post('/v1/screens', (Request req) async {
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}',
            headers: {'content-type': 'application/json'});
      }
      map = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}',
          headers: {'content-type': 'application/json'});
    }
    final id = (map['id'] as String?)?.trim() ?? '';
    final screenType = (map['screen_type'] as String?)?.trim() ?? '';
    if (id.isEmpty || screenType.isEmpty) {
      return Response(400,
          body: '{"error":"id_and_screen_type_required"}',
          headers: {'content-type': 'application/json'});
    }
    if (!kScreenLayoutWidgetTypes.contains(screenType)) {
      return Response(400,
          body: '{"error":"unknown_screen_type"}',
          headers: {'content-type': 'application/json'});
    }
    final dup = await (db.select(db.screenDefinitions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (dup != null) {
      return Response(409,
          body: '{"error":"id_already_exists"}',
          headers: {'content-type': 'application/json'});
    }
    final doc = screenConfigJsonDocForType(screenType);
    late final String configJsonStr;
    try {
      configJsonStr = _configJsonStringFromBody(map['config_json']);
    } on FormatException catch (e) {
      return Response(400,
          body: jsonEncode({'error': 'invalid_config_json', 'detail': e.message}),
          headers: {'content-type': 'application/json'});
    }
    final layout = synthesizeLayoutJson(
      screenType: screenType,
      configJson: configJsonStr,
    );
    if (parseScreenLayoutWidgets(layout).isEmpty) {
      return Response(400,
          body: '{"error":"invalid_screen_layout"}',
          headers: {'content-type': 'application/json'});
    }
    final name = (map['name'] as String?)?.trim();
    final description = (map['description'] as String?)?.trim() ?? '';
    final enabled = map['enabled'] is bool ? map['enabled'] as bool : true;
    final dwellSeconds = (map['dwell_seconds'] as num?)?.toInt() ?? 10;
    final frequencyWeight = (map['frequency_weight'] as num?)?.toInt() ?? 100;
    final minGap = (map['min_gap_between_shows_seconds'] as num?)?.toInt() ?? 0;
    final minPlacements =
        (map['min_placements_per_program'] as num?)?.toInt() ?? 0;
    final maxPlacements = (map['max_placements_per_program'] as num?)?.toInt();
    final dataKey = (map['data_key'] as String?)?.trim() ?? '';
    final resolvedName = (name == null || name.isEmpty) ? id : name;
    await db.into(db.screenDefinitions).insert(
          ScreenDefinitionsCompanion.insert(
            id: id,
            name: resolvedName,
            description: Value(description),
            enabled: Value(enabled),
            screenType: screenType,
            configJson: Value(configJsonStr),
            configJsonSchema: Value(doc.schema),
            exampleConfigJson: Value(doc.example),
            dwellSeconds: Value(dwellSeconds),
            frequencyWeight: Value(frequencyWeight),
            minGapBetweenShowsSeconds: Value(minGap),
            minPlacementsPerProgram: Value(minPlacements),
            maxPlacementsPerProgram: maxPlacements == null
                ? const Value.absent()
                : Value(maxPlacements),
            dataKey: Value(dataKey),
          ),
        );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.patch('/v1/screens/<id>', (Request req, String id) async {
    final existing = await (db.select(db.screenDefinitions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response(400,
            body: '{"error":"expected_json_object"}',
            headers: {'content-type': 'application/json'});
      }
      map = decoded;
    } catch (_) {
      return Response(400,
          body: '{"error":"invalid_json"}',
          headers: {'content-type': 'application/json'});
    }
    final screenType = map.containsKey('screen_type')
        ? (map['screen_type'] as String?)?.trim() ?? existing.screenType
        : existing.screenType;
    if (!kScreenLayoutWidgetTypes.contains(screenType)) {
      return Response(400,
          body: '{"error":"unknown_screen_type"}',
          headers: {'content-type': 'application/json'});
    }
    late final String resolvedConfigJson;
    try {
      resolvedConfigJson = map.containsKey('config_json')
          ? _configJsonStringFromBody(map['config_json'])
          : existing.configJson;
    } on FormatException catch (e) {
      return Response(400,
          body: jsonEncode({'error': 'invalid_config_json', 'detail': e.message}),
          headers: {'content-type': 'application/json'});
    }
    final layout = synthesizeLayoutJson(
      screenType: screenType,
      configJson: resolvedConfigJson,
    );
    if (parseScreenLayoutWidgets(layout).isEmpty) {
      return Response(400,
          body: '{"error":"invalid_screen_layout"}',
          headers: {'content-type': 'application/json'});
    }
    final doc = screenConfigJsonDocForType(screenType);
    final name = map.containsKey('name')
        ? ((map['name'] as String?)?.trim() ?? '')
        : existing.name;
    final description = map.containsKey('description')
        ? ((map['description'] as String?)?.trim() ?? '')
        : existing.description;
    final enabled = map.containsKey('enabled') && map['enabled'] is bool
        ? map['enabled'] as bool
        : existing.enabled;
    final dwellSeconds = map.containsKey('dwell_seconds')
        ? ((map['dwell_seconds'] as num?)?.toInt() ?? existing.dwellSeconds)
        : existing.dwellSeconds;
    final frequencyWeight = map.containsKey('frequency_weight')
        ? ((map['frequency_weight'] as num?)?.toInt() ?? existing.frequencyWeight)
        : existing.frequencyWeight;
    final minGap = map.containsKey('min_gap_between_shows_seconds')
        ? ((map['min_gap_between_shows_seconds'] as num?)?.toInt() ??
            existing.minGapBetweenShowsSeconds)
        : existing.minGapBetweenShowsSeconds;
    final minPlacements = map.containsKey('min_placements_per_program')
        ? ((map['min_placements_per_program'] as num?)?.toInt() ??
            existing.minPlacementsPerProgram)
        : existing.minPlacementsPerProgram;
    final maxPlacements = map.containsKey('max_placements_per_program')
        ? (map['max_placements_per_program'] as num?)?.toInt()
        : existing.maxPlacementsPerProgram;
    final dataKey = map.containsKey('data_key')
        ? ((map['data_key'] as String?)?.trim() ?? '')
        : existing.dataKey;
    await (db.update(db.screenDefinitions)..where((t) => t.id.equals(id))).write(
      ScreenDefinitionsCompanion(
        name: Value(name),
        description: Value(description),
        enabled: Value(enabled),
        screenType: Value(screenType),
        configJson: Value(resolvedConfigJson),
        configJsonSchema: Value(doc.schema),
        exampleConfigJson: Value(doc.example),
        dwellSeconds: Value(dwellSeconds),
        frequencyWeight: Value(frequencyWeight),
        minGapBetweenShowsSeconds: Value(minGap),
        minPlacementsPerProgram: Value(minPlacements),
        maxPlacementsPerProgram: Value(maxPlacements),
        dataKey: Value(dataKey),
      ),
    );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.delete('/v1/screens/<id>', (Request req, String id) async {
    final n = await (db.delete(db.screenDefinitions)
          ..where((t) => t.id.equals(id)))
        .go();
    if (n == 0) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });
}

String _configJsonStringFromBody(dynamic v) {
  if (v == null) {
    return '{}';
  }
  if (v is String) {
    return v.trim().isEmpty ? '{}' : v.trim();
  }
  if (v is Map) {
    return jsonEncode(v);
  }
  throw const FormatException('config_json_must_be_string_or_object');
}
