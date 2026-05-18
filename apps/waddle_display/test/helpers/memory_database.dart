import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

export 'package:waddle_shared/persistence/tables.dart';

AppDatabase openMemoryDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

Future<void> warmDatabase(AppDatabase db, {String? displayTimeZoneIana}) async {
  await db.customStatement('select 1');
  if (displayTimeZoneIana != null) {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTimezoneKvKey,
            value: displayTimeZoneIana,
          ),
        );
  }
}

/// Inserts the stub integration when missing (not part of production seed).
Future<void> seedStubIntegrationForTest(AppDatabase db) async {
  final existing = await (db.select(db.integrations)
        ..where((t) => t.id.equals('stub')))
      .getSingleOrNull();
  if (existing != null) {
    return;
  }
  final stubDoc = providerConfigJsonDocForType('stub');
  await db.into(db.integrations).insert(
        IntegrationsCompanion.insert(
          id: 'stub',
          integrationType: 'stub',
          enabled: const Value(true),
          pollSeconds: const Value(60),
          configJsonSchema: Value(stubDoc.schema),
          exampleConfigJson: Value(stubDoc.example),
        ),
      );
}

/// Seed ad-hoc curator category rows (`curator_categories`) so tests can reference category ids
/// (FK target of e.g. `calendar_events.category_id`) without depending on
/// `ensureInitialSeed`. Pass each id you intend to use; label defaults to id.
Future<void> seedContentCategoriesForTest(
  AppDatabase db,
  Iterable<String> ids, {
  String? label,
}) async {
  for (final id in ids) {
    await db.into(db.contentCategories).insertOnConflictUpdate(
          ContentCategoriesCompanion.insert(
            id: id,
            label: label ?? id,
          ),
        );
  }
}
