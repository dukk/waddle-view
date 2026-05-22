const MIN_EXPIRE_MINUTES = 1;
const MAX_EXPIRE_MINUTES = 10_080; // 7 days

/** Parses a positive integer minute count for manual alert expiry, or null if invalid. */
export function parseAlertExpireMinutes(raw: string): number | null {
  const trimmed = raw.trim();
  if (!trimmed || !/^\d+$/.test(trimmed)) return null;
  const minutes = Number(trimmed);
  if (!Number.isFinite(minutes) || minutes < MIN_EXPIRE_MINUTES || minutes > MAX_EXPIRE_MINUTES) {
    return null;
  }
  return minutes;
}

export function alertExpiresAtMs(minutes: number, nowMs = Date.now()): number {
  return nowMs + minutes * 60_000;
}

export function alertExpireMinutesError(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return 'Expire in minutes is required.';
  const minutes = parseAlertExpireMinutes(raw);
  if (minutes == null) {
    return `Enter ${MIN_EXPIRE_MINUTES}–${MAX_EXPIRE_MINUTES} minutes.`;
  }
  return null;
}
