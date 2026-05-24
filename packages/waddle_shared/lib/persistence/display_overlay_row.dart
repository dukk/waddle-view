import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'database.dart';

String _readConfigJson(QueryRow row) {
  final Object? raw = row.data['config_json'];
  if (raw == null) {
    return '{}';
  }
  return raw as String;
}

/// One row of [overlays].
class DisplayOverlayRow {
  const DisplayOverlayRow({
    required this.id,
    required this.overlayType,
    required this.label,
    required this.description,
    required this.configJson,
  });

  final String id;
  final String overlayType;
  final String label;
  final String description;
  final String configJson;

  factory DisplayOverlayRow.fromData(Overlay data) => DisplayOverlayRow(
    id: data.id,
    overlayType: data.overlayType,
    label: data.label,
    description: data.description,
    configJson: data.configJson,
  );

  static DisplayOverlayRow fromQueryRow(QueryRow row) {
    String description = '';
    try {
      description = row.read<String>('description');
    } on Object {
      description = '';
    }
    return DisplayOverlayRow(
      id: row.read<String>('id'),
      overlayType: row.read<String>('overlay_type'),
      label: row.read<String>('label'),
      description: description,
      configJson: _readConfigJson(row),
    );
  }
}
