/**
 * Returns true when [cronExpr] (five-field, daily-only `M H * * *`) matches [now] in [timeZone].
 */
export function isDailyCronDue(
  cronExpr: string,
  timeZone: string,
  now: Date = new Date(),
): boolean {
  const parts = cronExpr.trim().split(/\s+/);
  if (parts.length !== 5) {
    return false;
  }
  const [minutePart, hourPart, dom, month, dow] = parts;
  if (dom !== '*' || month !== '*' || dow !== '*') {
    return false;
  }
  const wantMinute = Number.parseInt(minutePart, 10);
  const wantHour = Number.parseInt(hourPart, 10);
  if (!Number.isFinite(wantMinute) || !Number.isFinite(wantHour)) {
    return false;
  }
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: timeZone || 'UTC',
    hour: 'numeric',
    minute: 'numeric',
    hour12: false,
  });
  const tokens = fmt.formatToParts(now);
  const hour = Number.parseInt(tokens.find((t) => t.type === 'hour')?.value ?? '', 10);
  const minute = Number.parseInt(tokens.find((t) => t.type === 'minute')?.value ?? '', 10);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) {
    return false;
  }
  return hour === wantHour && minute === wantMinute;
}
