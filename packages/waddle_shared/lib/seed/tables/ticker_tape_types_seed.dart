import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/ticker_type_label.dart';

/// Ensures every built-in ticker type exists in [TickerTapeTypes].
Future<void> ensureTickerTapeTypes(AppDatabase db) async {
  final referenced = await db.customSelect(
    'SELECT DISTINCT ticker_type FROM ticker_tapes',
  ).get();
  final types = <String>{
    ...kTickerSlotDefinitionTypes,
    for (final row in referenced) row.read<String>('ticker_type'),
  };
  for (final tickerType in types) {
    final doc = tickerSlotConfigJsonDocForType(tickerType);
    final label = tickerTypeLabel(tickerType);
    final existing = await (db.select(db.tickerTapeTypes)
          ..where((t) => t.tickerType.equals(tickerType)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.tickerTapeTypes).insert(
            TickerTapeTypesCompanion.insert(
              tickerType: tickerType,
              label: label,
              configJsonSchema: Value(doc.schema),
            ),
          );
    } else {
      await (db.update(db.tickerTapeTypes)
            ..where((t) => t.tickerType.equals(tickerType)))
          .write(
        TickerTapeTypesCompanion(
          label: Value(label),
          configJsonSchema: Value(doc.schema),
        ),
      );
    }
  }
}

/// JSON Schema for [tickerType] (DB first, then code catalog).
Future<String?> tickerTypeConfigJsonSchema(
  AppDatabase db,
  String tickerType,
) async {
  final row = await (db.select(db.tickerTapeTypes)
        ..where((t) => t.tickerType.equals(tickerType)))
      .getSingleOrNull();
  if (row?.configJsonSchema != null && row!.configJsonSchema!.trim().isNotEmpty) {
    return row.configJsonSchema;
  }
  return tickerSlotConfigJsonDocForType(tickerType).schema;
}

/// True when [tickerType] exists in [TickerTapeTypes].
Future<bool> tickerTypeExists(AppDatabase db, String tickerType) async {
  final row = await (db.select(db.tickerTapeTypes)
        ..where((t) => t.tickerType.equals(tickerType.trim())))
      .getSingleOrNull();
  return row != null;
}
