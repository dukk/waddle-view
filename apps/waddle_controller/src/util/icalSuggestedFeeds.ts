import {
  newIcalFeedId,
  type IcalFeedConfig,
} from '@/util/icalCalendarConfig';

export const kWebcalGuruSignupUrl =
  'https://www.webcal.guru/en-US/create_account';

export const kWebcalGuruSignupMessage =
  'Create a free WebCal.Guru account to browse more calendars, customize feeds, and manage subscriptions.';

export type IcalSuggestedFeed = {
  label: string;
  url: string;
};

function webcalGuruDownloadUrl(calendarInstanceId: number): string {
  return `https://www.webcal.guru/en-US/download_calendar?calendar_instance_id=${calendarInstanceId}`;
}

/** Built-in WebCal.Guru calendar shortcuts for the iCal integration form. */
export const ICAL_SUGGESTED_WEBCAL_GURU_FEEDS: readonly IcalSuggestedFeed[] = [
  { label: 'U.S. Election Calendar', url: webcalGuruDownloadUrl(28799) },
  { label: 'Awareness Days', url: webcalGuruDownloadUrl(10) },
  { label: 'Food and Drink Awareness', url: webcalGuruDownloadUrl(141) },
  { label: 'Funny Holidays', url: webcalGuruDownloadUrl(142) },
  { label: 'Good to Know', url: webcalGuruDownloadUrl(169) },
  { label: 'Word of the day', url: webcalGuruDownloadUrl(30326) },
  { label: 'Premiere movies', url: webcalGuruDownloadUrl(23593) },
  { label: 'U.S. Federal Holidays', url: webcalGuruDownloadUrl(41) },
  { label: 'National elections', url: webcalGuruDownloadUrl(22050) },
  { label: 'UN Observances', url: webcalGuruDownloadUrl(899) },
];

/** Normalizes feed URLs for duplicate detection (trim, lowercase, webcal→https). */
export function normalizeIcalFeedUrlForCompare(url: string): string {
  const trimmed = url.trim();
  if (!trimmed) return '';
  try {
    const normalized = trimmed.replace(/^webcal:\/\//i, 'https://');
    const parsed = new URL(normalized);
    const path = parsed.pathname.replace(/\/+$/, '') || '/';
    const search = parsed.search;
    return `${parsed.protocol}//${parsed.host.toLowerCase()}${path}${search}`.toLowerCase();
  } catch {
    return trimmed.toLowerCase();
  }
}

export function feedListHasUrl(feeds: IcalFeedConfig[], url: string): boolean {
  const key = normalizeIcalFeedUrlForCompare(url);
  if (!key) return false;
  return feeds.some((f) => normalizeIcalFeedUrlForCompare(f.url) === key);
}

export function feedFromSuggestion(
  suggestion: IcalSuggestedFeed,
  categoryId: string,
): IcalFeedConfig {
  return {
    id: newIcalFeedId(),
    url: suggestion.url,
    label: suggestion.label,
    categoryId,
  };
}
