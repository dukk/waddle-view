import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/screen_type_label.dart';

/// Ensures every built-in screen type exists in [ScreenTypes].
Future<void> ensureScreenTypes(AppDatabase db) async {
  final referenced = await db.customSelect(
    'SELECT DISTINCT screen_type FROM screens',
  ).get();
  final types = <String>{
    ...kScreenLayoutWidgetTypes,
    for (final row in referenced) row.read<String>('screen_type'),
  };
  for (final screenType in types) {
    final doc = screenConfigJsonDocForType(screenType);
    final label = screenTypeLabel(screenType);
    final existing = await (db.select(db.screenTypes)
          ..where((t) => t.screenType.equals(screenType)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.screenTypes).insert(
            ScreenTypesCompanion.insert(
              screenType: screenType,
              label: label,
              configJsonSchema: Value(doc.schema),
            ),
          );
    } else {
      await (db.update(db.screenTypes)
            ..where((t) => t.screenType.equals(screenType)))
          .write(
        ScreenTypesCompanion(
          label: Value(label),
          configJsonSchema: Value(doc.schema),
        ),
      );
    }
  }
}

/// JSON Schema for [screenType] (DB first, then code catalog).
Future<String?> screenTypeConfigJsonSchema(
  AppDatabase db,
  String screenType,
) async {
  final row = await (db.select(db.screenTypes)
        ..where((t) => t.screenType.equals(screenType)))
      .getSingleOrNull();
  if (row?.configJsonSchema != null && row!.configJsonSchema!.trim().isNotEmpty) {
    return row.configJsonSchema;
  }
  return screenConfigJsonDocForType(screenType).schema;
}

/// True when [screenType] exists in [ScreenTypes].
Future<bool> screenTypeExists(AppDatabase db, String screenType) async {
  final row = await (db.select(db.screenTypes)
        ..where((t) => t.screenType.equals(screenType.trim())))
      .getSingleOrNull();
  return row != null;
}
