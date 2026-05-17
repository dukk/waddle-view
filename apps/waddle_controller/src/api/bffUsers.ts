import { bffJson } from '@/api/bffClient';
import type { BffUser, ControllerRole } from '@/api/bffAuth';

export type BffUserRecord = BffUser & {
  disabled: boolean;
  createdAt: string;
  updatedAt: string;
};

export function listBffUsers(): Promise<{ users: BffUserRecord[] }> {
  return bffJson('/users');
}

export function createBffUser(input: {
  username: string;
  password: string;
  role: ControllerRole;
}): Promise<{ user: BffUserRecord }> {
  return bffJson('/users', {
    method: 'POST',
    body: JSON.stringify(input),
  });
}

export function updateBffUser(
  id: string,
  patch: { role?: ControllerRole; disabled?: boolean; password?: string },
): Promise<{ user: BffUserRecord }> {
  return bffJson(`/users/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
}

export function deleteBffUser(id: string): Promise<{ ok: boolean }> {
  return bffJson(`/users/${encodeURIComponent(id)}`, { method: 'DELETE' });
}
