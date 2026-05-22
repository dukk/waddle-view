import { describe, expect, it } from 'vitest';
import {
  buildDefaultBackupSchedule,
  isBackupScheduleDue,
  normalizeScheduleInput,
  parseCronToSchedule,
  scheduleToCronExpr,
} from './backupSchedule.js';

describe('backupSchedule', () => {
  it('buildDefaultBackupSchedule returns weekly night window', () => {
    const s = buildDefaultBackupSchedule();
    expect(s.frequency).toBe('weekly');
    expect(s.interval).toBe(1);
    expect(s.dayOfWeek).toBeGreaterThanOrEqual(0);
    expect(s.dayOfWeek).toBeLessThanOrEqual(6);
    expect(s.hour).toBeGreaterThanOrEqual(2);
    expect(s.hour).toBeLessThanOrEqual(5);
  });

  it('scheduleToCronExpr encodes daily and weekly', () => {
    expect(
      scheduleToCronExpr({
        frequency: 'daily',
        interval: 1,
        dayOfWeek: null,
        hour: 3,
        minute: 15,
      }),
    ).toBe('15 3 * * *');
    expect(
      scheduleToCronExpr({
        frequency: 'weekly',
        interval: 1,
        dayOfWeek: 2,
        hour: 4,
        minute: 0,
      }),
    ).toBe('0 4 * * 2');
  });

  it('parseCronToSchedule reads daily and weekly', () => {
    expect(parseCronToSchedule('30 2 * * *')).toEqual({
      frequency: 'daily',
      interval: 1,
      dayOfWeek: null,
      hour: 2,
      minute: 30,
    });
    expect(parseCronToSchedule('0 3 * * 5')).toEqual({
      frequency: 'weekly',
      interval: 1,
      dayOfWeek: 5,
      hour: 3,
      minute: 0,
    });
  });

  it('isBackupScheduleDue respects weekly day and interval', () => {
    const schedule = {
      frequency: 'weekly' as const,
      interval: 1,
      dayOfWeek: 4,
      hour: 2,
      minute: 30,
    };
    const thursday = new Date('2026-05-21T02:30:00.000Z');
    expect(isBackupScheduleDue(schedule, 'UTC', null, thursday)).toBe(true);
    expect(
      isBackupScheduleDue(schedule, 'UTC', thursday.toISOString(), thursday),
    ).toBe(false);
    const friday = new Date('2026-05-22T02:30:00.000Z');
    expect(isBackupScheduleDue(schedule, 'UTC', null, friday)).toBe(false);
  });

  it('isBackupScheduleDue enforces every-2-days gap', () => {
    const schedule = {
      frequency: 'daily' as const,
      interval: 2,
      dayOfWeek: null,
      hour: 2,
      minute: 0,
    };
    const now = new Date('2026-05-22T02:00:00.000Z');
    const oneDayAgo = new Date('2026-05-21T02:00:00.000Z').toISOString();
    expect(isBackupScheduleDue(schedule, 'UTC', oneDayAgo, now)).toBe(false);
    const threeDaysAgo = new Date('2026-05-19T02:00:00.000Z').toISOString();
    expect(isBackupScheduleDue(schedule, 'UTC', threeDaysAgo, now)).toBe(true);
  });

  it('normalizeScheduleInput clamps interval', () => {
    const s = normalizeScheduleInput({
      frequency: 'weekly',
      interval: 99,
      dayOfWeek: 1,
      hour: 3,
      minute: 10,
    });
    expect(s.interval).toBe(2);
  });
});
