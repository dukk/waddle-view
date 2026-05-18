import type { ControllerDateOrder, DateTimeFormatPrefs } from '@/constants/displaySettings';
import {
  DEFAULT_CONTROLLER_DATE_ORDER,
  DEFAULT_CONTROLLER_TIME_FORMAT,
} from '@/constants/displaySettings';

export type { DateTimeFormatPrefs } from '@/constants/displaySettings';

export function dateTimeFormatPrefsFromDisplaySettings(settings: {
  controller_time_format?: unknown;
  controller_date_order?: unknown;
} | null | undefined): DateTimeFormatPrefs {
  if (!settings) {
    return {
      timeFormat: DEFAULT_CONTROLLER_TIME_FORMAT,
      dateOrder: DEFAULT_CONTROLLER_DATE_ORDER,
    };
  }
  const timeFormat =
    settings.controller_time_format === '24h' ? '24h' : DEFAULT_CONTROLLER_TIME_FORMAT;
  let dateOrder: ControllerDateOrder = DEFAULT_CONTROLLER_DATE_ORDER;
  const rawOrder = settings.controller_date_order;
  if (rawOrder === 'dmy' || rawOrder === 'ymd') {
    dateOrder = rawOrder;
  }
  return { timeFormat, dateOrder };
}

function localeForDateOrder(order: ControllerDateOrder): string {
  switch (order) {
    case 'dmy':
      return 'en-GB';
    case 'ymd':
      return 'sv-SE';
    default:
      return 'en-US';
  }
}

function intlOptions(prefs: DateTimeFormatPrefs): { locale: string; hour12: boolean } {
  return {
    locale: localeForDateOrder(prefs.dateOrder),
    hour12: prefs.timeFormat === '12h',
  };
}

export function formatControllerDate(d: Date, prefs: DateTimeFormatPrefs): string {
  const { locale } = intlOptions(prefs);
  return new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(d);
}

export function formatControllerTime(d: Date, prefs: DateTimeFormatPrefs): string {
  const { locale, hour12 } = intlOptions(prefs);
  return new Intl.DateTimeFormat(locale, {
    hour: 'numeric',
    minute: '2-digit',
    hour12,
  }).format(d);
}

export function formatControllerDateTime(d: Date, prefs: DateTimeFormatPrefs): string {
  const { locale, hour12 } = intlOptions(prefs);
  return new Intl.DateTimeFormat(locale, {
    dateStyle: 'medium',
    timeStyle: 'short',
    hour12,
  }).format(d);
}

export function formatControllerDateTimeWithMs(d: Date, prefs: DateTimeFormatPrefs): string {
  const { locale, hour12 } = intlOptions(prefs);
  try {
    return new Intl.DateTimeFormat(locale, {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      fractionalSecondDigits: 3,
      hour12,
    }).format(d);
  } catch {
    return formatControllerDateTime(d, prefs);
  }
}

export function formatControllerTimestamp(
  atMs: unknown,
  prefs: DateTimeFormatPrefs,
): string {
  const n = typeof atMs === 'number' ? atMs : Number(atMs);
  if (!Number.isFinite(n)) return 'Unknown time';
  return formatControllerDateTime(new Date(n), prefs);
}
