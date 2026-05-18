import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'config_json_documentation.dart';
import 'database.dart';
import 'display_overlay_bouncing_message_settings.dart';
import 'display_overlay_confetti_settings.dart';
import 'display_overlay_falling_images_settings.dart';
import 'display_overlay_schedule_row.dart';
import 'display_overlay_sql.dart';
import 'tables.dart';

Selectable<DisplayOverlayScheduleRow> _overlaySelectable(AppDatabase db) {
  return db.customSelect(
    'SELECT * FROM overlays ORDER BY id ASC',
  ).map(DisplayOverlayScheduleRow.fromQueryRow);
}

Future<List<DisplayOverlayScheduleRow>> fetchDisplayOverlaySchedules(
  AppDatabase db,
) =>
    _overlaySelectable(db).get();

/// Periodically polls the table so REST changes appear without restarting the UI isolate.
Stream<List<DisplayOverlayScheduleRow>> watchDisplayOverlaySchedules(
  AppDatabase db,
) async* {
  yield await fetchDisplayOverlaySchedules(db);
  await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
    yield await fetchDisplayOverlaySchedules(db);
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
    kOverlayTypeBirthdayConfetti => () {
        final normalizedInner =
            normalizeBirthdayConfettiSettingsJsonString(restJson) ??
                (throw FormatException('invalid_config_json'));
        return _mergeMessagesIntoConfigJsonString(normalizedInner, split.messages);
      }(),
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

List<String> decodeMessagesNonEmpty(DisplayOverlayScheduleRow row) {
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

String? validateUpsertDraft({
  required String id,
  required String overlayType,
  required bool repeatAnnually,
  required int? yearExact,
  required int startMonth,
  required int startDay,
  required int? endMonth,
  required int? endDay,
  required int? nthWeekOfMonth,
  required int? nthWeekday,
}) {
  if (!_slug.hasMatch(id.trim())) {
    return 'invalid_id_slug';
  }
  final trimmedType = overlayType.trim();
  if (!_slug.hasMatch(trimmedType)) {
    return 'invalid_overlay_type';
  }

  final nthSet = nthWeekOfMonth != null || nthWeekday != null;
  if (nthSet && (nthWeekOfMonth == null || nthWeekday == null)) {
    return 'nth_fields_both_required';
  }
  if (nthWeekday != null &&
      (nthWeekday < DateTime.monday || nthWeekday > DateTime.sunday)) {
    return 'invalid_nth_weekday';
  }
  if (nthWeekOfMonth != null && (nthWeekOfMonth < 1 || nthWeekOfMonth > 5)) {
    return 'invalid_nth_week_of_month';
  }

  if (!repeatAnnually && yearExact == null) {
    return 'year_exact_required_when_not_repeating';
  }

  final sampleYear =
      repeatAnnually ? DateTime.now().year : (yearExact ?? DateTime.now().year);

  if (nthWeekOfMonth != null) {
    if (startMonth < 1 || startMonth > 12) {
      return 'invalid_start_month';
    }
    try {
      DateTime(sampleYear, startMonth, 1);
    } on Object {
      return 'invalid_calendar_month_anchor';
    }
    return null;
  }

  if (!_validYmd(sampleYear, startMonth, startDay)) {
    return 'invalid_fixed_start_date';
  }
  final endM = endMonth ?? startMonth;
  final endD = endDay ?? startDay;
  if (!_validYmd(sampleYear, endM, endD)) {
    return 'invalid_fixed_end_date';
  }
  try {
    final s = DateTime(sampleYear, startMonth, startDay);
    final e = DateTime(sampleYear, endM, endD);
    if (s.isAfter(e)) {
      return 'fixed_range_invalid';
    }
  } on Object {
    return 'fixed_range_invalid';
  }
  return null;
}

bool _validYmd(int y, int m, int d) {
  try {
    final dt = DateTime(y, m, d);
    return dt.year == y && dt.month == m && dt.day == d;
  } on Object {
    return false;
  }
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
}) async {
  final err = validateUpsertDraft(
    id: id,
    overlayType: overlayType,
    repeatAnnually: repeatAnnually,
    yearExact: yearExact,
    startMonth: startMonth,
    startDay: startDay,
    endMonth: endMonth,
    endDay: endDay,
    nthWeekOfMonth: nthWeekOfMonth,
    nthWeekday: nthWeekday,
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
  final ra = repeatAnnually ? 1 : 0;
  await db.customStatement(
    'INSERT OR REPLACE INTO overlays ('
    'id, overlay_type, label, '
    'config_json, config_json_schema, example_config_json, '
    'repeat_annually, year_exact, start_month, start_day, '
    'end_month, end_day, nth_week_of_month, nth_weekday) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      id.trim(),
      overlayType.trim(),
      label,
      configNorm,
      doc.schema,
      doc.example,
      ra,
      yearExact,
      startMonth,
      startDay,
      endMonth,
      endDay,
      nthWeekOfMonth,
      nthWeekday,
    ],
  );
}

Future<void> deleteOverlaySchedule(AppDatabase db, String id) async {
  await db.customStatement(
    'DELETE FROM overlays WHERE id = ?',
    <Object?>[id.trim()],
  );
}

Future<DisplayOverlayScheduleRow?> overlayScheduleById(
  AppDatabase db,
  String id,
) async {
  final trimmed = id.trim();
  final rows =
      await db
          .customSelect(
            'SELECT * FROM overlays WHERE id = ? LIMIT 1',
            variables: [Variable<String>(trimmed)],
          )
          .map(DisplayOverlayScheduleRow.fromQueryRow)
          .get();
  if (rows.isEmpty) {
    return null;
  }
  return rows.first;
}

Map<String, Object?> overlayScheduleToJson(DisplayOverlayScheduleRow row) {
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
    'label': row.label,
    'config_json': configField,
    'config_json_schema': _decodedJsonOrNull(row.configJsonSchema),
    'example_config_json': _decodedJsonOrNull(row.exampleConfigJson),
    'repeat_annually': row.repeatAnnually,
    'year_exact': row.yearExact,
    'start_month': row.startMonth,
    'start_day': row.startDay,
    'end_month': row.endMonth,
    'end_day': row.endDay,
    'nth_week_of_month': row.nthWeekOfMonth,
    'nth_weekday': row.nthWeekday,
  };
}
