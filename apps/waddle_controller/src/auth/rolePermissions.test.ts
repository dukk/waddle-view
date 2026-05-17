import { describe, expect, it } from 'vitest';
import {
  permissionsForRole,
  PREVIEWABLE_CONTROLLER_ROLES,
} from './rolePermissions';

describe('permissionsForRole', () => {
  it('returns sorted admin permissions including users.manage', () => {
    const perms = permissionsForRole('admin');
    expect(perms).toContain('users.manage');
    expect(perms).toContain('telemetry.read');
    expect([...perms].sort()).toEqual(perms);
  });

  it('returns operator permissions without users.manage', () => {
    const perms = permissionsForRole('operator');
    expect(perms).not.toContain('users.manage');
    expect(perms).toContain('screens.write');
  });

  it('returns viewer telemetry only', () => {
    expect(permissionsForRole('viewer')).toEqual(['telemetry.read']);
  });

  it('returns power_viewer catalog and navigation', () => {
    const perms = permissionsForRole('power_viewer');
    expect(perms).toEqual(
      [
        'content.catalog_read',
        'interests.read',
        'navigation.control',
        'telemetry.read',
      ].sort(),
    );
  });

  it('returns empty list for unknown role', () => {
    expect(permissionsForRole('guest')).toEqual([]);
  });
});

describe('PREVIEWABLE_CONTROLLER_ROLES', () => {
  it('lists roles admins can preview', () => {
    expect(PREVIEWABLE_CONTROLLER_ROLES).toEqual(['operator', 'viewer', 'power_viewer']);
  });
});
