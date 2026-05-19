const STORAGE_PREFIX = 'waddle_controller_config_schemas_v1:';

export type ConfigSchemaMetaItem = {
  config_json_schema?: unknown;
  example_config_json?: unknown;
};

export type ScreenTypeSchemaMeta = ConfigSchemaMetaItem & {
  screen_type: string;
};

export type TickerTypeSchemaMeta = ConfigSchemaMetaItem & {
  ticker_type: string;
};

export type OverlayTypeSchemaMeta = ConfigSchemaMetaItem & {
  overlay_type: string;
};

export type IntegrationTypeSchemaMeta = ConfigSchemaMetaItem & {
  integration_type: string;
};

export type ConfigSchemasBundle = {
  screen_types: ScreenTypeSchemaMeta[];
  ticker_types: TickerTypeSchemaMeta[];
  overlay_types: OverlayTypeSchemaMeta[];
  integration_types: IntegrationTypeSchemaMeta[];
};

function storageKey(displayId: string): string {
  return `${STORAGE_PREFIX}${displayId}`;
}

export function loadConfigSchemas(displayId: string): ConfigSchemasBundle | null {
  try {
    const raw = localStorage.getItem(storageKey(displayId));
    if (!raw) {
      return null;
    }
    const parsed = JSON.parse(raw) as ConfigSchemasBundle;
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    return {
      screen_types: Array.isArray(parsed.screen_types) ? parsed.screen_types : [],
      ticker_types: Array.isArray(parsed.ticker_types) ? parsed.ticker_types : [],
      overlay_types: Array.isArray(parsed.overlay_types) ? parsed.overlay_types : [],
      integration_types: Array.isArray(parsed.integration_types)
        ? parsed.integration_types
        : [],
    };
  } catch {
    return null;
  }
}

export function saveConfigSchemas(displayId: string, bundle: ConfigSchemasBundle): void {
  localStorage.setItem(storageKey(displayId), JSON.stringify(bundle));
}

export function clearConfigSchemas(displayId: string): void {
  localStorage.removeItem(storageKey(displayId));
}

export function schemaForScreenType(
  bundle: ConfigSchemasBundle | null,
  screenType: string,
): unknown {
  return bundle?.screen_types.find((m) => m.screen_type === screenType)?.config_json_schema;
}

export function exampleForScreenType(
  bundle: ConfigSchemasBundle | null,
  screenType: string,
): unknown {
  return bundle?.screen_types.find((m) => m.screen_type === screenType)?.example_config_json;
}

export function schemaForTickerType(
  bundle: ConfigSchemasBundle | null,
  tickerType: string,
): unknown {
  return bundle?.ticker_types.find((m) => m.ticker_type === tickerType)?.config_json_schema;
}

export function exampleForTickerType(
  bundle: ConfigSchemasBundle | null,
  tickerType: string,
): unknown {
  return bundle?.ticker_types.find((m) => m.ticker_type === tickerType)?.example_config_json;
}

export function schemaForOverlayType(
  bundle: ConfigSchemasBundle | null,
  overlayType: string,
): unknown {
  return (
    bundle?.overlay_types.find((m) => m.overlay_type === overlayType)?.config_json_schema ?? {
      type: 'object',
      additionalProperties: true,
    }
  );
}

export function exampleForOverlayType(
  bundle: ConfigSchemasBundle | null,
  overlayType: string,
): unknown {
  return bundle?.overlay_types.find((m) => m.overlay_type === overlayType)?.example_config_json;
}

export function schemaForIntegrationType(
  bundle: ConfigSchemasBundle | null,
  integrationType: string,
): unknown {
  return bundle?.integration_types.find((m) => m.integration_type === integrationType)
    ?.config_json_schema;
}

export function exampleForIntegrationType(
  bundle: ConfigSchemasBundle | null,
  integrationType: string,
): unknown {
  return bundle?.integration_types.find((m) => m.integration_type === integrationType)
    ?.example_config_json;
}
