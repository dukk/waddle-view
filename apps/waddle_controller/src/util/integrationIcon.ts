import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CloudOutlinedIcon from '@mui/icons-material/CloudOutlined';
import ExtensionOutlinedIcon from '@mui/icons-material/ExtensionOutlined';
import NewspaperOutlinedIcon from '@mui/icons-material/NewspaperOutlined';
import PhotoOutlinedIcon from '@mui/icons-material/PhotoOutlined';
import QuizOutlinedIcon from '@mui/icons-material/QuizOutlined';
import RssFeedOutlinedIcon from '@mui/icons-material/RssFeedOutlined';
import SentimentSatisfiedAltOutlinedIcon from '@mui/icons-material/SentimentSatisfiedAltOutlined';
import TrendingUpOutlinedIcon from '@mui/icons-material/TrendingUpOutlined';
import type { SvgIconComponent } from '@mui/icons-material';

/** Brand logo via [Simple Icons CDN](https://simpleicons.org/). */
export type IntegrationSimpleIconsSource = {
  kind: 'simpleicons';
  slug: string;
  /** Optional hex without `#` (e.g. `4285F4`). */
  color?: string;
};

/** Favicon resolved from a service hostname (e.g. integration `base_url`). */
export type IntegrationFaviconSource = {
  kind: 'favicon';
  hostname: string;
};

/** Material icon when no brand asset is available. */
export type IntegrationMuiIconSource = {
  kind: 'mui';
  Icon: SvgIconComponent;
};

export type IntegrationIconSource =
  | IntegrationSimpleIconsSource
  | IntegrationFaviconSource
  | IntegrationMuiIconSource;

const SIMPLE_ICONS_BY_TYPE: Readonly<Record<string, IntegrationSimpleIconsSource>> = {
  calendar_google: { kind: 'simpleicons', slug: 'googlecalendar', color: '4285F4' },
  google_calendar: { kind: 'simpleicons', slug: 'googlecalendar', color: '4285F4' },
  calendar_outlook: { kind: 'simpleicons', slug: 'microsoftoutlook', color: '0078D4' },
  photo_onedrive: { kind: 'simpleicons', slug: 'microsoftonedrive', color: '0078D4' },
  video_onedrive: { kind: 'simpleicons', slug: 'microsoftonedrive', color: '0078D4' },
  photo_pexels: { kind: 'simpleicons', slug: 'pexels', color: '05A081' },
  video_pexels: { kind: 'simpleicons', slug: 'pexels', color: '05A081' },
  photo_flickr: { kind: 'simpleicons', slug: 'flickr', color: '0063DC' },
  photo_bing_image_of_the_day: { kind: 'simpleicons', slug: 'bing', color: '258FFA' },
  weather_openweathermap: { kind: 'simpleicons', slug: 'openweathermap', color: 'FF6600' },
  joke_openai: { kind: 'simpleicons', slug: 'openai' },
  trivia_openai: { kind: 'simpleicons', slug: 'openai' },
  stock_finnhub: { kind: 'simpleicons', slug: 'finnhub', color: '00B98F' },
  home_assistant: { kind: 'simpleicons', slug: 'homeassistant', color: '18BCF2' },
  news_rss: { kind: 'simpleicons', slug: 'rss', color: 'FFA500' },
};

const FAVICON_HOST_BY_TYPE: Readonly<Record<string, string>> = {
  weather_alerts_nws: 'weather.gov',
  trivia_opentdb: 'opentdb.com',
};

const MUI_ICON_BY_FAMILY: Readonly<Record<string, SvgIconComponent>> = {
  calendar: CalendarMonthOutlinedIcon,
  joke: SentimentSatisfiedAltOutlinedIcon,
  media: PhotoOutlinedIcon,
  news: NewspaperOutlinedIcon,
  stock: TrendingUpOutlinedIcon,
  trivia: QuizOutlinedIcon,
  weather: CloudOutlinedIcon,
  stub: ExtensionOutlinedIcon,
};

/** Provider `integration_type` prefix before the first `_` (e.g. `calendar_google` → `calendar`). */
export function integrationDataFamily(integrationType: string): string {
  const t = integrationType.trim();
  const u = t.indexOf('_');
  if (u <= 0) {
    return t.length > 0 ? t : 'other';
  }
  return t.slice(0, u);
}

function hostnameFromUrl(url: string): string | null {
  const trimmed = url.trim();
  if (!trimmed) return null;
  try {
    return new URL(trimmed).hostname || null;
  } catch {
    return null;
  }
}

/** Material icon for an integration when brand images are unavailable. */
export function integrationMuiIconSource(integrationType: string): IntegrationMuiIconSource {
  const key = integrationType.trim();
  if (key === 'news_rss') {
    return { kind: 'mui', Icon: RssFeedOutlinedIcon };
  }
  const family = integrationDataFamily(key);
  const Icon = MUI_ICON_BY_FAMILY[family] ?? ExtensionOutlinedIcon;
  return { kind: 'mui', Icon };
}

/**
 * Resolves how to render an integration logo: brand (Simple Icons / favicon) or MUI fallback.
 */
export function integrationIconSource(
  integrationType: string,
  baseUrl?: string | null,
): IntegrationIconSource {
  const key = integrationType.trim();
  const brand = SIMPLE_ICONS_BY_TYPE[key];
  if (brand) return brand;

  const faviconHost = FAVICON_HOST_BY_TYPE[key];
  if (faviconHost) {
    return { kind: 'favicon', hostname: faviconHost };
  }

  const fromBase = baseUrl != null ? hostnameFromUrl(baseUrl) : null;
  if (fromBase) {
    return { kind: 'favicon', hostname: fromBase };
  }

  return integrationMuiIconSource(key);
}

/** Image URL for brand/favicon sources; `null` for pure MUI fallbacks. */
export function integrationIconImageUrl(source: IntegrationIconSource): string | null {
  if (source.kind === 'simpleicons') {
    const base = `https://cdn.simpleicons.org/${encodeURIComponent(source.slug)}`;
    return source.color ? `${base}/${source.color}` : base;
  }
  if (source.kind === 'favicon') {
    return `https://www.google.com/s2/favicons?domain=${encodeURIComponent(source.hostname)}&sz=64`;
  }
  return null;
}
