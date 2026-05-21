import { bffJson } from '@/api/bffClient';

export type ControllerRole = 'admin' | 'operator';

export type BffUser = {
  id: string;
  username: string;
  role: ControllerRole;
  mustChangePassword?: boolean;
};

export type BffStatus = {
  /** Env capability (`WADDLE_CONTROLLER_AUTH_ENABLED=1`). */
  authEnabled: boolean;
  /** Runtime user mode (SQLite). */
  userModeEnabled: boolean;
  /** Alias for `userModeEnabled`. */
  userManagementEnabled: boolean;
  needsBootstrap: boolean;
  recoveryExportAvailable: boolean;
  clientIdentifier?: string;
  user?: BffUser;
};

export function fetchBffStatus(): Promise<BffStatus> {
  return bffJson<BffStatus>('/status');
}

export function bffLogin(username: string, password: string): Promise<{ user: BffUser }> {
  return bffJson('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
}

export function bffLogout(): Promise<{ ok: boolean }> {
  return bffJson('/auth/logout', { method: 'POST' });
}

export function bffChangePassword(
  currentPassword: string,
  newPassword: string,
): Promise<{ user: BffUser }> {
  return bffJson('/auth/change-password', {
    method: 'POST',
    body: JSON.stringify({ currentPassword, newPassword }),
  });
}

export function bffBootstrapAdmin(
  username: string,
  password: string,
): Promise<{ user: BffUser; needsBootstrap: boolean }> {
  return bffJson('/bootstrap/admin', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
}

export function updateBffSettings(userModeEnabled: boolean): Promise<{
  userModeEnabled: boolean;
  userManagementEnabled: boolean;
  needsBootstrap: boolean;
}> {
  return bffJson('/settings', {
    method: 'PUT',
    body: JSON.stringify({ userModeEnabled }),
  });
}

export type RecoveryExportPayload = {
  displays: {
    id: string;
    label: string;
    baseUrl: string;
    apiKey?: string;
    role?: string;
    identifier?: string;
  }[];
  sessions: Record<
    string,
    {
      apiKey: string;
      identifier: string;
      role: string;
      permissions: string[];
      expiresAtMs: number;
    }
  >;
};

export function bffRecoveryExportDisplays(
  username: string,
  password: string,
): Promise<RecoveryExportPayload> {
  return bffJson('/recovery/export-displays', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
}
