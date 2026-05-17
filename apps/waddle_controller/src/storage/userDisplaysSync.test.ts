import { beforeEach, describe, expect, it, vi } from 'vitest';
import { setDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import { BffError } from '@/api/bffClient';
import {
  migrateLocalDisplaysToServer,
  pullUserDisplaysFromServer,
  syncUserDisplayToServer,
} from '@/storage/userDisplaysSync';
import {
  isLocalDisplaysMigrationComplete,
  loadDisplays,
} from '@/storage/displays';
import { loadDisplays, saveDisplays } from '@/storage/displays';
import { loadSession, saveSession } from '@/storage/sessions';

vi.mock('@/api/bffUserDisplays', () => ({
  fetchUserDisplays: vi.fn(),
  upsertUserDisplay: vi.fn(),
}));

import { fetchUserDisplays, upsertUserDisplay } from '@/api/bffUserDisplays';

describe('userDisplaysSync', () => {
  beforeEach(() => {
    localStorage.clear();
    setDisplayProxyAuthEnabled(true);
    vi.mocked(fetchUserDisplays).mockReset();
    vi.mocked(upsertUserDisplay).mockReset();
  });

  it('syncUserDisplayToServer upserts when authenticated', async () => {
    vi.mocked(upsertUserDisplay).mockResolvedValue({
      display: {
        id: '1',
        displayId: 'd1',
        label: 'Display',
        baseUrl: 'https://127.0.0.1:8787',
        clientIdentifier: 'wc',
        adoptedRole: 'admin',
        permissions: [],
        isActive: false,
        hasApiKey: true,
        createdAt: '',
        updatedAt: '',
      },
    });
    saveDisplays([{ id: 'd1', label: 'Display', baseUrl: 'https://127.0.0.1:8787' }]);
    await syncUserDisplayToServer(
      { id: 'd1', label: 'Display', baseUrl: 'https://127.0.0.1:8787' },
      {
        apiKey: 'key',
        identifier: 'wc',
        role: 'admin',
        permissions: [],
        expiresAtMs: Date.now() + 1000,
      },
    );
    expect(upsertUserDisplay).toHaveBeenCalled();
  });

  it('skips sync when controller auth is disabled', async () => {
    setDisplayProxyAuthEnabled(false);
    await syncUserDisplayToServer(
      { id: 'd1', label: 'K', baseUrl: 'https://127.0.0.1:8787' },
      {
        apiKey: 'key',
        identifier: 'wc',
        role: 'admin',
        permissions: [],
        expiresAtMs: Date.now() + 1000,
      },
    );
    expect(upsertUserDisplay).not.toHaveBeenCalled();
  });

  it('ignores unauthorized sync errors', async () => {
    vi.mocked(upsertUserDisplay).mockRejectedValue(new BffError('nope', 401));
    await syncUserDisplayToServer(
      { id: 'd1', label: 'K', baseUrl: 'https://127.0.0.1:8787' },
      {
        apiKey: 'key',
        identifier: 'wc',
        role: 'admin',
        permissions: [],
        expiresAtMs: Date.now() + 1000,
      },
    );
  });

  it('pullUserDisplaysFromServer merges remote displays', async () => {
    vi.mocked(fetchUserDisplays).mockResolvedValue({
      displays: [
        {
          id: 'row1',
          displayId: 'd_remote',
          label: 'Remote',
          baseUrl: 'http://10.0.0.5:8787',
          clientIdentifier: 'wc-remote',
          adoptedRole: 'operator',
          permissions: ['telemetry.read'],
          isActive: true,
          hasApiKey: true,
          createdAt: '',
          updatedAt: '',
        },
      ],
    });
    await pullUserDisplaysFromServer();
    const displays = loadDisplays();
    expect(displays.some((d) => d.id === 'd_remote')).toBe(true);
    const session = loadSession('d_remote');
    expect(session?.role).toBe('operator');
    expect(session?.permissions).toContain('telemetry.read');
  });

  it('pushes local-only displays on pull', async () => {
    vi.mocked(fetchUserDisplays).mockResolvedValue({ displays: [] });
    saveDisplays([{ id: 'd_local', label: 'Local', baseUrl: 'https://127.0.0.1:8787' }]);
    saveSession('d_local', {
      apiKey: 'local-key',
      identifier: 'wc',
      role: 'admin',
      permissions: [],
      expiresAtMs: Date.now() + 1000,
    });
    vi.mocked(upsertUserDisplay).mockResolvedValue({
      display: {
        id: '1',
        displayId: 'd_local',
        label: 'Local',
        baseUrl: 'https://127.0.0.1:8787',
        clientIdentifier: 'wc',
        adoptedRole: 'admin',
        permissions: [],
        isActive: false,
        hasApiKey: true,
        createdAt: '',
        updatedAt: '',
      },
    });
    await pullUserDisplaysFromServer();
    expect(upsertUserDisplay).toHaveBeenCalled();
  });

  it('migrateLocalDisplaysToServer clears local storage and marks migrated', async () => {
    saveDisplays([{ id: 'd_local', label: 'Local', baseUrl: 'https://127.0.0.1:8787' }]);
    saveSession('d_local', {
      apiKey: 'local-key',
      identifier: 'wc',
      role: 'admin',
      permissions: [],
      expiresAtMs: Date.now() + 1000,
    });
    vi.mocked(upsertUserDisplay).mockResolvedValue({
      display: {
        id: '1',
        displayId: 'd_local',
        label: 'Local',
        baseUrl: 'https://127.0.0.1:8787',
        clientIdentifier: 'wc',
        adoptedRole: 'admin',
        permissions: [],
        isActive: false,
        hasApiKey: true,
        createdAt: '',
        updatedAt: '',
      },
    });
    vi.mocked(fetchUserDisplays).mockResolvedValue({
      displays: [
        {
          id: 'row1',
          displayId: 'd_local',
          label: 'Local',
          baseUrl: 'https://127.0.0.1:8787',
          clientIdentifier: 'wc',
          adoptedRole: 'admin',
          permissions: [],
          isActive: true,
          hasApiKey: true,
          createdAt: '',
          updatedAt: '',
        },
      ],
    });
    await migrateLocalDisplaysToServer();
    expect(upsertUserDisplay).toHaveBeenCalled();
    expect(isLocalDisplaysMigrationComplete()).toBe(true);
    expect(loadDisplays().some((d) => d.id === 'd_local')).toBe(true);
  });
});
