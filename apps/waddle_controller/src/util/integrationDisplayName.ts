/**
 * Human-facing integration titles keyed by API `integration_type`
 * (matches SQLite `integrations.provider_type`).
 */
const INTEGRATION_TYPE_TITLES: Record<string, string> = {
  stub: 'Stub',
  news_rss: 'RSS News',
  media_pexels: 'Pexels Media',
  weather_openweathermap: 'OpenWeatherMap Weather',
  weather_nws_alerts: 'NWS Weather Alerts',
  joke_openai: 'OpenAI Jokes',
  trivia_openai: 'OpenAI Trivia',
  trivia_opentdb: 'OpenTDB Trivia',
  stock_finnhub: 'Finnhub Stock',
  home_assistant: 'Home Assistant',
  calendar_outlook: 'Outlook Calendar',
  calendar_google: 'Google Calendar',
  google_calendar: 'Google Calendar',
  media_onedrive: 'OneDrive Media',
  media_flickr: 'Flickr Media',
  media_bing_iotd: 'Bing Image of the Day',
};

/** Token segments inside `integration_type` after splitting on `_`. */
const WORD_DISPLAY: Record<string, string> = {
  rss: 'RSS',
  nws: 'NWS',
  api: 'API',
  iotd: 'IOTD',
  onedrive: 'OneDrive',
  openai: 'OpenAI',
  openweathermap: 'OpenWeatherMap',
  opentdb: 'OpenTDB',
  finnhub: 'Finnhub',
  google: 'Google',
  outlook: 'Outlook',
  pexels: 'Pexels',
  flickr: 'Flickr',
  bing: 'Bing',
};

function capitalizeToken(word: string): string {
  if (word.length === 0) return word;
  const lower = word.toLowerCase();
  if (WORD_DISPLAY[lower]) return WORD_DISPLAY[lower]!;
  return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
}

/** For unknown types: reverse `a_b_c` → "C B A" with per-token capitalization (e.g. `foo_bar` → "Bar Foo"). */
function titleFromReversedSegments(integrationType: string): string {
  const parts = integrationType.split('_').filter((s) => s.length > 0);
  if (parts.length === 0) return integrationType;
  if (parts.length === 1) return capitalizeToken(parts[0]!);
  return [...parts].reverse().map(capitalizeToken).join(' ');
}

/** Normalized label for cards and dialogs; does not expose row `id`. */
export function integrationDisplayName(integrationType: string): string {
  const key = integrationType.trim();
  if (!key) return 'Integration';
  const mapped = INTEGRATION_TYPE_TITLES[key];
  if (mapped) return mapped;
  return titleFromReversedSegments(key);
}
