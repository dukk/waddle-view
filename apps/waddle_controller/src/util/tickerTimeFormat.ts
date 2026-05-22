import type { ControllerTimeFormat } from '@/constants/displaySettings';

/** Live marquee preset with seconds for the given display time format. */
export function tickerTimeFormatPresetForControllerTimeFormat(
  format: ControllerTimeFormat,
): string {
  return format === '24h' ? '24h_hms' : '12h_hms_ampm';
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
