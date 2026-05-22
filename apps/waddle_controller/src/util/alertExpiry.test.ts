import { describe, expect, it } from 'vitest';
import {
  alertExpireMinutesError,
  alertExpiresAtMs,
  parseAlertExpireMinutes,
} from './alertExpiry';

describe('parseAlertExpireMinutes', () => {
  it('accepts in-range integers', () => {
    expect(parseAlertExpireMinutes('1')).toBe(1);
    expect(parseAlertExpireMinutes(' 60 ')).toBe(60);
    expect(parseAlertExpireMinutes('10080')).toBe(10080);
  });

  it('rejects empty, fractional, and out-of-range values', () => {
    expect(parseAlertExpireMinutes('')).toBeNull();
    expect(parseAlertExpireMinutes('0')).toBeNull();
    expect(parseAlertExpireMinutes('10081')).toBeNull();
    expect(parseAlertExpireMinutes('1.5')).toBeNull();
    expect(parseAlertExpireMinutes('abc')).toBeNull();
  });
});

describe('alertExpiresAtMs', () => {
  it('adds minutes to now', () => {
    expect(alertExpiresAtMs(30, 1_000)).toBe(1_000 + 30 * 60_000);
  });
});

describe('alertExpireMinutesError', () => {
  it('returns messages for invalid input', () => {
    expect(alertExpireMinutesError('')).toBe('Expire in minutes is required.');
    expect(alertExpireMinutesError('0')).toMatch(/Enter 1/);
  });

  it('returns null for valid input', () => {
    expect(alertExpireMinutesError('15')).toBeNull();
  });
});
