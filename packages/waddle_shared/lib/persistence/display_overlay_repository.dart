import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'config_json_documentation.dart';
import 'database.dart';
import '../seed/tables/overlay_types_seed.dart';
import 'display_overlay_bouncing_message_settings.dart';
import 'display_overlay_confetti_settings.dart';
import 'display_overlay_falling_images_settings.dart';
import 'display_overlay_floating_balloons_settings.dart';
import 'display_overlay_cloud_drift_settings.dart';
import 'display_overlay_edge_glow_settings.dart';
import 'display_overlay_matrix_rain_settings.dart';
import 'display_overlay_shape_rain_settings.dart';
import 'display_overlay_analog_clock_settings.dart';
import 'display_overlay_stock_quote_settings.dart';
import 'display_overlay_qr_code_settings.dart';
import 'display_overlay_calendar_month_settings.dart';
import 'display_overlay_calendar_upcoming_settings.dart';
import 'display_overlay_digital_clock_settings.dart';
import 'display_overlay_photo_slideshow_settings.dart';
import 'display_overlay_static_image_settings.dart';
import 'display_overlay_row.dart';
import 'display_overlay_sql.dart';
import 'overlay_type_label.dart';
import 'tables.dart';

/// Broadcast when `overlays` rows change (`upsertOverlay` / `deleteOverlay`).
///
/// The table is managed via custom SQL (not a generated Drift table), so writes
/// must notify explicitly for [watchDisplayOverlaySchedules] subscribers.
final StreamController<void> _overlayTableChanges =
    StreamController<void>.broadcast();

void _notifyOverlayTableChanged() {
  if (!_overlayTableChanges.isClosed) {
    _overlayTableChanges.add(null);
  }
}

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

/// Emits whenever overlay rows change (REST upserts/deletes via [upsertOverlay]).
Stream<List<DisplayOverlayRow>> watchDisplayOverlaySchedules(AppDatabase db) {
  StreamSubscription<void>? tableSub;
  return Stream<List<DisplayOverlayRow>>.multi((controller) async {
    Future<void> emitRows() async {
      if (controller.isClosed) {
        return;
      }
      controller.add(await fetchDisplayOverlays(db));
    }

    await emitRows();
    tableSub = _overlayTableChanges.stream.listen((_) {
      unawaited(emitRows());
    });
    controller.onCancel = () {
      unawaited(tableSub?.cancel());
    };
  });
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
    kOverlayTypeShapeRain || kOverlayTypeHeartsRain =>
        normalizeShapeRainSettingsJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeBirthdayConfetti =>
        normalizeBirthdayConfettiSettingsJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeBouncingMessage => () {
        final normalizedInner =
            normalizeBouncingMessageConfigJsonString(restJson) ??
                (throw FormatException('invalid_config_json'));
        return _mergeMessagesIntoConfigJsonString(normalizedInner, split.messages);
      }(),
    kOverlayTypeFallingImages =>
        normalizeFallingImagesConfigJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeFloatingBalloons =>
        normalizeFloatingBalloonsConfigJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeMatrixRain =>
        normalizeMatrixRainSettingsJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeEdgeGlow =>
        normalizeEdgeGlowSettingsJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeCloudDrift =>
        normalizeCloudDriftSettingsJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeStaticImage =>
        normalizeStaticImageSettingsJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeDigitalClock =>
        normalizeDigitalClockOverlayConfigJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeAnalogClock =>
        normalizeAnalogClockOverlayConfigJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeCalendarMonth =>
        normalizeCalendarMonthOverlayConfigJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeCalendarUpcoming =>
        normalizeCalendarUpcomingOverlayConfigJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeStockQuote =>
        normalizeStockQuoteOverlayConfigJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypePhotoSlideshow =>
        normalizePhotoSlideshowSettingsJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
    kOverlayTypeQrCode =>
        normalizeQrCodeOverlayConfigJsonString(restJson) ??
            (throw FormatException('invalid_config_json')),
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
  required String label,
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
  final trimmedType = overlayType.trim();
  await ensureOverlayTypes(db);
  if (!await overlayTypeExists(db, trimmedType)) {
    final doc = displayOverlayConfigJsonDocForType(trimmedType);
    await db.into(db.overlayTypes).insert(
          OverlayTypesCompanion.insert(
            overlayType: trimmedType,
            label: overlayTypeLabel(trimmedType),
            configJsonSchema: Value(doc.schema),
          ),
        );
  }
  final trimmedId = id.trim();
  await db.customStatement(
    'INSERT OR REPLACE INTO overlays ('
    'id, overlay_type, label, config_json) '
    'VALUES (?, ?, ?, ?)',
    <Object?>[
      trimmedId,
      trimmedType,
      label,
      configNorm,
    ],
  );
  _notifyOverlayTableChanged();
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
      label: label,
      configJson: configJson,
    );

Future<void> deleteOverlay(AppDatabase db, String id) async {
  await db.customStatement(
    'DELETE FROM overlays WHERE id = ?',
    <Object?>[id.trim()],
  );
  _notifyOverlayTableChanged();
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

Map<String, Object?> overlayToJson(
  DisplayOverlayRow row, {
  bool includeConfigDocs = false,
  String? configJsonSchema,
}) {
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
  final out = <String, Object?>{
    'id': row.id,
    'overlay_type': row.overlayType,
    'label': row.label,
    'config_json': configField,
  };
  if (includeConfigDocs) {
    out['config_json_schema'] = _decodedJsonOrNull(configJsonSchema);
  }
  return out;
}

/// Schema strings keyed by [DisplayOverlayRow.overlayType].
Future<Map<String, String?>> overlayTypeConfigJsonSchemasByType(
  AppDatabase db,
) async {
  final rows = await db.select(db.overlayTypes).get();
  return {for (final r in rows) r.overlayType: r.configJsonSchema};
}

/// Resolves overlay type schema (DB first, then code catalog).
Future<String?> overlayTypeSchemaForJson(
  AppDatabase db,
  String overlayType, {
  Map<String, String?>? cache,
}) async {
  final cached = cache?[overlayType];
  if (cached != null && cached.trim().isNotEmpty) {
    return cached;
  }
  return overlayTypeConfigJsonSchema(db, overlayType);
}

/// Back-compat alias.
Map<String, Object?> overlayScheduleToJson(DisplayOverlayRow row) =>
    overlayToJson(row);
