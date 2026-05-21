export type ControllerTimeFormat = '12h' | '24h';
export type ControllerDateOrder = 'mdy' | 'dmy' | 'ymd';

export type DateTimeFormatPrefs = {
  timeFormat: ControllerTimeFormat;
  dateOrder: ControllerDateOrder;
};

export type DisplaySettings = {
  display_theme_id: string;
  /** Max screen programs for back-nav; shared across all curator configurations. */
  display_program_history_depth: number;
  display_text_scale_screen: string;
  display_text_scale_ticker: string;
  /** IANA id from `display.timezone` (e.g. `America/Chicago`). */
  display_timezone: string;
  /** Percent of letterboxed viewport reserved on each edge (0–50). */
  display_viewport_reserve_top_pct: number;
  display_viewport_reserve_right_pct: number;
  display_viewport_reserve_bottom_pct: number;
  display_viewport_reserve_left_pct: number;
  /** RSS scroll budget for ticker curation (seconds). */
  display_ticker_program_duration_seconds: number;
  /** Bottom marquee scroll speed (pixels per second). */
  display_ticker_pixels_per_second: number;
  controller_time_format: ControllerTimeFormat;
  controller_date_order: ControllerDateOrder;
  /** Roles that may start adoption challenges. */
  adoption_allowed_roles?: string[];
  /** @deprecated Use `adoption_allowed_roles`; true when that list is non-empty. */
  adoption_allow_new_requests?: boolean;
};

export const DEFAULT_CONTROLLER_TIME_FORMAT: ControllerTimeFormat = '12h';
export const DEFAULT_CONTROLLER_DATE_ORDER: ControllerDateOrder = 'mdy';

export const CONTROLLER_TIME_FORMAT_OPTIONS = [
  { value: '12h' as const, label: '12-hour (AM/PM)' },
  { value: '24h' as const, label: '24-hour' },
] as const;

export const CONTROLLER_DATE_ORDER_OPTIONS = [
  { value: 'mdy' as const, label: 'Month / day / year (e.g. Jan 5, 2026)' },
  { value: 'dmy' as const, label: 'Day / month / year (e.g. 5 Jan 2026)' },
  { value: 'ymd' as const, label: 'Year / month / day (e.g. 2026-01-05)' },
] as const;

export const ADOPTION_ROLES = [
  { value: 'viewer', label: 'Viewer' },
  { value: 'power_viewer', label: 'Power viewer' },
  { value: 'operator', label: 'Operator' },
  { value: 'admin', label: 'Admin' },
] as const;

export function parseAdoptionAllowedRoles(settings: Pick<DisplaySettings, 'adoption_allowed_roles' | 'adoption_allow_new_requests'>): Set<string> {
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

export function normalizeControllerTimeFormat(raw: unknown): ControllerTimeFormat {
  const s = typeof raw === 'string' ? raw.trim().toLowerCase() : '';
  return s === '24h' || s === '24' ? '24h' : DEFAULT_CONTROLLER_TIME_FORMAT;
}

export function normalizeControllerDateOrder(raw: unknown): ControllerDateOrder {
  const s = typeof raw === 'string' ? raw.trim().toLowerCase() : '';
  if (s === 'dmy') return 'dmy';
  if (s === 'ymd') return 'ymd';
  return DEFAULT_CONTROLLER_DATE_ORDER;
}
