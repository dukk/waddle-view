export const curatorThemeIds = [
  { id: 'navy_coral', label: 'Navy / coral (default)' },
  { id: 'graphite_amber', label: 'Graphite / amber' },
];

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
};
