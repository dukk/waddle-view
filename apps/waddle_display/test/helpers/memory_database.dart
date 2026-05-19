import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:waddle_shared/config/integration_config_json.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/integration_types_seed.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/theme/display_program_history_kv.dart';

export 'package:waddle_shared/persistence/tables.dart';

AppDatabase openMemoryDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

Future<void> seedDisplayProgramHistoryDepthForTest(
  AppDatabase db,
  int depth,
) async {
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kDisplayProgramHistoryDepthKvKey,
          value: '$depth',
        ),
      );
}

Future<void> warmDatabase(AppDatabase db, {String? displayTimeZoneIana}) async {
  await db.customStatement('select 1');
  await ensureIntegrationTypes(db);
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
  await db.into(db.integrations).insert(
        IntegrationsCompanion.insert(
          id: 'stub',
          integrationType: 'stub',
          enabled: const Value(true),
          pollSeconds: const Value(60),
        ),
      );
}

/// Seed ad-hoc curator category rows (`curator_categories`) so tests can reference category ids
/// (FK target of e.g. `calendar_events.category_id`) without depending on
/// `ensureInitialSeed`. Pass each id you intend to use; label defaults to id.
/// Merges [baseUrl] into integration `config_json` for test inserts.
Value<String?> integrationConfigJsonValue({
  String? configJson,
  String? baseUrl,
}) {
  final merged = mergeBaseUrlIntoIntegrationConfig(configJson, baseUrl);
  if (merged == null) {
    return const Value.absent();
  }
  return Value(merged);
}

Future<void> seedIntegrationKvForTest(
  AppDatabase db, {
  String? integrationId,
  String? accountId,
  required String key,
  required String value,
  String? valueType,
  String accountType = kIntegrationAccountTypeMicrosoftGraph,
}) async {
  if (accountId != null) {
    final existing = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(accountId)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.integrationAccounts).insert(
            IntegrationAccountsCompanion.insert(
              id: accountId,
              accountType: accountType,
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    }
  }
  final kv = IntegrationKvRepository(db);
  if (integrationId != null) {
    await kv.upsertIntegration(
      integrationId: integrationId,
      key: key,
      value: value,
      valueType: valueType ?? integrationKvTypeForKey(key),
    );
    return;
  }
  if (accountId == null) {
    throw ArgumentError('integrationId or accountId required');
  }
  await kv.upsertAccount(
    accountId: accountId,
    key: key,
    value: value,
    valueType: valueType ?? integrationKvTypeForKey(key),
  );
}

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
