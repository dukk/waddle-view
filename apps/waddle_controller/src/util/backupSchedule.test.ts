import { describe, expect, it } from 'vitest';
import {
  defaultBackupSchedule,
  formatScheduleSummary,
  scheduleFromTarget,
} from './backupSchedule';

describe('backupSchedule (client)', () => {
  it('scheduleFromTarget normalizes weekly day', () => {
    const s = scheduleFromTarget({
      frequency: 'weekly',
      interval: 1,
      dayOfWeek: 3,
      hour: 2,
      minute: 5,
    });
    expect(s.dayOfWeek).toBe(3);
    expect(s.frequency).toBe('weekly');
  });

  it('formatScheduleSummary describes weekly schedule without timezone', () => {
    const text = formatScheduleSummary({
      frequency: 'weekly',
      interval: 2,
      dayOfWeek: 1,
      hour: 3,
      minute: 0,
    });
    expect(text).toBe('every 2 weeks on Monday at 03:00');
  });

  it('formatScheduleSummary describes daily schedule', () => {
    const text = formatScheduleSummary({
      frequency: 'daily',
      interval: 1,
      dayOfWeek: null,
      hour: 14,
      minute: 30,
    });
    expect(text).toBe('every day at 14:30');
  });

  it('defaultBackupSchedule is weekly', () => {
    expect(defaultBackupSchedule().frequency).toBe('weekly');
  });
});
