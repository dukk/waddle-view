export type BackupScheduleFrequency = 'daily' | 'weekly';

export type BackupScheduleFields = {
  frequency: BackupScheduleFrequency;
  interval: number;
  dayOfWeek: number | null;
  hour: number;
  minute: number;
};

export type BackupSchedulePublic = BackupScheduleFields;

export const BACKUP_SCHEDULE_STAGGER_MINUTES = 5;
export const BACKUP_SCHEDULE_BASE_HOUR = 2;
export const BACKUP_SCHEDULE_BASE_MINUTE = 0;
export const BACKUP_SCHEDULE_BASE_DAY_OF_WEEK = 0;

const MINUTES_PER_DAY = 24 * 60;

/** Controller host timezone for all backup_targets.timezone values. */
export function controllerBackupTimezone(): string {
  const envTz = process.env.TZ?.trim();
  if (envTz) return envTz;
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  } catch {
    return 'UTC';
  }
}

function scheduleMinutesSinceMidnight(schedule: BackupScheduleFields): number {
  return schedule.hour * 60 + schedule.minute;
}

function mostCommonDayOfWeek(schedules: BackupScheduleFields[]): number {
  if (schedules.length === 0) return BACKUP_SCHEDULE_BASE_DAY_OF_WEEK;
  const counts = new Map<number, number>();
  for (const s of schedules) {
    if (s.frequency === 'weekly' && s.dayOfWeek != null) {
      const d = s.dayOfWeek;
      counts.set(d, (counts.get(d) ?? 0) + 1);
    }
  }
  let best = BACKUP_SCHEDULE_BASE_DAY_OF_WEEK;
  let bestCount = 0;
  for (const [d, c] of counts) {
    if (c > bestCount) {
      bestCount = c;
      best = d;
    }
  }
  return best;
}

/**
 * Assigns a weekly slot for a new backup target, staggered +5 minutes after existing targets
 * in the same scope (controller local time).
 */
export function allocateBackupScheduleForNewTarget(
  existingTargets: BackupScheduleFields[],
): BackupScheduleFields {
  const dayOfWeek = mostCommonDayOfWeek(existingTargets);
  const n = existingTargets.length;

  let baseMinutes = BACKUP_SCHEDULE_BASE_HOUR * 60 + BACKUP_SCHEDULE_BASE_MINUTE;
  if (existingTargets.length > 0) {
    const sameDay = existingTargets.filter(
      (s) => s.frequency === 'weekly' && (s.dayOfWeek ?? 0) === dayOfWeek,
    );
    const pool = sameDay.length > 0 ? sameDay : existingTargets;
    let maxMin = baseMinutes;
    for (const s of pool) {
      const m = scheduleMinutesSinceMidnight(s);
      if (m > maxMin) maxMin = m;
    }
    baseMinutes = maxMin;
  }

  const totalMinutes = (baseMinutes + BACKUP_SCHEDULE_STAGGER_MINUTES * n) % MINUTES_PER_DAY;
  return {
    frequency: 'weekly',
    interval: 1,
    dayOfWeek,
    hour: Math.floor(totalMinutes / 60),
    minute: totalMinutes % 60,
  };
}

/** Fallback when no row exists and allocation context is unavailable. */
export function buildDefaultBackupSchedule(): BackupScheduleFields {
  return allocateBackupScheduleForNewTarget([]);
}

export function clampScheduleInterval(interval: number, frequency: BackupScheduleFrequency): number {
  const n = Number.isFinite(interval) ? Math.floor(interval) : 1;
  if (frequency === 'weekly') {
    return Math.max(1, Math.min(2, n));
  }
  return Math.max(1, Math.min(2, n));
}

export function normalizeScheduleInput(
  input: Partial<BackupScheduleFields> | undefined,
  fallback?: BackupScheduleFields,
): BackupScheduleFields {
  const base = fallback ?? buildDefaultBackupSchedule();
  const frequency: BackupScheduleFrequency =
    input?.frequency === 'daily' || input?.frequency === 'weekly' ? input.frequency : base.frequency;
  const interval = clampScheduleInterval(input?.interval ?? base.interval, frequency);
  let dayOfWeek: number | null =
    frequency === 'weekly'
      ? (input?.dayOfWeek ?? base.dayOfWeek ?? 0)
      : null;
  if (frequency === 'weekly' && dayOfWeek != null) {
    dayOfWeek = ((Math.floor(dayOfWeek) % 7) + 7) % 7;
  }
  const hour = Math.max(0, Math.min(23, Math.floor(input?.hour ?? base.hour)));
  const minute = Math.max(0, Math.min(59, Math.floor(input?.minute ?? base.minute)));
  return { frequency, interval, dayOfWeek, hour, minute };
}

/** Derived five-field cron for logging / legacy reads. */
export function scheduleToCronExpr(schedule: BackupScheduleFields): string {
  if (schedule.frequency === 'daily') {
    return `${schedule.minute} ${schedule.hour} * * *`;
  }
  const dow = schedule.dayOfWeek ?? 0;
  return `${schedule.minute} ${schedule.hour} * * ${dow}`;
}

/** Parse daily `M H * * *` or weekly `M H * * D` into structured schedule. */
export function parseCronToSchedule(cronExpr: string): BackupScheduleFields | null {
  const parts = cronExpr.trim().split(/\s+/);
  if (parts.length !== 5) return null;
  const [minutePart, hourPart, dom, month, dow] = parts;
  if (dom !== '*' || month !== '*') return null;
  const minute = Number.parseInt(minutePart, 10);
  const hour = Number.parseInt(hourPart, 10);
  if (!Number.isFinite(minute) || !Number.isFinite(hour)) return null;
  if (dow === '*') {
    return {
      frequency: 'daily',
      interval: 1,
      dayOfWeek: null,
      hour,
      minute,
    };
  }
  const dayOfWeek = Number.parseInt(dow, 10);
  if (!Number.isFinite(dayOfWeek) || dayOfWeek < 0 || dayOfWeek > 6) return null;
  return {
    frequency: 'weekly',
    interval: 1,
    dayOfWeek,
    hour,
    minute,
  };
}

function localParts(timeZone: string, now: Date): { hour: number; minute: number; dayOfWeek: number } | null {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: timeZone || 'UTC',
    hour: 'numeric',
    minute: 'numeric',
    weekday: 'short',
    hour12: false,
  });
  const tokens = fmt.formatToParts(now);
  const hour = Number.parseInt(tokens.find((t) => t.type === 'hour')?.value ?? '', 10);
  const minute = Number.parseInt(tokens.find((t) => t.type === 'minute')?.value ?? '', 10);
  const weekday = tokens.find((t) => t.type === 'weekday')?.value ?? '';
  const dowMap: Record<string, number> = {
    Sun: 0,
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
  };
  const dayOfWeek = dowMap[weekday];
  if (!Number.isFinite(hour) || !Number.isFinite(minute) || dayOfWeek === undefined) {
    return null;
  }
  return { hour, minute, dayOfWeek };
}

function msSinceLastRun(lastRunAt: string | null, now: Date): number | null {
  if (!lastRunAt) return null;
  const t = Date.parse(lastRunAt);
  if (!Number.isFinite(t)) return null;
  return now.getTime() - t;
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const MS_PER_WEEK = 7 * MS_PER_DAY;

/**
 * Returns true when the structured schedule matches [now] in [timeZone] and the
 * interval since [lastRunAt] allows another run.
 */
export function isBackupScheduleDue(
  schedule: BackupScheduleFields,
  timeZone: string,
  lastRunAt: string | null,
  now: Date = new Date(),
): boolean {
  const local = localParts(timeZone, now);
  if (!local) return false;
  if (local.hour !== schedule.hour || local.minute !== schedule.minute) {
    return false;
  }

  const elapsed = msSinceLastRun(lastRunAt, now);

  if (schedule.frequency === 'daily') {
    const minGap = schedule.interval * MS_PER_DAY;
    if (elapsed != null && elapsed < minGap) return false;
    return true;
  }

  const wantDow = schedule.dayOfWeek ?? 0;
  if (local.dayOfWeek !== wantDow) return false;
  const minGap = schedule.interval * MS_PER_WEEK;
  if (elapsed != null && elapsed < minGap) return false;
  return true;
}

/** @deprecated Use isBackupScheduleDue; kept for tests migrating from daily-only cron. */
export function isDailyCronDue(
  cronExpr: string,
  timeZone: string,
  now: Date = new Date(),
): boolean {
  const schedule = parseCronToSchedule(cronExpr);
  if (!schedule || schedule.frequency !== 'daily') return false;
  return isBackupScheduleDue(schedule, timeZone, null, now);
}
