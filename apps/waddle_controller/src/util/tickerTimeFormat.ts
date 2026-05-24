import type {
  ControllerTimeFormat,
  DateTimeFormatPrefs,
} from '@/constants/displaySettings';
import { formatControllerDateTime } from '@/util/dateTimeFormat';

/** Sample instant for ticker format preview labels. */
const TICKER_FORMAT_PREVIEW_DATE = new Date('2026-05-04T14:05:00');

/** Live marquee preset with seconds for the given display time format. */
export function tickerTimeFormatPresetForControllerTimeFormat(
  format: ControllerTimeFormat,
): string {
  return format === '24h' ? '24h_hms' : '12h_hms_ampm';
}

/** Human-readable preview when the tape follows Display settings date + time. */
export function tickerDisplayDefaultDateTimeLabel(prefs: DateTimeFormatPrefs): string {
  return formatControllerDateTime(TICKER_FORMAT_PREVIEW_DATE, prefs);
}

const PRESET_LABELS: Record<string, string> = {
  '24h_hms': '24-hour with seconds (14:05:09)',
  '24h_hm': '24-hour (14:05)',
  '12h_hms_ampm': '12-hour with seconds (2:05:09 PM)',
  '12h_hm_ampm': '12-hour (2:05 PM)',
  '12h_hm_tt': '12-hour compact (2:05pm)',
};

export function tickerTimeFormatPresetLabel(preset: string): string {
  return PRESET_LABELS[preset] ?? preset;
}
