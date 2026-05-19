const SECONDS_PER_MINUTE = 60;
const SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE;
const SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR;
/** Fixed 30-day month for operator-facing poll interval labels. */
const SECONDS_PER_MONTH = 30 * SECONDS_PER_DAY;

function unitLabel(value: number, singular: string, plural: string): string {
  return `${value} ${value === 1 ? singular : plural}`;
}

/** Human-readable poll interval (stored value is seconds). */
export function formatPollInterval(seconds: number): string {
  let remaining = Math.max(0, Math.round(seconds));
  const parts: string[] = [];

  const months = Math.floor(remaining / SECONDS_PER_MONTH);
  remaining %= SECONDS_PER_MONTH;
  const days = Math.floor(remaining / SECONDS_PER_DAY);
  remaining %= SECONDS_PER_DAY;
  const hours = Math.floor(remaining / SECONDS_PER_HOUR);
  remaining %= SECONDS_PER_HOUR;
  const minutes = Math.floor(remaining / SECONDS_PER_MINUTE);
  remaining %= SECONDS_PER_MINUTE;

  if (months > 0) {
    parts.push(unitLabel(months, 'month', 'months'));
  }
  if (days > 0) {
    parts.push(unitLabel(days, 'day', 'days'));
  }
  if (hours > 0) {
    parts.push(unitLabel(hours, 'hour', 'hours'));
  }
  if (minutes > 0) {
    parts.push(unitLabel(minutes, 'minute', 'minutes'));
  }
  if (remaining > 0 || parts.length === 0) {
    parts.push(unitLabel(remaining, 'second', 'seconds'));
  }

  return parts.join(' ');
}
