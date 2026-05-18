import { describe, expect, it } from 'vitest';
import {
  normalizeControllerDateOrder,
  normalizeControllerTimeFormat,
  parseAdoptionAllowedRoles,
} from './displaySettings';

describe('normalizeControllerTimeFormat', () => {
  it('defaults to 12h', () => {
    expect(normalizeControllerTimeFormat(undefined)).toBe('12h');
    expect(normalizeControllerTimeFormat('bogus')).toBe('12h');
  });

  it('accepts 24h', () => {
    expect(normalizeControllerTimeFormat('24h')).toBe('24h');
    expect(normalizeControllerTimeFormat('24')).toBe('24h');
  });
});

describe('normalizeControllerDateOrder', () => {
  it('defaults to mdy', () => {
    expect(normalizeControllerDateOrder(undefined)).toBe('mdy');
  });

  it('accepts dmy and ymd', () => {
    expect(normalizeControllerDateOrder('dmy')).toBe('dmy');
    expect(normalizeControllerDateOrder('ymd')).toBe('ymd');
  });
});

describe('parseAdoptionAllowedRoles', () => {
  it('uses adoption_allowed_roles when present', () => {
    expect(
      parseAdoptionAllowedRoles({
        adoption_allowed_roles: ['viewer', 'admin'],
      }),
    ).toEqual(new Set(['viewer', 'admin']));
  });

  it('returns empty set when legacy flag is false', () => {
    expect(parseAdoptionAllowedRoles({ adoption_allow_new_requests: false })).toEqual(
      new Set(),
    );
  });

  it('defaults to all roles when unset', () => {
    expect(parseAdoptionAllowedRoles({})).toEqual(
      new Set(['viewer', 'power_viewer', 'operator', 'admin']),
    );
  });
});
