import 'package:drift/drift.dart' hide isNull, isNotNull;

int? _readOptionalInt(QueryRow row, String key) {
  final Object? raw = row.data[key];
  if (raw == null) {
    return null;
  }
  return raw as int;
}

/// One row of [display_overlay_schedules] (custom SQL backed).
class DisplayOverlayScheduleRow {
  const DisplayOverlayScheduleRow({
    required this.id,
    required this.enabled,
    required this.overlayKind,
    required this.label,
    required this.messagesJson,
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
  final String overlayKind;
  final String label;
  final String messagesJson;
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
      overlayKind: row.read<String>('overlay_kind'),
      label: row.read<String>('label'),
      messagesJson: row.read<String>('messages_json'),
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
