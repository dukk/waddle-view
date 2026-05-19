import 'package:drift/drift.dart' hide isNull, isNotNull;

String _readConfigJson(QueryRow row) {
  final Object? raw = row.data['config_json'];
  if (raw == null) {
    return '{}';
  }
  return raw as String;
}

/// One row of [overlays] (custom SQL backed).
class DisplayOverlayRow {
  const DisplayOverlayRow({
    required this.id,
    required this.overlayType,
    required this.label,
    required this.configJson,
  });

  final String id;
  final String overlayType;
  final String label;
  final String configJson;

  static DisplayOverlayRow fromQueryRow(QueryRow row) {
    return DisplayOverlayRow(
      id: row.read<String>('id'),
      overlayType: row.read<String>('overlay_type'),
      label: row.read<String>('label'),
      configJson: _readConfigJson(row),
    );
  }
}
