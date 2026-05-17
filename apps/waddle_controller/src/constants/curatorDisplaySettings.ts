export type CuratorThemeOption = {
  id: string;
  label: string;
  /** Hex colors shown in the theme picker (source palette order). */
  colors: readonly string[];
};

/** Preview swatches mirror `apps/waddle_display/lib/theme/config/palettes/`. */
export const curatorThemeIds: readonly CuratorThemeOption[] = [
  {
    id: 'navy_coral',
    label: 'Navy / coral (default)',
    colors: [
      '#0D1B2A',
      '#1B263B',
      '#415A77',
      '#778DA9',
      '#E0E1DD',
      '#83AF84',
      '#E05C6C',
      '#FFE356',
      '#966CB3',
    ],
  },
  {
    id: 'graphite_amber',
    label: 'Graphite / amber',
    colors: ['#121214', '#2A2A2E', '#78716C', '#F59E0B', '#F5F5F4'],
  },
  {
    id: 'teal_gold_sunset',
    label: 'Teal & gold sunset',
    colors: ['#264653', '#2A9D8F', '#E9C46A', '#F4A261', '#E76F51'],
  },
  {
    id: 'ocean_depth',
    label: 'Ocean depth',
    colors: ['#03045E', '#0077B6', '#00B4D8', '#90E0EF', '#CAF0F8'],
  },
  {
    id: 'forest_cream',
    label: 'Forest & cream',
    colors: ['#606C38', '#283618', '#FEFAE0', '#DDA15E', '#BC6C25'],
  },
  {
    id: 'heritage_coast',
    label: 'Heritage coast',
    colors: ['#780000', '#C1121F', '#FDF0D5', '#003049', '#669BBC'],
  },
  {
    id: 'plum_ember',
    label: 'Plum ember',
    colors: ['#5F0F40', '#9A031E', '#FB8B24', '#E36414', '#0F4C5C'],
  },
  {
    id: 'slate_crimson',
    label: 'Slate & crimson',
    colors: ['#2B2D42', '#8D99AE', '#EDF2F4', '#EF233C', '#D90429'],
  },
  {
    id: 'wine_ember',
    label: 'Wine ember',
    colors: ['#03071E', '#370617', '#6A040F', '#9D0208', '#D00000'],
  },
  {
    id: 'dopamine_pop',
    label: 'Dopamine pop',
    colors: ['#FF006E', '#FB5607', '#FFBE0B', '#8338EC', '#3A86FF'],
  },
  {
    id: 'sage_wellness',
    label: 'Sage wellness',
    colors: ['#9CAF88', '#CDD5AE', '#FEFEE3', '#F2E8C6', '#BBC2A0'],
  },
  {
    id: 'warm_minimal',
    label: 'Warm minimal',
    colors: ['#F7F1E8', '#E8B577', '#D2691E', '#8B4513', '#2F1B14'],
  },
];

/** UI slider bounds for curator timing fields (defaults match display seed). */
export const CURATOR_PROGRAM_DURATION = {
  min: 30,
  max: 600,
  step: 15,
  default: 180,
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

export type CuratorDisplaySettings = {
  program_duration_seconds: number;
  history_depth: number;
  ticker_pixels_per_second: string;
  require_news_photo_for_screens: boolean;
  display_theme_id: string;
  display_text_scale_screen: string;
  display_text_scale_ticker: string;
  /** IANA id from `display.timezone` (e.g. `America/Chicago`). */
  display_timezone: string;
  /** Roles that may start adoption challenges (`viewer`, `power_viewer`, `operator`, `admin`). */
  adoption_allowed_roles?: string[];
  /** @deprecated Use `adoption_allowed_roles`; true when that list is non-empty. */
  adoption_allow_new_requests?: boolean;
};

export const ADOPTION_ROLES = [
  { value: 'viewer', label: 'Viewer' },
  { value: 'power_viewer', label: 'Power viewer' },
  { value: 'operator', label: 'Operator' },
  { value: 'admin', label: 'Admin' },
] as const;

export function parseAdoptionAllowedRoles(settings: CuratorDisplaySettings): Set<string> {
  if (Array.isArray(settings.adoption_allowed_roles)) {
    return new Set(
      settings.adoption_allowed_roles.filter(
        (r): r is string => typeof r === 'string' && r.trim() !== '',
      ),
    );
  }
  if (settings.adoption_allow_new_requests === false) {
    return new Set();
  }
  return new Set(ADOPTION_ROLES.map((r) => r.value));
}

export function curatorThemeById(id: string): CuratorThemeOption | undefined {
  return curatorThemeIds.find((t) => t.id === id);
}
