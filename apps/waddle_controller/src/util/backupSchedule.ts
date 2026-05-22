export type BackupScheduleFrequency = 'daily' | 'weekly';

export type BackupSchedule = {
  frequency: BackupScheduleFrequency;
  interval: number;
  dayOfWeek: number | null;
  hour: number;
  minute: number;
};

export const WEEKDAY_LABELS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'] as const;

export const NIGHT_HOUR_OPTIONS = [0, 1, 2, 3, 4, 5] as const;

export function defaultBackupSchedule(): BackupSchedule {
  return {
    frequency: 'weekly',
    interval: 1,
    dayOfWeek: 0,
    hour: 2,
    minute: 0,
  };
}

export function scheduleFromTarget(
  schedule: BackupSchedule | undefined,
): BackupSchedule {
  if (!schedule) return defaultBackupSchedule();
  return {
    frequency: schedule.frequency === 'daily' ? 'daily' : 'weekly',
    interval: schedule.interval === 2 ? 2 : 1,
    dayOfWeek:
      schedule.frequency === 'weekly'
        ? schedule.dayOfWeek != null
          ? ((schedule.dayOfWeek % 7) + 7) % 7
          : 0
        : null,
    hour: Math.max(0, Math.min(23, schedule.hour)),
    minute: Math.max(0, Math.min(59, schedule.minute)),
  };
}

export function formatScheduleSummary(schedule: BackupSchedule, timezone: string): string {
  const time = `${String(schedule.hour).padStart(2, '0')}:${String(schedule.minute).padStart(2, '0')}`;
  if (schedule.frequency === 'daily') {
    const every = schedule.interval === 2 ? 'every 2 days' : 'every day';
    return `${every} at ${time} (${timezone})`;
  }
  const dow = schedule.dayOfWeek != null ? WEEKDAY_LABELS[schedule.dayOfWeek] : 'Sunday';
  const every = schedule.interval === 2 ? 'every 2 weeks' : 'every week';
  return `${every} on ${dow} at ${time} (${timezone})`;
}

export function isNightHour(hour: number): boolean {
  return hour >= 0 && hour <= 5;
}
