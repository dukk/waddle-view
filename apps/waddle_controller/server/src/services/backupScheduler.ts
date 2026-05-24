import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
import { isBackupScheduleDue } from './backupSchedule.js';
import {
  listEnabledBackupTargets,
  rowScheduleFields,
  updateBackupTargetRunStatus,
} from './backupTargets.js';
import { pullBackupFromDisplay } from './displayBackupPull.js';

const lastFiredMinute = new Map<string, string>();

function minuteKey(tz: string, now: Date): string {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: tz || 'UTC',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  return fmt.format(now);
}

let interval: ReturnType<typeof setInterval> | null = null;
let running = false;

export function startBackupScheduler(config: AppConfig, db: AppDatabase): void {
  if (interval) return;
  interval = setInterval(() => {
    void tick(config, db);
  }, 60_000);
  void tick(config, db);
}

export function stopBackupScheduler(): void {
  if (interval) {
    clearInterval(interval);
    interval = null;
  }
}

async function tick(config: AppConfig, db: AppDatabase): Promise<void> {
  if (running) return;
  running = true;
  try {
    const now = new Date();
    for (const target of await listEnabledBackupTargets(db)) {
      const schedule = rowScheduleFields(target);
      if (!isBackupScheduleDue(schedule, target.timezone, target.last_run_at, now)) {
        continue;
      }
      const key = `${target.id}:${minuteKey(target.timezone, now)}`;
      if (lastFiredMinute.get(target.id) === key) {
        continue;
      }
      lastFiredMinute.set(target.id, key);
      try {
        await pullBackupFromDisplay(config, db, target, 'scheduled');
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        await updateBackupTargetRunStatus(db, target.id, 'error', msg);
      }
    }
  } finally {
    running = false;
  }
}

export function resetSchedulerStateForTests(): void {
  lastFiredMinute.clear();
}
