import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/overlay_type_label.dart';
import 'package:waddle_shared/persistence/tables.dart';

Future<bool> _sqliteTableExists(AppDatabase db, String tableName) async {
  final row = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    variables: [Variable<String>(tableName)],
  ).getSingleOrNull();
  return row != null;
}

/// Ensures every built-in overlay type exists in [OverlayTypes].
Future<void> ensureOverlayTypes(AppDatabase db) async {
  final referenced = <String>{};
  if (await _sqliteTableExists(db, 'overlays')) {
    final rows = await db.customSelect(
      'SELECT DISTINCT overlay_type FROM overlays',
    ).get();
    referenced.addAll(rows.map((row) => row.read<String>('overlay_type')));
  }
  final types = <String>{
    ...kBuiltinOverlayTypes,
    ...referenced,
  };
  for (final overlayType in types) {
    final doc = displayOverlayConfigJsonDocForType(overlayType);
    final label = overlayTypeLabel(overlayType);
    final existing = await (db.select(db.overlayTypes)
          ..where((t) => t.overlayType.equals(overlayType)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.overlayTypes).insert(
            OverlayTypesCompanion.insert(
              overlayType: overlayType,
              label: label,
              configJsonSchema: Value(doc.schema),
            ),
          );
    } else {
      await (db.update(db.overlayTypes)
            ..where((t) => t.overlayType.equals(overlayType)))
          .write(
        OverlayTypesCompanion(
          label: Value(label),
          configJsonSchema: Value(doc.schema),
        ),
      );
    }
  }
}

/// JSON Schema for [overlayType] (DB first, then code catalog).
Future<String?> overlayTypeConfigJsonSchema(
  AppDatabase db,
  String overlayType,
) async {
  final row = await (db.select(db.overlayTypes)
        ..where((t) => t.overlayType.equals(overlayType)))
      .getSingleOrNull();
  if (row?.configJsonSchema != null && row!.configJsonSchema!.trim().isNotEmpty) {
    return row.configJsonSchema;
  }
  return displayOverlayConfigJsonDocForType(overlayType).schema;
}

/// True when [overlayType] exists in [OverlayTypes].
Future<bool> overlayTypeExists(AppDatabase db, String overlayType) async {
  final row = await (db.select(db.overlayTypes)
        ..where((t) => t.overlayType.equals(overlayType.trim())))
      .getSingleOrNull();
  return row != null;
}
