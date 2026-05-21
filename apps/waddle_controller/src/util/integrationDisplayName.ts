/**
 * Human-facing integration titles keyed by API `integration_type`
 * (matches SQLite `integrations.integration_type`).
 */
const INTEGRATION_TYPE_TITLES: Record<string, string> = {
  stub: 'Stub',
  news_rss: 'RSS News',
  photo_pexels: 'Pexels Photos',
  video_pexels: 'Pexels Videos',
  weather_openweathermap: 'OpenWeatherMap Weather',
  weather_openmeteo: 'Open-Meteo Weather',
  air_quality_openmeteo: 'Open-Meteo Air Quality',
  weather_alerts_nws: 'NWS Weather Alerts',
  joke_openai: 'OpenAI Jokes',
  general_openai: 'OpenAI General',
  trivia_openai: 'OpenAI Trivia',
  trivia_opentdb: 'OpenTDB Trivia',
  stock_finnhub: 'Finnhub Stock',
  home_assistant: 'Home Assistant',
  calendar_outlook: 'Outlook Calendar',
  calendar_google: 'Google Calendar',
  calendar_ical: 'iCal / ICS Calendar',
  calendar_mealviewer: 'MealViewer School Menus',
  google_calendar: 'Google Calendar',
  photo_onedrive: 'OneDrive Photos',
  video_onedrive: 'OneDrive Videos',
  photo_flickr: 'Flickr Photos',
  photo_bing_image_of_the_day: 'Bing Image of the Day',
  photo_nasa_apod: 'NASA APOD',
  photo_nasa_mars_rover: 'NASA Mars Rover Photos',
  photo_nasa_earth_imagery: 'NASA Earth Imagery',
  quote_quoterism: 'Quoterism Quotes',
  manual_entry: 'Manual entry',
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
  openmeteo: 'Open-Meteo',
  opentdb: 'OpenTDB',
  finnhub: 'Finnhub',
  google: 'Google',
  outlook: 'Outlook',
  pexels: 'Pexels',
  flickr: 'Flickr',
  bing: 'Bing',
  nasa: 'NASA',
  apod: 'APOD',
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
export function integrationDisplayName(
  integrationType: string,
  apiLabel?: string | null,
): string {
  const fromApi = apiLabel?.trim();
  if (fromApi) return fromApi;
  const key = integrationType.trim();
  if (!key) return 'Integration';
  const mapped = INTEGRATION_TYPE_TITLES[key];
  if (mapped) return mapped;
  return titleFromReversedSegments(key);
}
