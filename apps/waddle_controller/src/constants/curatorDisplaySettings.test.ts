import { describe, expect, it } from 'vitest';
import {
  curatorThemeById,
  curatorThemeIds,
  parseAdoptionAllowedRoles,
} from './curatorDisplaySettings';

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

describe('curatorThemeIds', () => {
  it('each theme has preview hex colors', () => {
    expect(curatorThemeIds.length).toBeGreaterThanOrEqual(12);
    for (const theme of curatorThemeIds) {
      expect(theme.colors.length).toBeGreaterThanOrEqual(5);
      for (const hex of theme.colors) {
        expect(hex).toMatch(/^#[0-9A-Fa-f]{6}$/);
      }
    }
  });

  it('curatorThemeById resolves known ids', () => {
    expect(curatorThemeById('navy_coral')?.label).toContain('Navy');
    expect(curatorThemeById('unknown_theme')).toBeUndefined();
  });
});
