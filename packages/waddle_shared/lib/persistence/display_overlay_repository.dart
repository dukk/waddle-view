import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'config_json_documentation.dart';
import 'database.dart';
import 'display_overlay_bouncing_message_settings.dart';
import 'display_overlay_confetti_settings.dart';
import 'display_overlay_falling_images_settings.dart';
import 'display_overlay_row.dart';
import 'display_overlay_sql.dart';
import 'overlay_id_allocation.dart';
import 'tables.dart';

Selectable<DisplayOverlayRow> _overlaySelectable(AppDatabase db) {
  return db.customSelect(
    'SELECT * FROM overlays ORDER BY id ASC',
  ).map(DisplayOverlayRow.fromQueryRow);
}

Future<List<DisplayOverlayRow>> fetchDisplayOverlays(AppDatabase db) =>
    _overlaySelectable(db).get();

/// Back-compat alias for display runtime polling.
Future<List<DisplayOverlayRow>> fetchDisplayOverlaySchedules(AppDatabase db) =>
    fetchDisplayOverlays(db);

/// Periodically polls the table so REST changes appear without restarting the UI isolate.
Stream<List<DisplayOverlayRow>> watchDisplayOverlaySchedules(
  AppDatabase db,
) async* {
  yield await fetchDisplayOverlays(db);
  await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
    yield await fetchDisplayOverlays(db);
  }
}

Future<void> ensureOverlaysTableExists(AppDatabase db) async {
  await db.customStatement(kEnsureOverlaysTableSql);
}

/// Returns `false` only for explicit disables (`false`, `0`, `no`, `off`).
bool parseDisplayOverlayGloballyEnabled(String? kv) {
  if (kv == null || kv.trim().isEmpty) {
    return true;
  }
  switch (kv.trim().toLowerCase()) {
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      return true;
  }
}

({Map<String, dynamic> rest, List<String> messages}) _splitOverlayConfigForNormalize(
  String configJson,
) {
  dynamic decoded;
  try {
    decoded = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
  } on Object {
    throw FormatException('invalid_config_json');
  }
  if (decoded is! Map) {
    throw FormatException('invalid_config_json');
  }
  final map = Map<String, dynamic>.from(
    decoded.map((k, v) => MapEntry(k.toString(), v)),
  );
  final messagesRaw = map.remove('messages');
  final messages = <String>[];
  if (messagesRaw != null) {
    if (messagesRaw is! List) {
      throw FormatException('invalid_messages_in_config');
    }
    for (final e in messagesRaw) {
      if (e is! String || e.trim().isEmpty) {
        throw FormatException('invalid_messages_in_config');
      }
      messages.add(e.trim());
    }
  }
  return (rest: map, messages: messages);
}

String _mergeMessagesIntoConfigJsonString(
  String normalizedInnerJson,
  List<String> messages,
) {
  dynamic decoded;
  try {
    decoded = jsonDecode(normalizedInnerJson.trim().isEmpty ? '{}' : normalizedInnerJson);
  } on Object {
    return jsonEncode(<String, Object?>{'messages': messages});
  }
  final map = decoded is Map
      ? Map<String, dynamic>.from(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        )
      : <String, dynamic>{};
  map['messages'] = messages;
  return jsonEncode(map);
}

bool _isJsonEncodableOverlayValue(Object? v) {
  if (v == null) {
    return true;
  }
  if (v is bool || v is num || v is String) {
    return true;
  }
  if (v is List) {
    for (final e in v) {
      if (!_isJsonEncodableOverlayValue(e)) {
        return false;
      }
    }
    return true;
  }
  if (v is Map) {
    for (final e in v.entries) {
      if (e.key is! String) {
        return false;
      }
      if (!_isJsonEncodableOverlayValue(e.value)) {
        return false;
      }
    }
    return true;
  }
  return false;
}

String _normalizeUnknownOverlayConfigJson(
  Map<String, dynamic> rest,
  List<String> messages,
) {
  for (final v in rest.values) {
    if (!_isJsonEncodableOverlayValue(v)) {
      throw FormatException('invalid_config_json');
    }
  }
  final out = Map<String, dynamic>.from(rest);
  out['messages'] = messages;
  return jsonEncode(out);
}

/// Normalizes and returns stored `config_json` (including a `messages` array).
String normalizeOverlayConfigForUpsert({
  required String overlayType,
  required String configJson,
}) {
  final trimmedType = overlayType.trim();
  final split = _splitOverlayConfigForNormalize(configJson);
  final restJson = jsonEncode(split.rest);
  return switch (trimmedType) {
    kOverlayTypeHeartsRain => jsonEncode(<String, Object?>{'messages': split.messages}),
    kOverlayTypeBirthdayConfetti =>
        normalizeBirthdayConfettiSettingsJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeBouncingMessage => () {
        final normalizedInner =
            normalizeBouncingMessageConfigJsonString(restJson) ??
                (throw FormatException('invalid_config_json'));
        return _mergeMessagesIntoConfigJsonString(normalizedInner, split.messages);
      }(),
    kOverlayTypeFallingImages => () {
        final normalizedInner =
            normalizeFallingImagesConfigJsonString(restJson) ??
                (throw FormatException('invalid_config_json'));
        return _mergeMessagesIntoConfigJsonString(normalizedInner, split.messages);
      }(),
    _ => _normalizeUnknownOverlayConfigJson(split.rest, split.messages),
  };
}

List<String> decodeMessagesNonEmpty(DisplayOverlayRow row) {
  try {
    final decoded = jsonDecode(row.configJson);
    if (decoded is! Map) {
      return const [];
    }
    final map = decoded.cast<String, dynamic>();
    final raw = map['messages'];
    if (raw is! List) {
      return const [];
    }
    return [
      for (final e in raw)
        if (e is String && e.trim().isNotEmpty) e.trim(),
    ];
  } on Object {
    return const [];
  }
}

final RegExp _slug = RegExp(r'^[a-z0-9][a-z0-9_.-]*$');

String? validateOverlayUpsertDraft({
  required String id,
  required String overlayType,
}) {
  if (!_slug.hasMatch(id.trim())) {
    return 'invalid_id_slug';
  }
  final trimmedType = overlayType.trim();
  if (!_slug.hasMatch(trimmedType)) {
    return 'invalid_overlay_type';
  }
  return null;
}

Object? _decodedJsonOrNull(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(raw);
  } on Object {
    return raw;
  }
}

Future<String> upsertOverlay(
  AppDatabase db, {
  required String id,
  required String overlayType,
  required String name,
  required String configJson,
}) async {
  final err = validateOverlayUpsertDraft(
    id: id,
    overlayType: overlayType,
  );
  if (err != null) {
    throw FormatException(err);
  }
  final String configNorm;
  try {
    configNorm = normalizeOverlayConfigForUpsert(
      overlayType: overlayType,
      configJson: configJson,
    );
  } on FormatException {
    rethrow;
  } on Object {
    throw FormatException('invalid_config_json');
  }
  final doc = displayOverlayConfigJsonDocForType(overlayType.trim());
  final trimmedId = id.trim();
  await db.customStatement(
    'INSERT OR REPLACE INTO overlays ('
    'id, overlay_type, name, '
    'config_json, config_json_schema, example_config_json) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>[
      trimmedId,
      overlayType.trim(),
      name,
      configNorm,
      doc.schema,
      doc.example,
    ],
  );
  return trimmedId;
}

/// Back-compat alias.
Future<void> upsertOverlaySchedule(
  AppDatabase db, {
  required String id,
  required String overlayType,
  required String label,
  required String configJson,
  required bool repeatAnnually,
  int? yearExact,
  required int startMonth,
  required int startDay,
  int? endMonth,
  int? endDay,
  int? nthWeekOfMonth,
  int? nthWeekday,
}) =>
    upsertOverlay(
      db,
      id: id,
      overlayType: overlayType,
      name: label,
      configJson: configJson,
    );

Future<void> deleteOverlay(AppDatabase db, String id) async {
  await db.customStatement(
    'DELETE FROM overlays WHERE id = ?',
    <Object?>[id.trim()],
  );
}

/// Back-compat alias.
Future<void> deleteOverlaySchedule(AppDatabase db, String id) =>
    deleteOverlay(db, id);

Future<DisplayOverlayRow?> overlayById(AppDatabase db, String id) async {
  final trimmed = id.trim();
  final rows =
      await db
          .customSelect(
            'SELECT * FROM overlays WHERE id = ? LIMIT 1',
            variables: [Variable<String>(trimmed)],
          )
          .map(DisplayOverlayRow.fromQueryRow)
          .get();
  if (rows.isEmpty) {
    return null;
  }
  return rows.first;
}

/// Back-compat alias.
Future<DisplayOverlayRow?> overlayScheduleById(AppDatabase db, String id) =>
    overlayById(db, id);

Map<String, Object?> overlayToJson(DisplayOverlayRow row) {
  Object? configField;
  try {
    final d = jsonDecode(row.configJson);
    if (d is Map) {
      configField = Map<String, Object?>.from(
        d.map((k, v) => MapEntry(k.toString(), v)),
      );
    } else {
      configField = const <String, Object?>{};
    }
  } on Object {
    configField = const <String, Object?>{};
  }
  return <String, Object?>{
    'id': row.id,
    'overlay_type': row.overlayType,
    'name': row.name,
    'config_json': configField,
    'config_json_schema': _decodedJsonOrNull(row.configJsonSchema),
    'example_config_json': _decodedJsonOrNull(row.exampleConfigJson),
  };
}

/// Back-compat alias.
Map<String, Object?> overlayScheduleToJson(DisplayOverlayRow row) =>
    overlayToJson(row);
