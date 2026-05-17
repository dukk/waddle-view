import { bffJson } from '@/api/bffClient';

export type BffUserDisplay = {
  id: string;
  displayId: string;
  label: string;
  baseUrl: string;
  clientIdentifier: string;
  adoptedRole: string;
  permissions: string[];
  isActive: boolean;
  hasApiKey: boolean;
  createdAt: string;
  updatedAt: string;
};

export function fetchUserDisplays(): Promise<{ displays: BffUserDisplay[] }> {
  return bffJson('/user-displays');
}

export function upsertUserDisplay(input: {
  displayId: string;
  label: string;
  baseUrl: string;
  clientIdentifier: string;
  adoptedRole: string;
  apiKey: string;
  permissions: string[];
}): Promise<{ display: BffUserDisplay }> {
  return bffJson('/user-displays', {
    method: 'PUT',
    body: JSON.stringify(input),
  });
}

export function setActiveUserDisplay(displayId: string): Promise<{ display: BffUserDisplay }> {
  return bffJson('/user-displays/active', {
    method: 'PATCH',
    body: JSON.stringify({ displayId }),
  });
}

export function deleteUserDisplay(displayId: string): Promise<{ ok: boolean }> {
  return bffJson(`/user-displays/${encodeURIComponent(displayId)}`, {
    method: 'DELETE',
  });
}
