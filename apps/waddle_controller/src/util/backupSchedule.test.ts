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

  it('formatScheduleSummary describes weekly schedule', () => {
    const text = formatScheduleSummary(
      {
        frequency: 'weekly',
        interval: 2,
        dayOfWeek: 1,
        hour: 3,
        minute: 0,
      },
      'America/Chicago',
    );
    expect(text).toContain('every 2 weeks');
    expect(text).toContain('Monday');
    expect(text).toContain('America/Chicago');
  });

  it('defaultBackupSchedule is weekly', () => {
    expect(defaultBackupSchedule().frequency).toBe('weekly');
  });
});
