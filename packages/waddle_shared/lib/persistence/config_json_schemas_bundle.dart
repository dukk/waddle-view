import 'dart:convert';

import '../integration_accounts/integration_account_catalog.dart';
import '../seed/tables/overlay_types_seed.dart';
import 'config_json_documentation.dart';
import 'kv_schema_documentation.dart';
import 'database.dart';
import 'integration_type_label.dart';
import 'overlay_type_label.dart';
import 'screen_type_label.dart';
import 'tables.dart';
import 'ticker_type_label.dart';

/// Decodes a stored JSON Schema or example string for REST responses.
Object? decodeConfigJsonDocField(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(raw);
  } catch (_) {
    return raw;
  }
}

Map<String, Object?> screenTypeConfigJsonMetaItem(String screenType) {
  final doc = screenConfigJsonDocForType(screenType);
  return {
    'screen_type': screenType,
    'label': screenTypeLabel(screenType),
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> screenTypeConfigJsonMetaItemFromRow(ScreenType row) {
  final doc = screenConfigJsonDocForType(row.screenType);
  return {
    'screen_type': row.screenType,
    'label': row.label,
    'config_json_schema': decodeConfigJsonDocField(
      row.configJsonSchema ?? doc.schema,
    ),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> tickerTypeConfigJsonMetaItem(String tickerType) {
  final doc = tickerSlotConfigJsonDocForType(tickerType);
  return {
    'ticker_type': tickerType,
    'label': tickerTypeLabel(tickerType),
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> tickerTypeConfigJsonMetaItemFromRow(TickerTapeType row) {
  final doc = tickerSlotConfigJsonDocForType(row.tickerType);
  return {
    'ticker_type': row.tickerType,
    'label': row.label,
    'config_json_schema': decodeConfigJsonDocField(
      row.configJsonSchema ?? doc.schema,
    ),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> overlayTypeConfigJsonMetaItem(String overlayType) {
  final doc = displayOverlayConfigJsonDocForType(overlayType);
  return {
    'overlay_type': overlayType,
    'label': overlayTypeLabel(overlayType),
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> overlayTypeConfigJsonMetaItemFromRow(OverlayType row) {
  final doc = displayOverlayConfigJsonDocForType(row.overlayType);
  return {
    'overlay_type': row.overlayType,
    'label': row.label,
    'config_json_schema': decodeConfigJsonDocField(
      row.configJsonSchema ?? doc.schema,
    ),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> integrationTypeConfigJsonMetaItem(String integrationType) {
  final doc = providerConfigJsonDocForType(integrationType);
  return {
    'integration_type': integrationType,
    'label': integrationTypeLabel(integrationType),
    'requires_accounts': integrationAccountTypesRequiredForIntegration(
      integrationType,
    ).isNotEmpty,
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> integrationTypeConfigJsonMetaItemFromRow(
  IntegrationType row,
) {
  final doc = providerConfigJsonDocForType(row.integrationType);
  return {
    'integration_type': row.integrationType,
    'label': row.label,
    'requires_accounts': row.requiresAccounts,
    'config_json_schema': decodeConfigJsonDocField(
      row.configJsonSchema ?? doc.schema,
    ),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

List<Map<String, Object?>> buildScreenTypeConfigJsonMetaItems() => [
      for (final t in kScreenLayoutWidgetTypes) screenTypeConfigJsonMetaItem(t),
    ];

List<Map<String, Object?>> buildTickerTypeConfigJsonMetaItems() => [
      for (final t in kTickerSlotDefinitionTypes) tickerTypeConfigJsonMetaItem(t),
    ];

List<Map<String, Object?>> buildOverlayTypeConfigJsonMetaItems() => [
      for (final t in kBuiltinOverlayTypes) overlayTypeConfigJsonMetaItem(t),
    ];

List<Map<String, Object?>> buildIntegrationTypeConfigJsonMetaItems() => [
      for (final t in kProviderConfigJsonMeta.keys)
        integrationTypeConfigJsonMetaItem(t),
    ];

Map<String, Object?> kvWidgetTypeConfigJsonMetaItem(String widgetType) {
  final doc = kvWidgetConfigJsonDocForType(widgetType);
  return {
    'widget_type': widgetType,
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_config_json': decodeConfigJsonDocField(doc.example),
    'expected_value_type': doc.expectedValueType,
  };
}

Map<String, Object?> kvValueDataTypeMetaItem(String id) {
  final doc = kKvValueDataTypeMeta[id]!;
  return {
    'id': doc.id,
    'description': doc.description,
    'value_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_value_json': decodeConfigJsonDocField(doc.example),
  };
}

List<Map<String, Object?>> buildKvWidgetTypeConfigJsonMetaItems() => [
      for (final t in kKvWidgetTypes) kvWidgetTypeConfigJsonMetaItem(t),
    ];

List<Map<String, Object?>> buildKvValueDataTypeMetaItems() => [
      for (final id in kKvValueDataTypeMeta.keys) kvValueDataTypeMetaItem(id),
    ];

Future<List<Map<String, Object?>>> buildScreenTypeConfigJsonMetaItemsFromDb(
  AppDatabase db,
) async {
  final rows = await db.select(db.screenTypes).get();
  if (rows.isEmpty) {
    return buildScreenTypeConfigJsonMetaItems();
  }
  rows.sort((a, b) => a.screenType.compareTo(b.screenType));
  return [for (final row in rows) screenTypeConfigJsonMetaItemFromRow(row)];
}

Future<List<Map<String, Object?>>> buildTickerTypeConfigJsonMetaItemsFromDb(
  AppDatabase db,
) async {
  final rows = await db.select(db.tickerTapeTypes).get();
  if (rows.isEmpty) {
    return buildTickerTypeConfigJsonMetaItems();
  }
  rows.sort((a, b) => a.tickerType.compareTo(b.tickerType));
  return [for (final row in rows) tickerTypeConfigJsonMetaItemFromRow(row)];
}

Future<List<Map<String, Object?>>> buildOverlayTypeConfigJsonMetaItemsFromDb(
  AppDatabase db,
) async {
  await ensureOverlayTypes(db);
  final rows = await db.select(db.overlayTypes).get();
  if (rows.isEmpty) {
    return buildOverlayTypeConfigJsonMetaItems();
  }
  rows.sort((a, b) => a.overlayType.compareTo(b.overlayType));
  return [for (final row in rows) overlayTypeConfigJsonMetaItemFromRow(row)];
}

Future<List<Map<String, Object?>>> buildIntegrationTypeConfigJsonMetaItemsFromDb(
  AppDatabase db,
) async {
  final rows = await db.select(db.integrationTypes).get();
  if (rows.isEmpty) {
    return buildIntegrationTypeConfigJsonMetaItems();
  }
  rows.sort((a, b) => a.integrationType.compareTo(b.integrationType));
  return [for (final row in rows) integrationTypeConfigJsonMetaItemFromRow(row)];
}

/// Canonical bundled config-json documentation for operator clients.
Map<String, Object?> buildConfigJsonSchemasBundle() => {
      'screen_types': buildScreenTypeConfigJsonMetaItems(),
      'ticker_tape_types': buildTickerTypeConfigJsonMetaItems(),
      'overlay_types': buildOverlayTypeConfigJsonMetaItems(),
      'integration_types': buildIntegrationTypeConfigJsonMetaItems(),
      'kv_widget_types': buildKvWidgetTypeConfigJsonMetaItems(),
      'kv_value_data_types': buildKvValueDataTypeMetaItems(),
    };

/// Like [buildConfigJsonSchemasBundle] but reads type docs from SQLite when present.
Future<Map<String, Object?>> buildConfigJsonSchemasBundleFromDb(
  AppDatabase db,
) async {
  return {
    'screen_types': await buildScreenTypeConfigJsonMetaItemsFromDb(db),
    'ticker_tape_types': await buildTickerTypeConfigJsonMetaItemsFromDb(db),
    'overlay_types': await buildOverlayTypeConfigJsonMetaItemsFromDb(db),
    'integration_types': await buildIntegrationTypeConfigJsonMetaItemsFromDb(db),
    'kv_widget_types': buildKvWidgetTypeConfigJsonMetaItems(),
    'kv_value_data_types': buildKvValueDataTypeMetaItems(),
  };
}
