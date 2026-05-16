/**
 * Mirrors `packages/waddle_shared/lib/auth/role_permissions.dart` (kRolePermissions).
 * Keep in sync when server roles change.
 */
const ROLE_PERMISSIONS: Record<string, ReadonlySet<string>> = {
  admin: new Set([
    'users.manage',
    'screens.read',
    'screens.write',
    'integrations.read',
    'integrations.write',
    'curator.read',
    'curator.write',
    'ticker.read',
    'ticker.write',
    'overlays.read',
    'overlays.write',
    'alerts.read',
    'alerts.write',
    'content.moderate',
    'reject_terms.manage',
    'navigation.control',
    'telemetry.read',
    'meta.read',
  ]),
  operator: new Set([
    'screens.read',
    'screens.write',
    'integrations.read',
    'integrations.write',
    'curator.read',
    'curator.write',
    'ticker.read',
    'ticker.write',
    'overlays.read',
    'overlays.write',
    'alerts.read',
    'alerts.write',
    'content.moderate',
    'reject_terms.manage',
    'navigation.control',
    'telemetry.read',
    'meta.read',
  ]),
  /** Telemetry + remote navigation + read-only catalog (Data, no suppression). */
  power_viewer: new Set(['telemetry.read', 'navigation.control', 'content.catalog_read']),
  /** Programs view only (telemetry + media GETs); keep in sync with `_viewerPermissions`. */
  viewer: new Set(['telemetry.read']),
};

/** Roles an admin can preview in the controller UI (same strings as the display API). */
export const PREVIEWABLE_CONTROLLER_ROLES = ['operator', 'viewer', 'power_viewer'] as const;
export type PreviewableControllerRole = (typeof PREVIEWABLE_CONTROLLER_ROLES)[number];

export function permissionsForRole(role: string): string[] {
  const set = ROLE_PERMISSIONS[role];
  if (!set) return [];
  return [...set].sort();
}
