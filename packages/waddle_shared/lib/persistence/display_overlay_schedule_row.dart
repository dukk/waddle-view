import 'package:drift/drift.dart' hide isNull, isNotNull;

String _readConfigJson(QueryRow row) {
  final Object? raw = row.data['config_json'];
  if (raw == null) {
    return '{}';
  }
  return raw as String;
}

String? _readOptionalString(QueryRow row, String key) {
  final Object? raw = row.data[key];
  if (raw == null) {
    return null;
  }
  return raw as String;
}

int? _readOptionalInt(QueryRow row, String key) {
  final Object? raw = row.data[key];
  if (raw == null) {
    return null;
  }
  return raw as int;
}

/// One row of [overlays] (custom SQL backed).
class DisplayOverlayScheduleRow {
  const DisplayOverlayScheduleRow({
    required this.id,
    required this.enabled,
    required this.overlayType,
    required this.label,
    required this.configJson,
    required this.configJsonSchema,
    required this.exampleConfigJson,
    required this.repeatAnnually,
    required this.yearExact,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
    required this.nthWeekOfMonth,
    required this.nthWeekday,
  });

  final String id;
  final bool enabled;
  final String overlayType;
  final String label;
  final String configJson;
  final String? configJsonSchema;
  final String? exampleConfigJson;
  final bool repeatAnnually;
  final int? yearExact;
  final int startMonth;
  final int startDay;
  final int? endMonth;
  final int? endDay;
  final int? nthWeekOfMonth;
  final int? nthWeekday;

  static DisplayOverlayScheduleRow fromQueryRow(QueryRow row) {
    return DisplayOverlayScheduleRow(
      id: row.read<String>('id'),
      enabled: row.read<int>('enabled') != 0,
      overlayType: row.read<String>('overlay_type'),
      label: row.read<String>('label'),
      configJson: _readConfigJson(row),
      configJsonSchema: _readOptionalString(row, 'config_json_schema'),
      exampleConfigJson: _readOptionalString(row, 'example_config_json'),
      repeatAnnually: row.read<int>('repeat_annually') != 0,
      yearExact: _readOptionalInt(row, 'year_exact'),
      startMonth: row.read<int>('start_month'),
      startDay: row.read<int>('start_day'),
      endMonth: _readOptionalInt(row, 'end_month'),
      endDay: _readOptionalInt(row, 'end_day'),
      nthWeekOfMonth: _readOptionalInt(row, 'nth_week_of_month'),
      nthWeekday: _readOptionalInt(row, 'nth_weekday'),
    );
  }
}
