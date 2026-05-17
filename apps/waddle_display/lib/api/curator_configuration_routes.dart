import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/curation/curator_state_predicates.dart';
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
    await db.into(db.curatorConfigurations).insert(
          CuratorConfigurationsCompanion.insert(
            id: id,
            name: name,
            layer: layer,
            sortOrder: Value(_readInt(map['sort_order']) ?? 0),
            programDurationSeconds:
                Value(_readInt(map['program_duration_seconds']) ?? 180),
            historyDepth: Value(_readInt(map['history_depth']) ?? 5),
            requireNewsPhotoForScreens: Value(
              _readBool(map['require_news_photo_for_screens'], defaultValue: true),
            ),
            themeIdOverride: Value(_readOptionalTrimmedString(map['theme_id_override'])),
            defaultConfig: Value(_readBool(map['default_config'], defaultValue: false)),
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
        historyDepth: map.containsKey('history_depth')
            ? Value(_readInt(map['history_depth']) ?? existing.historyDepth)
            : const Value.absent(),
        requireNewsPhotoForScreens: map.containsKey('require_news_photo_for_screens')
            ? Value(
                _readBool(
                  map['require_news_photo_for_screens'],
                  defaultValue: existing.requireNewsPhotoForScreens,
                ),
              )
            : const Value.absent(),
        themeIdOverride: map.containsKey('theme_id_override')
            ? Value(_readOptionalTrimmedString(map['theme_id_override']))
            : const Value.absent(),
        defaultConfig: map.containsKey('default_config')
            ? Value(_readBool(map['default_config'], defaultValue: existing.defaultConfig))
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
    'history_depth': c.historyDepth,
    'require_news_photo_for_screens': c.requireNewsPhotoForScreens,
    'theme_id_override': c.themeIdOverride,
    'default_config': c.defaultConfig,
  };
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
  final screens = <String>[];
  final tickers = <String>[];
  final overlays = <String>[];
  for (final m in members) {
    switch (m.entityType) {
      case kCuratorMemberEntityScreen:
        screens.add(m.entityId);
      case kCuratorMemberEntityTicker:
        tickers.add(m.entityId);
      case kCuratorMemberEntityOverlay:
        overlays.add(m.entityId);
    }
  }
  return {
    ..._configurationSummaryJson(config),
    'rules': [for (final r in rules) _ruleJson(r)],
    'members': {
      'screens': screens,
      'tickers': tickers,
      'overlays': overlays,
    },
  };
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
      final entityId = '$item'.trim();
      if (entityId.isEmpty) {
        continue;
      }
      if (!kCuratorMemberEntityTypes.contains(entityType)) {
        throw const FormatException('invalid_entity_type');
      }
      await db.into(db.curatorConfigurationMembers).insert(
            CuratorConfigurationMembersCompanion.insert(
              configurationId: configurationId,
              entityType: entityType,
              entityId: entityId,
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
