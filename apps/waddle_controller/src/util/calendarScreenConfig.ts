import type { ControllerTimeFormat } from '@/constants/displaySettings';

export function upcomingTime12HourFromControllerFormat(
  timeFormat: ControllerTimeFormat,
): boolean {
  return timeFormat === '12h';
}

/** Defaults for new or incomplete calendar_month screen config. */
export function applyCalendarMonthDefaults(
  config: Record<string, unknown>,
  timeFormat: ControllerTimeFormat,
): Record<string, unknown> {
  const out = { ...config };
  if (out.hidePastEvents === undefined) {
    out.hidePastEvents = true;
  }
  if (out.upcomingTime12Hour === undefined) {
    out.upcomingTime12Hour = upcomingTime12HourFromControllerFormat(timeFormat);
  }
  return out;
}
