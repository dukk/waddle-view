import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../debug/operator_telemetry_hub.dart';
import '../display/display_navigation_bus.dart';
import 'curator_configuration_routes.dart';
import '../theme/display_theme.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/config/adoption_allowed_roles.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/content_category_defaults.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

import 'integration_accounts_rest_routes.dart';
import 'integration_oauth_providers_rest_routes.dart';
import 'integration_secrets_rest_routes.dart';

final Set<String> _reservedCuratorCategoryIds = {
  for (final d in kContentCategoryDefaults) d.id,
};

bool _isValidCuratorCategoryId(String id) {
  return RegExp(r'^[a-z][a-z0-9_]{0,62}$').hasMatch(id);
}

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
  required SecretStore secrets,
  required Future<void> Function() onConfigChanged,
  OperatorTelemetryHub? telemetryHub,
  DisplayNavigationBus? navigationBus,
}) {
  registerIntegrationSecretsRestRoutes(r, db: db, secrets: secrets);
  registerIntegrationAccountsRestRoutes(r, db: db, secrets: secrets);
  registerIntegrationOAuthProvidersRestRoutes(r, secrets: secrets);
  r.get('/v1/telemetry/integrations', (Request req) async {
    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 200;
    final sinceMs = int.tryParse(req.url.queryParameters['since_ms'] ?? '');
    final items = telemetryHub?.snapshotIntegrationLines(
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

  r.get('/v1/meta/ticker-types', (Request req) async {
    final items = <Map<String, Object?>>[];
    for (final t in kTickerSlotDefinitionTypes) {
      final doc = tickerSlotConfigJsonDocForType(t);
      items.add({
        'ticker_type': t,
        'config_json_schema': _jsonFieldDecode(doc.schema),
        'example_config_json': _jsonFieldDecode(doc.example),
      });
    }
    return Response.ok(
      jsonEncode({'items': items}),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/ticker/tapes', (Request req) async {
    final rows = await (db.select(db.tickerTapes)
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
              'ticker_type': e.tickerType,
              'frequency_weight': e.frequencyWeight,
              'sort_order': e.sortOrder,
              'config_key': e.configKey,
              'config_json': _jsonFieldDecode(e.configJson),
              'config_json_schema': _jsonFieldDecode(e.configJsonSchema),
              'example_config_json': _jsonFieldDecode(e.exampleConfigJson),
            },
        ],
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/ticker/tapes', (Request req) async {
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
    final tickerType = (map['ticker_type'] as String?)?.trim() ?? '';
    if (id.isEmpty || tickerType.isEmpty) {
      return Response(400,
          body: '{"error":"id_and_ticker_type_required"}',
          headers: {'content-type': 'application/json'});
    }
    if (!kTickerSlotDefinitionTypes.contains(tickerType)) {
      return Response(400,
          body: '{"error":"unknown_ticker_type"}',
          headers: {'content-type': 'application/json'});
    }
    final dup = await (db.select(db.tickerTapes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (dup != null) {
      return Response(409,
          body: '{"error":"id_already_exists"}',
          headers: {'content-type': 'application/json'});
    }
    final doc = tickerSlotConfigJsonDocForType(tickerType);
    final name = (map['name'] as String?)?.trim();
    final description = (map['description'] as String?)?.trim() ?? '';
    final frequencyWeight = (map['frequency_weight'] as num?)?.toInt() ?? 100;
    final sortOrder = (map['sort_order'] as num?)?.toInt() ?? 0;
    final rawCk = map['config_key'];
    String? configKey;
    if (rawCk is String) {
      final t = rawCk.trim();
      configKey = t.isEmpty ? null : t;
    }
    final resolvedName = (name == null || name.isEmpty) ? id : name;
    String configJsonStr = '{}';
    if (map.containsKey('config_json')) {
      try {
        configJsonStr = _configJsonStringFromBody(map['config_json']);
      } on FormatException {
        return Response(400,
            body: '{"error":"config_json_must_be_string_or_object"}',
            headers: {'content-type': 'application/json'});
      }
    }
    await db.into(db.tickerTapes).insert(
          TickerTapesCompanion.insert(
            id: id,
            name: resolvedName,
            description: Value(description),
            tickerType: tickerType,
            frequencyWeight: Value(frequencyWeight),
            sortOrder: Value(sortOrder),
            configKey: configKey == null
                ? const Value.absent()
                : Value(configKey),
            configJson: Value(configJsonStr),
            configJsonSchema: Value(doc.schema),
            exampleConfigJson: Value(doc.example),
          ),
        );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.patch('/v1/ticker/tapes/<id>', (Request req, String id) async {
    final existing = await (db.select(db.tickerTapes)
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
    final weight = map.containsKey('frequency_weight')
        ? (map['frequency_weight'] as num?)?.toInt()
        : existing.frequencyWeight;
    final sortOrder = map.containsKey('sort_order')
        ? (map['sort_order'] as num?)?.toInt()
        : existing.sortOrder;
    final Value<String?> configKeyVal;
    if (!map.containsKey('config_key')) {
      configKeyVal = const Value.absent();
    } else {
      final ck = map['config_key'] as String?;
      configKeyVal =
          Value(ck == null || ck.trim().isEmpty ? null : ck.trim());
    }
    final name = map.containsKey('name')
        ? ((map['name'] as String?)?.trim() ?? '')
        : existing.name;
    final description = map.containsKey('description')
        ? ((map['description'] as String?)?.trim() ?? '')
        : existing.description;
    final tickerType = map.containsKey('ticker_type')
        ? (map['ticker_type'] as String?)?.trim() ?? existing.tickerType
        : existing.tickerType;
    if (weight == null || sortOrder == null) {
      return Response(400,
          body: '{"error":"invalid_fields"}',
          headers: {'content-type': 'application/json'});
    }
    if (!kTickerSlotDefinitionTypes.contains(tickerType)) {
      return Response(400,
          body: '{"error":"unknown_ticker_type"}',
          headers: {'content-type': 'application/json'});
    }
    final Value<String> configJsonVal;
    if (!map.containsKey('config_json')) {
      configJsonVal = const Value.absent();
    } else {
      try {
        configJsonVal = Value(_configJsonStringFromBody(map['config_json']));
      } on FormatException catch (e) {
        return Response(
          400,
          body: jsonEncode({'error': 'invalid_config_json', 'detail': e.message}),
          headers: {'content-type': 'application/json'},
        );
      }
    }
    final doc = tickerSlotConfigJsonDocForType(tickerType);
    await (db.update(db.tickerTapes)..where((t) => t.id.equals(id))).write(
      TickerTapesCompanion(
        name: Value(name),
        description: Value(description),
        frequencyWeight: Value(weight),
        sortOrder: Value(sortOrder),
        configKey: configKeyVal,
        tickerType: Value(tickerType),
        configJson: configJsonVal,
        configJsonSchema: Value(doc.schema),
        exampleConfigJson: Value(doc.example),
      ),
    );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.delete('/v1/ticker/tapes/<id>', (Request req, String id) async {
    final n =
        await (db.delete(db.tickerTapes)..where((t) => t.id.equals(id))).go();
    if (n == 0) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.get('/v1/curator/settings', (Request req) async {
    final kvRows = await db.select(db.configKeyValues).get();
    final kv = {for (final r in kvRows) r.key: r.value};
    final tickerPx = kv['curator.ticker.newsPixelsPerSecond'] ?? '80';
    final themeId = normalizeDisplayThemeId(kv[kDisplayThemeIdKvKey]);
    final screenTextScale = normalizeDisplayTextScaleOption(
      kv[kDisplayTextScaleScreenKvKey],
    );
    final tickerTextScale = normalizeDisplayTextScaleOption(
      kv[kDisplayTextScaleTickerKvKey],
    );
    final tzRaw = kv[kDisplayTimezoneKvKey]?.trim() ?? '';
    final displayTimezone =
        tzRaw.isEmpty ? kDefaultDisplayTimezoneIana : tzRaw;
    final adoptionAllowedRoles = await readAdoptionAllowedRoles(db);
    final adoptionRolesList = adoptionAllowedRoles.toList()
      ..sort((a, b) {
        final ai = kAdoptionConfigurableRoles.indexOf(a);
        final bi = kAdoptionConfigurableRoles.indexOf(b);
        return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
      });
    return Response.ok(
      jsonEncode({
        'ticker_pixels_per_second': tickerPx,
        'display_theme_id': themeId,
        'display_text_scale_screen': screenTextScale,
        'display_text_scale_ticker': tickerTextScale,
        'display_timezone': displayTimezone,
        'adoption_allowed_roles': adoptionRolesList,
        'adoption_allow_new_requests': adoptionAllowedRoles.isNotEmpty,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/curator/categories', (Request req) async {
    final rows = await db.select(db.contentCategories).get();
    return Response.ok(
      jsonEncode({
        'items': [
          for (final r in rows)
            {
              'id': r.id,
              'label': r.label,
              'material_icon_name': r.materialIconName,
              'icon_blob_key': r.iconBlobKey,
              'reserved': _reservedCuratorCategoryIds.contains(r.id),
            },
        ],
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/curator/categories', (Request req) async {
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
    final id = '${body['id'] ?? ''}'.trim();
    final label = '${body['label'] ?? ''}'.trim();
    if (id.isEmpty || label.isEmpty) {
      return Response(400,
          body: '{"error":"id_and_label_required"}',
          headers: {'content-type': 'application/json'});
    }
    if (!_isValidCuratorCategoryId(id)) {
      return Response(400,
          body: '{"error":"invalid_category_id"}',
          headers: {'content-type': 'application/json'});
    }
    final existing = await (db.select(db.contentCategories)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing != null) {
      return Response(409,
          body: '{"error":"category_id_exists"}',
          headers: {'content-type': 'application/json'});
    }
    String? material;
    final rawMat = body['material_icon_name'];
    if (rawMat != null) {
      final s = '$rawMat'.trim();
      material = s.isEmpty ? null : s;
    }
    String? iconKey;
    final rawIcon = body['icon_blob_key'];
    if (rawIcon != null) {
      final s = '$rawIcon'.trim();
      iconKey = s.isEmpty ? null : s;
    }
    await db.into(db.contentCategories).insert(
          ContentCategoriesCompanion.insert(
            id: id,
            label: label,
            materialIconName: Value(material),
            iconBlobKey: Value(iconKey),
          ),
        );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.patch('/v1/curator/categories/<id>', (Request req, String id) async {
    final existing = await (db.select(db.contentCategories)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
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
    final label = body.containsKey('label')
        ? '${body['label']}'.trim()
        : existing.label;
    if (label.isEmpty) {
      return Response(400,
          body: '{"error":"invalid_label"}',
          headers: {'content-type': 'application/json'});
    }
    String? material;
    if (body.containsKey('material_icon_name')) {
      final raw = body['material_icon_name'];
      material = raw == null ? null : '$raw'.trim();
      if (material != null && material.isEmpty) {
        material = null;
      }
    } else {
      material = existing.materialIconName;
    }
    String? iconKey;
    if (body.containsKey('icon_blob_key')) {
      final raw = body['icon_blob_key'];
      iconKey = raw == null ? null : '$raw'.trim();
      if (iconKey != null && iconKey.isEmpty) {
        iconKey = null;
      }
    } else {
      iconKey = existing.iconBlobKey;
    }
    await (db.update(db.contentCategories)..where((t) => t.id.equals(id))).write(
      ContentCategoriesCompanion(
        label: Value(label),
        materialIconName: Value(material),
        iconBlobKey: Value(iconKey),
      ),
    );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.delete('/v1/curator/categories/<id>', (Request req, String id) async {
    if (_reservedCuratorCategoryIds.contains(id)) {
      return Response(403,
          body: '{"error":"reserved_category"}',
          headers: {'content-type': 'application/json'});
    }
    final cal = await (db.select(db.calendarEvents)
          ..where((t) => t.categoryId.equals(id)))
        .get();
    if (cal.isNotEmpty) {
      return Response(409,
          body: '{"error":"category_in_use_calendar"}',
          headers: {'content-type': 'application/json'});
    }
    final n =
        await (db.delete(db.contentCategories)..where((t) => t.id.equals(id)))
            .go();
    if (n == 0) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
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
    var touched = false;
    final tickerPx = (body['ticker_pixels_per_second'] as String?)?.trim() ??
        (body['ticker_pixels_per_second'] as num?)?.toString();
    if (tickerPx != null && tickerPx.isNotEmpty) {
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: 'curator.ticker.newsPixelsPerSecond',
              value: tickerPx,
            ),
          );
      touched = true;
    }
    if (body.containsKey('display_theme_id')) {
      final themeId = normalizeDisplayThemeId('${body['display_theme_id']}');
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kDisplayThemeIdKvKey,
              value: themeId,
            ),
          );
      touched = true;
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
      touched = true;
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
      touched = true;
    }
    if (body.containsKey('display_timezone')) {
      final raw = body['display_timezone'];
      final s = raw == null ? '' : '$raw'.trim();
      if (s.isEmpty) {
        await (db.delete(db.configKeyValues)
              ..where((t) => t.key.equals(kDisplayTimezoneKvKey)))
            .go();
      } else {
        await db.into(db.configKeyValues).insertOnConflictUpdate(
              ConfigKeyValuesCompanion.insert(
                key: kDisplayTimezoneKvKey,
                value: s,
              ),
            );
      }
      touched = true;
    }
    if (body.containsKey('adoption_allowed_roles')) {
      final raw = body['adoption_allowed_roles'];
      final roles = <String>{};
      if (raw is List) {
        for (final item in raw) {
          if (item is String) {
            final role = item.trim();
            if (isValidUserRole(role)) {
              roles.add(role);
            }
          }
        }
      }
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kAdoptionAllowedRolesKvKey,
              value: encodeAdoptionAllowedRoles(roles),
            ),
          );
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kAdoptionAllowNewRequestsKvKey,
              value: roles.isEmpty ? 'false' : 'true',
            ),
          );
      touched = true;
    } else if (body.containsKey('adoption_allow_new_requests')) {
      final raw = body['adoption_allow_new_requests'];
      final flag = raw is bool ? raw : raw?.toString().toLowerCase() == 'true';
      final roles = flag ? Set<String>.from(kValidUserRoles) : <String>{};
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kAdoptionAllowedRolesKvKey,
              value: encodeAdoptionAllowedRoles(roles),
            ),
          );
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kAdoptionAllowNewRequestsKvKey,
              value: flag ? 'true' : 'false',
            ),
          );
      touched = true;
    }
    if (!touched) {
      return Response(400,
          body: '{"error":"no_curator_settings_fields"}',
          headers: {'content-type': 'application/json'});
    }
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.get('/v1/config/key-values', (Request req) async {
    final rows = await (db.select(db.configKeyValues)
          ..orderBy([(t) => OrderingTerm.asc(t.key)]))
        .get();
    return Response.ok(
      jsonEncode({
        'items': [
          for (final r in rows) {'key': r.key, 'value': r.value},
        ],
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.put('/v1/config/key-values', (Request req) async {
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
    final key = '${body['key'] ?? ''}'.trim();
    if (key.isEmpty) {
      return Response(400,
          body: '{"error":"key_required"}',
          headers: {'content-type': 'application/json'});
    }
    if (key.length > 512) {
      return Response(400,
          body: '{"error":"key_too_long"}',
          headers: {'content-type': 'application/json'});
    }
    final rawVal = body['value'];
    final value = rawVal == null ? '' : '$rawVal';
    if (value.length > 262144) {
      return Response(400,
          body: '{"error":"value_too_long"}',
          headers: {'content-type': 'application/json'});
    }
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: key,
            value: value,
          ),
        );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.delete('/v1/config/key-values', (Request req) async {
    final key = req.url.queryParameters['key']?.trim() ?? '';
    if (key.isEmpty) {
      return Response(400,
          body: '{"error":"key_required"}',
          headers: {'content-type': 'application/json'});
    }
    final n =
        await (db.delete(db.configKeyValues)..where((t) => t.key.equals(key)))
            .go();
    if (n == 0) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.patch('/v1/integrations/<id>', (Request req, String id) async {
    final existing = await (db.select(db.integrations)
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
    if (enabled) {
      if (integrationSecretSlotsForType(existing.integrationType).isNotEmpty &&
          !await isIntegrationSecretsFullyConfigured(
            secrets,
            id,
            integrationType: existing.integrationType,
          )) {
        return Response(
          400,
          body: '{"error":"secrets_required_before_enable"}',
          headers: {'content-type': 'application/json'},
        );
      }
      if (!await integrationAccountsSatisfiedForEnable(
        secrets,
        db,
        id,
        existing.integrationType,
      )) {
        return Response(
          400,
          body: '{"error":"accounts_required_before_enable"}',
          headers: {'content-type': 'application/json'},
        );
      }
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
    await (db.update(db.integrations)..where((t) => t.id.equals(id))).write(
      IntegrationsCompanion(
        enabled: Value(enabled),
        pollSeconds: Value(poll),
        baseUrl: Value(baseUrl),
        configJson: Value(configJson),
      ),
    );
    await syncIntegrationAccountLinks(db);
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
    final dup = await (db.select(db.screens)
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
    final minDwell = (map['min_dwell_seconds'] as num?)?.toInt() ?? 8;
    final maxDwell = (map['max_dwell_seconds'] as num?)?.toInt() ?? 15;
    if (minDwell <= 0 || maxDwell <= 0 || minDwell > maxDwell) {
      return Response(400,
          body: '{"error":"invalid_dwell_seconds"}',
          headers: {'content-type': 'application/json'});
    }
    final frequencyWeight = (map['frequency_weight'] as num?)?.toInt() ?? 100;
    final minGap = (map['min_gap_between_shows_seconds'] as num?)?.toInt() ?? 0;
    final minPlacements =
        (map['min_placements_per_program'] as num?)?.toInt() ?? 0;
    final maxPlacements = (map['max_placements_per_program'] as num?)?.toInt();
    final dataKey = (map['data_key'] as String?)?.trim() ?? '';
    final resolvedName = (name == null || name.isEmpty) ? id : name;
    await db.into(db.screens).insert(
          ScreensCompanion.insert(
            id: id,
            name: resolvedName,
            description: Value(description),
            screenType: screenType,
            configJson: Value(configJsonStr),
            configJsonSchema: Value(doc.schema),
            exampleConfigJson: Value(doc.example),
            minDwellSeconds: Value(minDwell),
            maxDwellSeconds: Value(maxDwell),
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
    final existing = await (db.select(db.screens)
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
    var minDwell = existing.minDwellSeconds;
    var maxDwell = existing.maxDwellSeconds;
    if (map.containsKey('min_dwell_seconds')) {
      minDwell = (map['min_dwell_seconds'] as num?)?.toInt() ?? minDwell;
    }
    if (map.containsKey('max_dwell_seconds')) {
      maxDwell = (map['max_dwell_seconds'] as num?)?.toInt() ?? maxDwell;
    }
    if (minDwell <= 0 || maxDwell <= 0 || minDwell > maxDwell) {
      return Response(400,
          body: '{"error":"invalid_dwell_seconds"}',
          headers: {'content-type': 'application/json'});
    }
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
    await (db.update(db.screens)..where((t) => t.id.equals(id))).write(
      ScreensCompanion(
        name: Value(name),
        description: Value(description),
        screenType: Value(screenType),
        configJson: Value(resolvedConfigJson),
        configJsonSchema: Value(doc.schema),
        exampleConfigJson: Value(doc.example),
        minDwellSeconds: Value(minDwell),
        maxDwellSeconds: Value(maxDwell),
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
    final n = await (db.delete(db.screens)
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

  registerCuratorConfigurationRoutes(
    r,
    db: db,
    onConfigChanged: onConfigChanged,
  );
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
