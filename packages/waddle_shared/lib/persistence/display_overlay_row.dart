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

/// One row of [overlays] (custom SQL backed).
class DisplayOverlayRow {
  const DisplayOverlayRow({
    required this.id,
    required this.overlayType,
    required this.name,
    required this.configJson,
    required this.configJsonSchema,
    required this.exampleConfigJson,
  });

  final String id;
  final String overlayType;
  final String name;
  final String configJson;
  final String? configJsonSchema;
  final String? exampleConfigJson;

  static DisplayOverlayRow fromQueryRow(QueryRow row) {
    return DisplayOverlayRow(
      id: row.read<String>('id'),
      overlayType: row.read<String>('overlay_type'),
      name: row.read<String>('name'),
      configJson: _readConfigJson(row),
      configJsonSchema: _readOptionalString(row, 'config_json_schema'),
      exampleConfigJson: _readOptionalString(row, 'example_config_json'),
    );
  }
}
