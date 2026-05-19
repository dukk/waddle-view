import 'dart:convert';

import 'config_json_documentation.dart';
import 'tables.dart';

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
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> tickerTypeConfigJsonMetaItem(String tickerType) {
  final doc = tickerSlotConfigJsonDocForType(tickerType);
  return {
    'ticker_type': tickerType,
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> overlayTypeConfigJsonMetaItem(String overlayType) {
  final doc = displayOverlayConfigJsonDocForType(overlayType);
  return {
    'overlay_type': overlayType,
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
    'example_config_json': decodeConfigJsonDocField(doc.example),
  };
}

Map<String, Object?> integrationTypeConfigJsonMetaItem(String integrationType) {
  final doc = providerConfigJsonDocForType(integrationType);
  return {
    'integration_type': integrationType,
    'config_json_schema': decodeConfigJsonDocField(doc.schema),
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

/// Canonical bundled config-json documentation for operator clients.
Map<String, Object?> buildConfigJsonSchemasBundle() => {
      'screen_types': buildScreenTypeConfigJsonMetaItems(),
      'ticker_types': buildTickerTypeConfigJsonMetaItems(),
      'overlay_types': buildOverlayTypeConfigJsonMetaItems(),
      'integration_types': buildIntegrationTypeConfigJsonMetaItems(),
    };
