import {
  displayThemePreviewById,
  flattenDisplayThemePreview,
  type DisplayThemePreviewGroups,
} from './displayThemePreview';

export type CuratorThemeOption = {
  id: string;
  label: string;
  /** Flat hex list (deduped preview colors). */
  colors: readonly string[];
  /** Grouped swatches: display → slide → ticker → accents. */
  preview: DisplayThemePreviewGroups;
};

function themeOption(id: string, label: string): CuratorThemeOption {
  const preview = displayThemePreviewById[id];
  if (!preview) {
    throw new Error(`Missing displayThemePreviewById for ${id}`);
  }
  return {
    id,
    label,
    preview,
    colors: flattenDisplayThemePreview(preview),
  };
}

export const curatorThemeIds: readonly CuratorThemeOption[] = [
  themeOption('navy_coral', 'Navy / coral (default)'),
  themeOption('graphite_amber', 'Graphite / amber'),
  themeOption('teal_gold_sunset', 'Teal & gold sunset'),
  themeOption('ocean_depth', 'Ocean depth'),
  themeOption('forest_cream', 'Forest & cream'),
  themeOption('heritage_coast', 'Heritage coast'),
  themeOption('plum_ember', 'Plum ember'),
  themeOption('slate_crimson', 'Slate & crimson'),
  themeOption('wine_ember', 'Wine ember'),
  themeOption('dopamine_pop', 'Dopamine pop'),
  themeOption('sage_wellness', 'Sage wellness'),
  themeOption('warm_minimal', 'Warm minimal'),
];

/** Default sort order for new curator configurations (matches display POST default). */
export const CURATOR_SORT_ORDER = {
  default: 100,
} as const;

/** UI slider bounds for curator timing fields (defaults match display seed). */
export const CURATOR_PROGRAM_DURATION = {
  min: 30,
  max: 600,
  step: 15,
  default: 180,
} as const;

export const CURATOR_TICKER_PROGRAM_DURATION = {
  min: 30,
  max: 1800,
  step: 15,
  default: 300,
} as const;

export const CURATOR_HISTORY_DEPTH = {
  min: 1,
  max: 10,
  step: 1,
  default: 5,
} as const;

export const CURATOR_TICKER_PIXELS_PER_SECOND = {
  min: 20,
  max: 140,
  step: 5,
  default: 80,
} as const;

/** Viewport edge reserve while curator is active (percent per side). */
export const VIEWPORT_RESERVE_PCT = {
  min: 0,
  max: 50,
  step: 1,
  default: 0,
} as const;

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function parseTickerPixelsPerSecond(raw: string | number): number {
  const parsed =
    typeof raw === 'number' ? raw : Number.parseInt(String(raw).trim(), 10);
  if (!Number.isFinite(parsed)) {
    return CURATOR_TICKER_PIXELS_PER_SECOND.default;
  }
  return clampNumber(
    parsed,
    CURATOR_TICKER_PIXELS_PER_SECOND.min,
    CURATOR_TICKER_PIXELS_PER_SECOND.max,
  );
}

export const curatorTextScaleIds = [
  'xxx-small',
  'xx-small',
  'x-small',
  'smaller',
  'small',
  'normal',
  'large',
  'larger',
  'x-large',
  'xx-large',
  'xxx-large',
];

/** @deprecated Legacy combined curator + display settings shape. */
export type CuratorDisplaySettings = {
  program_duration_seconds?: number;
  history_depth?: number;
  ticker_pixels_per_second?: number;
  require_news_photo_for_screens?: boolean;
};

export function curatorThemeById(id: string): CuratorThemeOption | undefined {
  return curatorThemeIds.find((t) => t.id === id);
}
