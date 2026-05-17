import { bffJson } from '@/api/bffClient';

export type ControllerRole = 'admin' | 'operator';

export type BffUser = {
  id: string;
  username: string;
  role: ControllerRole;
};

export type BffStatus = {
  authEnabled: boolean;
  userManagementEnabled: boolean;
  needsBootstrap: boolean;
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

export function bffBootstrapAdmin(
  username: string,
  password: string,
): Promise<{ user: BffUser; needsBootstrap: boolean }> {
  return bffJson('/bootstrap/admin', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
}

export function updateBffSettings(userManagementEnabled: boolean): Promise<{
  userManagementEnabled: boolean;
  needsBootstrap: boolean;
}> {
  return bffJson('/settings', {
    method: 'PUT',
    body: JSON.stringify({ userManagementEnabled }),
  });
}
