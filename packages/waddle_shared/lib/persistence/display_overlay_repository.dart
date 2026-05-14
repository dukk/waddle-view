import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'config_json_documentation.dart';
import 'database.dart';
import 'display_overlay_bouncing_message_settings.dart';
import 'display_overlay_confetti_settings.dart';
import 'display_overlay_schedule_row.dart';
import 'display_overlay_sql.dart';
import 'tables.dart';

Selectable<DisplayOverlayScheduleRow> _overlaySelectable(AppDatabase db) {
  return db.customSelect(
    'SELECT * FROM display_overlay_schedules ORDER BY id ASC',
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

Future<void> ensureDisplayOverlayTableExists(AppDatabase db) async {
  await db.customStatement(kEnsureDisplayOverlaySchedulesTableSql);
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

String? normalizeMessagesJsonString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '[]') {
    return '[]';
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on Object {
    return null;
  }
  if (decoded is! List) {
    return null;
  }
  for (final e in decoded) {
    if (e is! String || e.trim().isEmpty) {
      return null;
    }
  }
  return jsonEncode(decoded.cast<String>());
}

List<String> decodeMessagesNonEmpty(DisplayOverlayScheduleRow row) {
  List<dynamic>? list;
  try {
    final decoded = jsonDecode(row.messagesJson);
    list = decoded is List ? decoded : null;
  } on Object {
    return const [];
  }
  if (list == null) {
    return const [];
  }
  return [
    for (final e in list)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
}

final RegExp _slug = RegExp(r'^[a-z0-9][a-z0-9_.-]*$');

String? validateUpsertDraft({
  required String id,
  required String overlayKind,
  required String messagesJsonNormalized,
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
  final trimmedKind = overlayKind.trim();
  if (!_slug.hasMatch(trimmedKind)) {
    return 'invalid_overlay_kind';
  }
  if (trimmedKind != kOverlayKindHeartsRain &&
      trimmedKind != kOverlayKindBirthdayConfetti &&
      trimmedKind != kOverlayKindBouncingMessage) {
    return 'unsupported_overlay_kind';
  }
  if (normalizeMessagesJsonString(messagesJsonNormalized) == null) {
    return 'invalid_messages_json';
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
  required bool enabled,
  required String overlayKind,
  required String label,
  required String messagesJson,
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
  final norm = normalizeMessagesJsonString(messagesJson) ?? '[]';
  final err = validateUpsertDraft(
    id: id,
    overlayKind: overlayKind,
    messagesJsonNormalized: norm,
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
  final kind = overlayKind.trim();
  final String configNorm = switch (kind) {
    kOverlayKindHeartsRain => '{}',
    kOverlayKindBirthdayConfetti =>
        normalizeBirthdayConfettiSettingsJsonString(configJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayKindBouncingMessage =>
        normalizeBouncingMessageConfigJsonString(configJson) ??
            (throw FormatException('invalid_config_json')),
    _ => throw StateError('unexpected overlay kind'),
  };
  final doc = displayOverlayConfigJsonDocForKind(kind);
  final en = enabled ? 1 : 0;
  final ra = repeatAnnually ? 1 : 0;
  await db.customStatement(
    'INSERT OR REPLACE INTO display_overlay_schedules ('
    'id, enabled, overlay_kind, label, messages_json, '
    'config_json, config_json_schema, example_config_json, '
    'repeat_annually, year_exact, start_month, start_day, '
    'end_month, end_day, nth_week_of_month, nth_weekday) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      id.trim(),
      en,
      overlayKind.trim(),
      label,
      norm,
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
    'DELETE FROM display_overlay_schedules WHERE id = ?',
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
            'SELECT * FROM display_overlay_schedules WHERE id = ? LIMIT 1',
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
  Object? messagesField;
  try {
    final d = jsonDecode(row.messagesJson);
    messagesField = d is List ? d : const <Object?>[];
  } on Object {
    messagesField = const <Object?>[];
  }
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
    'enabled': row.enabled,
    'overlay_kind': row.overlayKind,
    'label': row.label,
    'messages_json': messagesField,
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
