import 'package:drift/drift.dart';

import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/integration_type_label.dart';

/// Ensures every built-in integration type exists in [IntegrationTypes].
Future<void> ensureIntegrationTypes(AppDatabase db) async {
  final types = <String>{
    ...kProviderConfigJsonMeta.keys,
    'news_facebook',
    'news_twitter',
    'news_linkedin',
  };
  for (final integrationType in types) {
    final doc = providerConfigJsonDocForType(integrationType);
    final requires = integrationAccountTypesRequiredForIntegration(
      integrationType,
    ).isNotEmpty;
    final label = integrationTypeLabel(integrationType);
    final existing = await (db.select(db.integrationTypes)
          ..where((t) => t.integrationType.equals(integrationType)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.integrationTypes).insert(
            IntegrationTypesCompanion.insert(
              integrationType: integrationType,
              label: label,
              configJsonSchema: Value(doc.schema),
              requiresAccounts: Value(requires),
            ),
          );
    } else {
      await (db.update(db.integrationTypes)
            ..where((t) => t.integrationType.equals(integrationType)))
          .write(
        IntegrationTypesCompanion(
          label: Value(label),
          configJsonSchema: Value(doc.schema),
          requiresAccounts: Value(requires),
        ),
      );
    }
  }
}

/// JSON Schema for [integrationType] (DB first, then code catalog).
Future<String?> integrationTypeConfigJsonSchema(
  AppDatabase db,
  String integrationType,
) async {
  final row = await (db.select(db.integrationTypes)
        ..where((t) => t.integrationType.equals(integrationType)))
      .getSingleOrNull();
  if (row?.configJsonSchema != null && row!.configJsonSchema!.trim().isNotEmpty) {
    return row.configJsonSchema;
  }
  return providerConfigJsonDocForType(integrationType).schema;
}

/// Lookup whether [integrationType] requires accounts (DB first, then catalog).
Future<bool> integrationTypeRequiresAccounts(
  AppDatabase db,
  String integrationType,
) async {
  final row = await (db.select(db.integrationTypes)
        ..where((t) => t.integrationType.equals(integrationType)))
      .getSingleOrNull();
  if (row != null) {
    return row.requiresAccounts;
  }
  return integrationAccountTypesRequiredForIntegration(integrationType)
      .isNotEmpty;
}
