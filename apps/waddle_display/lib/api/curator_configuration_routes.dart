import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/curation/curator_member_op.dart';
import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/curation/curator_state_predicates.dart';
import 'package:waddle_shared/display/display_ticker_settings.dart';
import 'package:waddle_shared/display/display_viewport_reserve.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../curator/active_curator_service.dart';
import '../curator/curator_runtime_state_builder.dart';

void registerCuratorConfigurationRoutes(
  Router r, {
  required AppDatabase db,
  required Future<void> Function() onConfigChanged,
  ActiveCuratorService? activeCuratorService,
}) {
  final curator = activeCuratorService ?? ActiveCuratorService(db: db);
  final runtimeBuilder = CuratorRuntimeStateBuilder(db: db);

  r.get('/v1/meta/curator-state-predicates', (Request req) async {
    return Response.ok(
      jsonEncode({
        'items': [
          for (final e in kCuratorStatePredicateCatalog)
            {
              'id': e.id,
              'label': e.label,
              'description': e.description,
              'implemented': e.implemented,
            },
        ],
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/curator/runtime-state', (Request req) async {
    final state = await runtimeBuilder.build();
    return Response.ok(
      jsonEncode({
        'display_adopted': state.displayAdopted,
        'internet_reachable': state.internetReachable,
        'display_server_reachable': state.displayServerReachable,
        'motion_detected': state.motionDetected,
        'beacon_detected': state.beaconDetected,
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/curator/active', (Request req) async {
    final selection = await curator.resolveAt(DateTime.now());
    return Response.ok(
      jsonEncode({
        'exclusive': _activeMatchJson(selection.exclusive),
        'base': _activeMatchJson(selection.base),
        'enhancements': [
          for (final e in selection.enhancements) _activeMatchJson(e)!,
        ],
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/curator/configurations', (Request req) async {
    final rows = await (db.select(db.curatorConfigurations)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return Response.ok(
      jsonEncode({
        'items': [for (final c in rows) _configurationSummaryJson(c)],
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  r.get('/v1/curator/configurations/<id>', (Request req, String id) async {
    final detail = await _loadConfigurationDetail(db, id);
    if (detail == null) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    return Response.ok(
      jsonEncode(detail),
      headers: {'content-type': 'application/json'},
    );
  });

  r.post('/v1/curator/configurations', (Request req) async {
    final map = await _readJsonObject(req);
    if (map == null) {
      return Response(400,
          body: '{"error":"expected_json_object"}',
          headers: {'content-type': 'application/json'});
    }
    final id = '${map['id'] ?? ''}'.trim();
    final name = '${map['name'] ?? ''}'.trim();
    final layer = '${map['layer'] ?? ''}'.trim();
    if (id.isEmpty || name.isEmpty || layer.isEmpty) {
      return Response(400,
          body: '{"error":"id_name_and_layer_required"}',
          headers: {'content-type': 'application/json'});
    }
    if (!kCuratorConfigurationLayers.contains(layer)) {
      return Response(400,
          body: '{"error":"invalid_layer"}',
          headers: {'content-type': 'application/json'});
    }
    final dup = await (db.select(db.curatorConfigurations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (dup != null) {
      return Response(409,
          body: '{"error":"id_already_exists"}',
          headers: {'content-type': 'application/json'});
    }
    final parentId = _readOptionalTrimmedString(map['parent_configuration_id']);
    final parentError = await _validateParentConfigurationWrite(
      db,
      childId: id,
      layer: layer,
      parentId: parentId,
    );
    if (parentError != null) {
      return Response(400,
          body: jsonEncode({'error': parentError}),
          headers: {'content-type': 'application/json'});
    }
    await db.into(db.curatorConfigurations).insert(
          CuratorConfigurationsCompanion.insert(
            id: id,
            name: name,
            layer: layer,
            sortOrder: Value(
              _readInt(map['sort_order']) ?? kDefaultCuratorConfigurationSortOrder,
            ),
            programDurationSeconds:
                Value(_readInt(map['program_duration_seconds']) ?? 180),
            requireNewsPhotoForScreens: Value(
              _readBool(map['require_news_photo_for_screens'], defaultValue: true),
            ),
            screensEnabled: Value(
              _screensEnabledForWrite(
                layer,
                map['screens_enabled'],
                defaultValue: true,
              ),
            ),
            tickerEnabled: Value(
              _tickerEnabledForWrite(
                layer,
                map['ticker_enabled'],
                defaultValue: true,
              ),
            ),
            tickerProgramDurationSeconds: Value(
              _tickerProgramDurationOverrideForWrite(
                layer,
                map['ticker_program_duration_seconds'],
              ),
            ),
            tickerPixelsPerSecond: Value(
              _tickerPixelsPerSecondOverrideForWrite(
                layer,
                map['ticker_pixels_per_second'],
              ),
            ),
            themeIdOverride: Value(
              _themeIdOverrideForWrite(layer, map['theme_id_override']),
            ),
            viewportReserveTopPctOverride: Value(
              _viewportReserveOverrideForWrite(
                layer,
                map['viewport_reserve_top_pct_override'],
              ),
            ),
            viewportReserveRightPctOverride: Value(
              _viewportReserveOverrideForWrite(
                layer,
                map['viewport_reserve_right_pct_override'],
              ),
            ),
            viewportReserveBottomPctOverride: Value(
              _viewportReserveOverrideForWrite(
                layer,
                map['viewport_reserve_bottom_pct_override'],
              ),
            ),
            viewportReserveLeftPctOverride: Value(
              _viewportReserveOverrideForWrite(
                layer,
                map['viewport_reserve_left_pct_override'],
              ),
            ),
            defaultConfig: Value(_readBool(map['default_config'], defaultValue: false)),
            parentConfigurationId: Value(parentId),
          ),
        );
    try {
      if (map['rules'] is List) {
        await _replaceRules(db, configurationId: id, rules: map['rules'] as List);
      }
      if (map['members'] is Map) {
        await _replaceMembers(
          db,
          configurationId: id,
          members: Map<String, dynamic>.from(map['members'] as Map),
        );
      }
    } on FormatException catch (e) {
      await _deleteConfiguration(db, id);
      return Response(400,
          body: jsonEncode({'error': e.message}),
          headers: {'content-type': 'application/json'});
    }
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.patch('/v1/curator/configurations/<id>', (Request req, String id) async {
    final existing = await (db.select(db.curatorConfigurations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    final map = await _readJsonObject(req);
    if (map == null) {
      return Response(400,
          body: '{"error":"expected_json_object"}',
          headers: {'content-type': 'application/json'});
    }
    final layer = map.containsKey('layer')
        ? '${map['layer']}'.trim()
        : existing.layer;
    if (!kCuratorConfigurationLayers.contains(layer)) {
      return Response(400,
          body: '{"error":"invalid_layer"}',
          headers: {'content-type': 'application/json'});
    }
    if (map.containsKey('parent_configuration_id')) {
      final parentId = _readOptionalTrimmedString(map['parent_configuration_id']);
      final parentError = await _validateParentConfigurationWrite(
        db,
        childId: id,
        layer: layer,
        parentId: parentId,
      );
      if (parentError != null) {
        return Response(400,
            body: jsonEncode({'error': parentError}),
            headers: {'content-type': 'application/json'});
      }
    }
    await (db.update(db.curatorConfigurations)..where((t) => t.id.equals(id))).write(
      CuratorConfigurationsCompanion(
        name: map.containsKey('name')
            ? Value('${map['name']}'.trim())
            : const Value.absent(),
        layer: Value(layer),
        sortOrder: map.containsKey('sort_order')
            ? Value(_readInt(map['sort_order']) ?? existing.sortOrder)
            : const Value.absent(),
        programDurationSeconds: map.containsKey('program_duration_seconds')
            ? Value(
                _readInt(map['program_duration_seconds']) ??
                    existing.programDurationSeconds,
              )
            : const Value.absent(),
        requireNewsPhotoForScreens: map.containsKey('require_news_photo_for_screens')
            ? Value(
                _readBool(
                  map['require_news_photo_for_screens'],
                  defaultValue: existing.requireNewsPhotoForScreens,
                ),
              )
            : const Value.absent(),
        screensEnabled: _isEnhancementLayer(layer)
            ? const Value(true)
            : map.containsKey('screens_enabled')
                ? Value(
                    _readBool(
                      map['screens_enabled'],
                      defaultValue: existing.screensEnabled,
                    ),
                  )
                : const Value.absent(),
        tickerEnabled: _isEnhancementLayer(layer)
            ? const Value(true)
            : map.containsKey('ticker_enabled')
                ? Value(
                    _readBool(
                      map['ticker_enabled'],
                      defaultValue: existing.tickerEnabled,
                    ),
                  )
                : const Value.absent(),
        tickerProgramDurationSeconds:
            _tickerProgramDurationOverrideCompanionForPatch(
          layer: layer,
          map: map,
          key: 'ticker_program_duration_seconds',
        ),
        tickerPixelsPerSecond: _tickerPixelsPerSecondOverrideCompanionForPatch(
          layer: layer,
          map: map,
          key: 'ticker_pixels_per_second',
        ),
        themeIdOverride: _isEnhancementLayer(layer)
            ? const Value(null)
            : map.containsKey('theme_id_override')
                ? Value(_readOptionalTrimmedString(map['theme_id_override']))
                : const Value.absent(),
        viewportReserveTopPctOverride: _viewportReserveOverrideCompanionForPatch(
          layer: layer,
          map: map,
          key: 'viewport_reserve_top_pct_override',
        ),
        viewportReserveRightPctOverride:
            _viewportReserveOverrideCompanionForPatch(
          layer: layer,
          map: map,
          key: 'viewport_reserve_right_pct_override',
        ),
        viewportReserveBottomPctOverride:
            _viewportReserveOverrideCompanionForPatch(
          layer: layer,
          map: map,
          key: 'viewport_reserve_bottom_pct_override',
        ),
        viewportReserveLeftPctOverride: _viewportReserveOverrideCompanionForPatch(
          layer: layer,
          map: map,
          key: 'viewport_reserve_left_pct_override',
        ),
        defaultConfig: map.containsKey('default_config')
            ? Value(_readBool(map['default_config'], defaultValue: existing.defaultConfig))
            : const Value.absent(),
        parentConfigurationId: map.containsKey('parent_configuration_id')
            ? Value(_readOptionalTrimmedString(map['parent_configuration_id']))
            : const Value.absent(),
      ),
    );
    try {
      if (map['rules'] is List) {
        await _replaceRules(db, configurationId: id, rules: map['rules'] as List);
      }
      if (map['members'] is Map) {
        await _replaceMembers(
          db,
          configurationId: id,
          members: Map<String, dynamic>.from(map['members'] as Map),
        );
      }
    } on FormatException catch (e) {
      return Response(400,
          body: jsonEncode({'error': e.message}),
          headers: {'content-type': 'application/json'});
    }
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.delete('/v1/curator/configurations/<id>', (Request req, String id) async {
    final existing = await (db.select(db.curatorConfigurations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    await _deleteConfiguration(db, id);
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.post('/v1/curator/configurations/<configId>/rules', (Request req, String configId) async {
    if (!await _configurationExists(db, configId)) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    final map = await _readJsonObject(req);
    if (map == null) {
      return Response(400,
          body: '{"error":"expected_json_object"}',
          headers: {'content-type': 'application/json'});
    }
    final ruleId = '${map['id'] ?? ''}'.trim();
    if (ruleId.isEmpty) {
      return Response(400,
          body: '{"error":"id_required"}',
          headers: {'content-type': 'application/json'});
    }
    final dup = await (db.select(db.curatorScheduleRules)
          ..where((t) => t.id.equals(ruleId)))
        .getSingleOrNull();
    if (dup != null) {
      return Response(409,
          body: '{"error":"rule_id_exists"}',
          headers: {'content-type': 'application/json'});
    }
    final pred = _readOptionalTrimmedString(map['state_predicate']);
    if (!isKnownCuratorStatePredicate(pred)) {
      return Response(400,
          body: '{"error":"invalid_state_predicate"}',
          headers: {'content-type': 'application/json'});
    }
    await db.into(db.curatorScheduleRules).insert(
          _ruleCompanionFromMap(
            map,
            id: ruleId,
            configurationId: configId,
          ),
        );
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });

  r.patch(
    '/v1/curator/configurations/<configId>/rules/<ruleId>',
    (Request req, String configId, String ruleId) async {
      final existing = await (db.select(db.curatorScheduleRules)
            ..where((t) => t.id.equals(ruleId)))
          .getSingleOrNull();
      if (existing == null || existing.configurationId != configId) {
        return Response(404,
            body: '{"error":"not_found"}',
            headers: {'content-type': 'application/json'});
      }
      final map = await _readJsonObject(req);
      if (map == null) {
        return Response(400,
            body: '{"error":"expected_json_object"}',
            headers: {'content-type': 'application/json'});
      }
      String? pred = existing.statePredicate;
      if (map.containsKey('state_predicate')) {
        pred = _readOptionalTrimmedString(map['state_predicate']);
        if (!isKnownCuratorStatePredicate(pred)) {
          return Response(400,
              body: '{"error":"invalid_state_predicate"}',
              headers: {'content-type': 'application/json'});
        }
      }
      await (db.update(db.curatorScheduleRules)..where((t) => t.id.equals(ruleId))).write(
        CuratorScheduleRulesCompanion(
          priority: map.containsKey('priority')
              ? Value(_readInt(map['priority']) ?? existing.priority)
              : const Value.absent(),
          statePredicate: map.containsKey('state_predicate')
              ? Value(pred)
              : const Value.absent(),
          daysOfWeekMask: map.containsKey('days_of_week_mask')
              ? Value(_readNullableInt(map['days_of_week_mask']))
              : const Value.absent(),
          startTimeMinutes: map.containsKey('start_time_minutes')
              ? Value(_readNullableInt(map['start_time_minutes']))
              : const Value.absent(),
          endTimeMinutes: map.containsKey('end_time_minutes')
              ? Value(_readNullableInt(map['end_time_minutes']))
              : const Value.absent(),
          startMonth: map.containsKey('start_month')
              ? Value(_readNullableInt(map['start_month']))
              : const Value.absent(),
          startDay: map.containsKey('start_day')
              ? Value(_readNullableInt(map['start_day']))
              : const Value.absent(),
          endMonth: map.containsKey('end_month')
              ? Value(_readNullableInt(map['end_month']))
              : const Value.absent(),
          endDay: map.containsKey('end_day')
              ? Value(_readNullableInt(map['end_day']))
              : const Value.absent(),
          repeatAnnually: map.containsKey('repeat_annually')
              ? Value(_readBool(map['repeat_annually'], defaultValue: existing.repeatAnnually))
              : const Value.absent(),
          yearExact: map.containsKey('year_exact')
              ? Value(_readNullableInt(map['year_exact']))
              : const Value.absent(),
          nthWeekOfMonth: map.containsKey('nth_week_of_month')
              ? Value(_readNullableInt(map['nth_week_of_month']))
              : const Value.absent(),
          nthWeekday: map.containsKey('nth_weekday')
              ? Value(_readNullableInt(map['nth_weekday']))
              : const Value.absent(),
        ),
      );
      await onConfigChanged();
      return Response.ok('{}', headers: {'content-type': 'application/json'});
    },
  );

  r.delete(
    '/v1/curator/configurations/<configId>/rules/<ruleId>',
    (Request req, String configId, String ruleId) async {
      final existing = await (db.select(db.curatorScheduleRules)
            ..where((t) => t.id.equals(ruleId)))
          .getSingleOrNull();
      if (existing == null || existing.configurationId != configId) {
        return Response(404,
            body: '{"error":"not_found"}',
            headers: {'content-type': 'application/json'});
      }
      await (db.delete(db.curatorScheduleRules)..where((t) => t.id.equals(ruleId))).go();
      await onConfigChanged();
      return Response.ok('{}', headers: {'content-type': 'application/json'});
    },
  );

  r.put('/v1/curator/configurations/<configId>/members', (Request req, String configId) async {
    if (!await _configurationExists(db, configId)) {
      return Response(404,
          body: '{"error":"not_found"}',
          headers: {'content-type': 'application/json'});
    }
    final map = await _readJsonObject(req);
    if (map == null) {
      return Response(400,
          body: '{"error":"expected_json_object"}',
          headers: {'content-type': 'application/json'});
    }
    await _replaceMembers(db, configurationId: configId, members: map);
    await onConfigChanged();
    return Response.ok('{}', headers: {'content-type': 'application/json'});
  });
}

Map<String, Object?>? _activeMatchJson(ResolvedCuratorConfiguration? resolved) {
  if (resolved == null) {
    return null;
  }
  final c = resolved.configuration;
  return {
    'configuration_id': c.id,
    'configuration_name': c.name,
    'layer': c.layer,
    'matched_rule_id': resolved.matchedRuleId,
    'match_reason': resolved.matchReason,
  };
}

Map<String, Object?> _configurationSummaryJson(CuratorConfiguration c) {
  return {
    'id': c.id,
    'name': c.name,
    'layer': c.layer,
    'sort_order': c.sortOrder,
    'program_duration_seconds': c.programDurationSeconds,
    'require_news_photo_for_screens': c.requireNewsPhotoForScreens,
    'screens_enabled': c.screensEnabled,
    'ticker_enabled': c.tickerEnabled,
    'ticker_program_duration_seconds': c.tickerProgramDurationSeconds,
    'ticker_pixels_per_second': c.tickerPixelsPerSecond,
    'theme_id_override': c.themeIdOverride,
    'viewport_reserve_top_pct_override': c.viewportReserveTopPctOverride,
    'viewport_reserve_right_pct_override': c.viewportReserveRightPctOverride,
    'viewport_reserve_bottom_pct_override': c.viewportReserveBottomPctOverride,
    'viewport_reserve_left_pct_override': c.viewportReserveLeftPctOverride,
    'default_config': c.defaultConfig,
    'parent_configuration_id': c.parentConfigurationId,
  };
}

Future<String?> _validateParentConfigurationWrite(
  AppDatabase db, {
  required String childId,
  required String layer,
  String? parentId,
}) async {
  if (parentId == null) {
    return null;
  }
  if (parentId == childId) {
    return 'invalid_parent_configuration';
  }
  if (layer != kCuratorLayerBase) {
    return 'parent_only_for_base_layer';
  }
  final parent = await (db.select(db.curatorConfigurations)
        ..where((t) => t.id.equals(parentId)))
      .getSingleOrNull();
  if (parent == null) {
    return 'parent_not_found';
  }
  if (parent.layer != kCuratorLayerBase) {
    return 'parent_must_be_base_layer';
  }
  final grandparent = parent.parentConfigurationId?.trim();
  if (grandparent != null && grandparent.isNotEmpty) {
    return 'parent_cannot_extend_parent';
  }
  return null;
}

Future<Map<String, Object?>?> _loadConfigurationDetail(
  AppDatabase db,
  String id,
) async {
  final config = await (db.select(db.curatorConfigurations)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  if (config == null) {
    return null;
  }
  final rules = await (db.select(db.curatorScheduleRules)
        ..where((t) => t.configurationId.equals(id))
        ..orderBy([
          (t) => OrderingTerm.desc(t.priority),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .get();
  final members = await (db.select(db.curatorConfigurationMembers)
        ..where((t) => t.configurationId.equals(id))
        ..orderBy([
          (t) => OrderingTerm.asc(t.entityType),
          (t) => OrderingTerm.asc(t.entityId),
        ]))
      .get();
  return {
    ..._configurationSummaryJson(config),
    'rules': [for (final r in rules) _ruleJson(r)],
    'members': {
      'screens': _memberOpsJson(members, kCuratorMemberEntityScreen),
      'tickers': _memberOpsJson(members, kCuratorMemberEntityTicker),
      'overlays': _memberOpsJson(members, kCuratorMemberEntityOverlay),
    },
  };
}

List<Map<String, Object?>> _memberOpsJson(
  List<CuratorConfigurationMember> members,
  String entityType,
) {
  return [
    for (final m in members.where((t) => t.entityType == entityType))
      <String, Object?>{
        'id': m.entityId,
        'op': normalizeCuratorMemberOp(m.op),
      },
  ];
}

Map<String, Object?> _ruleJson(CuratorScheduleRule r) {
  return {
    'id': r.id,
    'configuration_id': r.configurationId,
    'priority': r.priority,
    'state_predicate': r.statePredicate,
    'days_of_week_mask': r.daysOfWeekMask,
    'start_time_minutes': r.startTimeMinutes,
    'end_time_minutes': r.endTimeMinutes,
    'start_month': r.startMonth,
    'start_day': r.startDay,
    'end_month': r.endMonth,
    'end_day': r.endDay,
    'repeat_annually': r.repeatAnnually,
    'year_exact': r.yearExact,
    'nth_week_of_month': r.nthWeekOfMonth,
    'nth_weekday': r.nthWeekday,
  };
}

Future<bool> _configurationExists(AppDatabase db, String id) async {
  final row = await (db.select(db.curatorConfigurations)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  return row != null;
}

Future<void> _deleteConfiguration(AppDatabase db, String id) async {
  await (db.delete(db.curatorConfigurationMembers)
        ..where((t) => t.configurationId.equals(id)))
      .go();
  await (db.delete(db.curatorScheduleRules)
        ..where((t) => t.configurationId.equals(id)))
      .go();
  await (db.delete(db.curatorConfigurations)..where((t) => t.id.equals(id))).go();
}

Future<void> _replaceRules(
  AppDatabase db, {
  required String configurationId,
  required List<dynamic> rules,
}) async {
  await (db.delete(db.curatorScheduleRules)
        ..where((t) => t.configurationId.equals(configurationId)))
      .go();
  for (final raw in rules) {
    if (raw is! Map) {
      throw const FormatException('invalid_rule');
    }
    final map = Map<String, dynamic>.from(raw);
    final id = '${map['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      throw const FormatException('rule_id_required');
    }
    final pred = _readOptionalTrimmedString(map['state_predicate']);
    if (!isKnownCuratorStatePredicate(pred)) {
      throw const FormatException('invalid_state_predicate');
    }
    await db.into(db.curatorScheduleRules).insert(
          _ruleCompanionFromMap(map, id: id, configurationId: configurationId),
        );
  }
}

CuratorScheduleRulesCompanion _ruleCompanionFromMap(
  Map<String, dynamic> map, {
  required String id,
  required String configurationId,
}) {
  return CuratorScheduleRulesCompanion.insert(
    id: id,
    configurationId: configurationId,
    priority: Value(_readInt(map['priority']) ?? 0),
    statePredicate: Value(_readOptionalTrimmedString(map['state_predicate'])),
    daysOfWeekMask: Value(_readNullableInt(map['days_of_week_mask'])),
    startTimeMinutes: Value(_readNullableInt(map['start_time_minutes'])),
    endTimeMinutes: Value(_readNullableInt(map['end_time_minutes'])),
    startMonth: Value(_readNullableInt(map['start_month'])),
    startDay: Value(_readNullableInt(map['start_day'])),
    endMonth: Value(_readNullableInt(map['end_month'])),
    endDay: Value(_readNullableInt(map['end_day'])),
    repeatAnnually: Value(_readBool(map['repeat_annually'], defaultValue: true)),
    yearExact: Value(_readNullableInt(map['year_exact'])),
    nthWeekOfMonth: Value(_readNullableInt(map['nth_week_of_month'])),
    nthWeekday: Value(_readNullableInt(map['nth_weekday'])),
  );
}

Future<void> _replaceMembers(
  AppDatabase db, {
  required String configurationId,
  required Map<String, dynamic> members,
}) async {
  await (db.delete(db.curatorConfigurationMembers)
        ..where((t) => t.configurationId.equals(configurationId)))
      .go();
  Future<void> insertList(String entityType, dynamic raw) async {
    if (raw == null) {
      return;
    }
    if (raw is! List) {
      throw const FormatException('invalid_members');
    }
    for (final item in raw) {
      if (!kCuratorMemberEntityTypes.contains(entityType)) {
        throw const FormatException('invalid_entity_type');
      }
      late final String entityId;
      late final String op;
      if (item is String) {
        entityId = item.trim();
        op = kCuratorMemberOpAdd;
      } else if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        entityId = '${map['id'] ?? ''}'.trim();
        op = normalizeCuratorMemberOp(map['op'] as String?);
      } else {
        throw const FormatException('invalid_members');
      }
      if (entityId.isEmpty) {
        continue;
      }
      if (!isValidCuratorMemberOp(op)) {
        throw const FormatException('invalid_member_op');
      }
      await db.into(db.curatorConfigurationMembers).insert(
            CuratorConfigurationMembersCompanion.insert(
              configurationId: configurationId,
              entityType: entityType,
              entityId: entityId,
              op: Value(op),
            ),
          );
    }
  }

  await insertList(kCuratorMemberEntityScreen, members['screens']);
  await insertList(kCuratorMemberEntityTicker, members['tickers']);
  await insertList(kCuratorMemberEntityOverlay, members['overlays']);
}

Future<Map<String, dynamic>?> _readJsonObject(Request req) async {
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  } catch (_) {
    return null;
  }
}

int? _readInt(dynamic v) {
  if (v == null) {
    return null;
  }
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  return int.tryParse('$v');
}

int? _readNullableInt(dynamic v) {
  if (v == null) {
    return null;
  }
  return _readInt(v);
}

bool _readBool(dynamic v, {required bool defaultValue}) {
  if (v == null) {
    return defaultValue;
  }
  if (v is bool) {
    return v;
  }
  final s = '$v'.trim().toLowerCase();
  if (s == 'true' || s == '1') {
    return true;
  }
  if (s == 'false' || s == '0') {
    return false;
  }
  return defaultValue;
}

String? _readOptionalTrimmedString(dynamic v) {
  if (v == null) {
    return null;
  }
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

bool _isEnhancementLayer(String layer) => layer == kCuratorLayerEnhancement;

String? _themeIdOverrideForWrite(String layer, dynamic mapValue) {
  if (_isEnhancementLayer(layer)) {
    return null;
  }
  return _readOptionalTrimmedString(mapValue);
}

int? _viewportReserveOverrideForWrite(String layer, dynamic mapValue) {
  if (_isEnhancementLayer(layer)) {
    return null;
  }
  return normalizeViewportReservePctOverride(mapValue);
}

Value<int?> _viewportReserveOverrideCompanionForPatch({
  required String layer,
  required Map<String, dynamic> map,
  required String key,
}) {
  if (_isEnhancementLayer(layer)) {
    return const Value(null);
  }
  if (!map.containsKey(key)) {
    return const Value.absent();
  }
  return Value(normalizeViewportReservePctOverride(map[key]));
}

bool _screensEnabledForWrite(
  String layer,
  dynamic mapValue, {
  required bool defaultValue,
  bool? existing,
}) {
  if (_isEnhancementLayer(layer)) {
    return true;
  }
  if (mapValue != null) {
    return _readBool(mapValue, defaultValue: defaultValue);
  }
  return existing ?? defaultValue;
}

bool _tickerEnabledForWrite(
  String layer,
  dynamic mapValue, {
  required bool defaultValue,
  bool? existing,
}) {
  if (_isEnhancementLayer(layer)) {
    return true;
  }
  if (mapValue != null) {
    return _readBool(mapValue, defaultValue: defaultValue);
  }
  return existing ?? defaultValue;
}

int? _tickerProgramDurationOverrideForWrite(String layer, dynamic mapValue) {
  if (_isEnhancementLayer(layer)) {
    return null;
  }
  return _readTickerProgramDurationSecondsOverride(mapValue);
}

int? _tickerPixelsPerSecondOverrideForWrite(String layer, dynamic mapValue) {
  if (_isEnhancementLayer(layer)) {
    return null;
  }
  return _readTickerPixelsPerSecondOverride(mapValue);
}

int? _readTickerProgramDurationSecondsOverride(dynamic v) {
  if (v == null) {
    return null;
  }
  final parsed = _readInt(v);
  if (parsed == null) {
    return null;
  }
  return parsed.clamp(
    kDisplayTickerProgramDurationSecondsMin,
    kDisplayTickerProgramDurationSecondsMax,
  );
}

int? _readTickerPixelsPerSecondOverride(dynamic v) {
  if (v == null) {
    return null;
  }
  final parsed = _readInt(v);
  if (parsed == null) {
    return null;
  }
  return parsed.clamp(
    kDisplayTickerPixelsPerSecondMin,
    kDisplayTickerPixelsPerSecondMax,
  );
}

Value<int?> _tickerProgramDurationOverrideCompanionForPatch({
  required String layer,
  required Map<String, dynamic> map,
  required String key,
}) {
  if (_isEnhancementLayer(layer)) {
    return const Value(null);
  }
  if (!map.containsKey(key)) {
    return const Value.absent();
  }
  return Value(_readTickerProgramDurationSecondsOverride(map[key]));
}

Value<int?> _tickerPixelsPerSecondOverrideCompanionForPatch({
  required String layer,
  required Map<String, dynamic> map,
  required String key,
}) {
  if (_isEnhancementLayer(layer)) {
    return const Value(null);
  }
  if (!map.containsKey(key)) {
    return const Value.absent();
  }
  return Value(_readTickerPixelsPerSecondOverride(map[key]));
}
