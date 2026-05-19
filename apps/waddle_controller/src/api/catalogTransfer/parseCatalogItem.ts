import type {
  CatalogKind,
  CatalogListItem,
  CatalogPayload,
  OverlayCatalogPayload,
  ScreenCatalogPayload,
  TickerCatalogPayload,
} from './types';

function readOptionalString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function readNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function readOptionalNumber(value: unknown): number | null {
  if (value == null) return null;
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function parseConfigJson(raw: unknown): unknown {
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw) as unknown;
    } catch {
      return {};
    }
  }
  if (raw != null && typeof raw === 'object') {
    return raw;
  }
  return {};
}

export function catalogListItemFromRaw(
  kind: CatalogKind,
  raw: Record<string, unknown>,
): CatalogListItem | null {
  const id = readOptionalString(raw.id);
  if (!id) return null;
  const label =
    readOptionalString(raw.label) ||
    readOptionalString(raw.name) ||
    id;
  if (kind === 'overlay' && !readOptionalString(raw.overlay_type ?? raw.overlay_kind)) {
    return null;
  }
  if (kind === 'screen' && !readOptionalString(raw.screen_type)) {
    return null;
  }
  if (kind === 'ticker' && !readOptionalString(raw.ticker_type)) {
    return null;
  }
  return { id, label };
}

export function parseCatalogPayload(
  kind: CatalogKind,
  raw: Record<string, unknown>,
): CatalogPayload | null {
  switch (kind) {
    case 'screen':
      return parseScreenPayload(raw);
    case 'overlay':
      return parseOverlayPayload(raw);
    case 'ticker':
      return parseTickerPayload(raw);
  }
}

function parseScreenPayload(raw: Record<string, unknown>): ScreenCatalogPayload | null {
  const id = readOptionalString(raw.id);
  const screenType = readOptionalString(raw.screen_type);
  if (!id || !screenType) return null;
  return {
    kind: 'screen',
    id,
    screen_type: screenType,
    label: readOptionalString(raw.label) || readOptionalString(raw.name) || id,
    description: readOptionalString(raw.description),
    config_json: parseConfigJson(raw.config_json),
    min_dwell_seconds: readNumber(raw.min_dwell_seconds, 8),
    max_dwell_seconds: readNumber(raw.max_dwell_seconds, 15),
    frequency_weight: readNumber(raw.frequency_weight, 100),
    min_gap_between_shows_seconds: readNumber(raw.min_gap_between_shows_seconds),
    min_placements_per_program: readNumber(raw.min_placements_per_program),
    max_placements_per_program: readOptionalNumber(raw.max_placements_per_program),
    data_key: readOptionalString(raw.data_key),
  };
}

function parseOverlayPayload(raw: Record<string, unknown>): OverlayCatalogPayload | null {
  const id = readOptionalString(raw.id);
  const overlayType =
    readOptionalString(raw.overlay_type) || readOptionalString(raw.overlay_kind);
  const label =
    readOptionalString(raw.label) || readOptionalString(raw.name) || id;
  if (!id || !overlayType) return null;
  return {
    kind: 'overlay',
    id,
    overlay_type: overlayType,
    label,
    config_json: parseConfigJson(raw.config_json),
  };
}

function parseTickerPayload(raw: Record<string, unknown>): TickerCatalogPayload | null {
  const id = readOptionalString(raw.id);
  const tickerType = readOptionalString(raw.ticker_type);
  if (!id || !tickerType) return null;
  return {
    kind: 'ticker',
    id,
    ticker_type: tickerType,
    label: readOptionalString(raw.label) || readOptionalString(raw.name) || id,
    description: readOptionalString(raw.description),
    frequency_weight: readNumber(raw.frequency_weight, 100),
    sort_order: readNumber(raw.sort_order),
    config_json: parseConfigJson(raw.config_json),
  };
}
