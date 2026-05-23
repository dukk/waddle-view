import { formatPollInterval } from '@/util/pollIntervalFormat';

export type DurationUnit = 'sec' | 'min' | 'hr' | 'day';

export const DURATION_UNIT_SECONDS: Record<DurationUnit, number> = {
  sec: 1,
  min: 60,
  hr: 3600,
  day: 86400,
};

export function durationUnitLabel(unit: DurationUnit): string {
  switch (unit) {
    case 'sec':
      return 'Seconds';
    case 'min':
      return 'Minutes';
    case 'hr':
      return 'Hours';
    case 'day':
      return 'Days';
  }
}

/** Operator-facing interval label (stored value is seconds). */
export function formatIntervalDisplay(seconds: number): string {
  return formatPollInterval(seconds);
}

/** Resolves the unit dropdown default: [preferred] when allowed, else heuristic. */
export function resolveDurationUnit(
  totalSeconds: number,
  allowedUnits: readonly DurationUnit[],
  preferred?: DurationUnit,
): DurationUnit {
  const units = allowedUnits.length > 0 ? allowedUnits : (['sec'] as const);
  if (preferred != null && units.includes(preferred)) {
    return preferred;
  }
  return defaultDurationUnit(totalSeconds, units);
}

/** Picks a sensible default unit for displaying [totalSeconds]. */
export function defaultDurationUnit(
  totalSeconds: number,
  allowedUnits: readonly DurationUnit[],
): DurationUnit {
  const units = allowedUnits.length > 0 ? allowedUnits : (['sec'] as const);
  const abs = Math.max(0, Math.round(totalSeconds));
  if (units.includes('day') && abs >= 86400 && abs % 86400 === 0) return 'day';
  if (units.includes('hr') && abs >= 3600 && abs % 3600 === 0) return 'hr';
  if (units.includes('min') && abs >= 60 && abs % 60 === 0) return 'min';
  if (units.includes('sec')) return 'sec';
  return units[0]!;
}

export function secondsToDurationParts(
  totalSeconds: number,
  unit: DurationUnit,
): { amount: number; unit: DurationUnit } {
  const divisor = DURATION_UNIT_SECONDS[unit];
  const abs = Math.max(0, Math.round(totalSeconds));
  return { amount: divisor > 0 ? abs / divisor : abs, unit };
}

export function durationPartsToSeconds(amount: number, unit: DurationUnit): number {
  if (!Number.isFinite(amount)) return 0;
  return Math.max(0, Math.round(amount * DURATION_UNIT_SECONDS[unit]));
}

export function clampDurationSeconds(
  seconds: number,
  minSeconds?: number,
  maxSeconds?: number,
): number {
  let v = Math.max(0, Math.round(seconds));
  if (typeof minSeconds === 'number') v = Math.max(minSeconds, v);
  if (typeof maxSeconds === 'number') v = Math.min(maxSeconds, v);
  return v;
}

export function formatDurationSummary(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  if (total === 0) return '0 sec';
  const parts: string[] = [];
  let rem = total;
  const days = Math.floor(rem / 86400);
  if (days > 0) {
    parts.push(`${days} day${days === 1 ? '' : 's'}`);
    rem %= 86400;
  }
  const hours = Math.floor(rem / 3600);
  if (hours > 0) {
    parts.push(`${hours} hr`);
    rem %= 3600;
  }
  const minutes = Math.floor(rem / 60);
  if (minutes > 0) {
    parts.push(`${minutes} min`);
    rem %= 60;
  }
  if (rem > 0 || parts.length === 0) {
    parts.push(`${rem} sec`);
  }
  return parts.join(' ');
}
