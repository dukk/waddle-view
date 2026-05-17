import { upsertUserDisplay, fetchUserDisplays } from '@/api/bffUserDisplays';
import { isDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import { BffError } from '@/api/bffClient';
import {
  clearDisplaysStorage,
  loadDisplays,
  saveDisplays,
  setLocalDisplaysMigrationComplete,
  type SavedDisplay,
} from '@/storage/displays';
import { clearAllSessions, loadSession, saveSession } from '@/storage/sessions';
import type { DisplaySession } from '@/storage/sessions';

function isUserDisplaysSyncSkippedError(e: unknown): boolean {
  return e instanceof BffError && (e.status === 401 || e.status === 403);
}

export async function syncUserDisplayToServer(
  display: SavedDisplay,
  session: DisplaySession,
): Promise<void> {
  if (!isDisplayProxyAuthEnabled()) {
    return;
  }
  try {
    await upsertUserDisplay({
      displayId: display.id,
      label: display.label,
      baseUrl: display.baseUrl,
      clientIdentifier: session.identifier,
      adoptedRole: session.role,
      apiKey: session.apiKey,
      permissions: session.permissions,
    });
  } catch (e) {
    if (isUserDisplaysSyncSkippedError(e)) {
      return;
    }
    throw e;
  }
}

export async function pullUserDisplaysFromServer(): Promise<void> {
  if (!isDisplayProxyAuthEnabled()) {
    return;
  }
  let remote;
  try {
    remote = (await fetchUserDisplays()).displays;
  } catch (e) {
    if (isUserDisplaysSyncSkippedError(e)) {
      return;
    }
    throw e;
  }

  const local = loadDisplays();
  const byId = new Map(local.map((d) => [d.id, d]));
  for (const row of remote) {
    const existing = byId.get(row.displayId);
    byId.set(row.displayId, {
      id: row.displayId,
      label: row.label,
      baseUrl: row.baseUrl,
      apiKey: existing?.apiKey ?? '',
      role: row.adoptedRole,
      identifier: row.clientIdentifier,
    });
    if (!existing?.apiKey) {
      saveSession(row.displayId, {
        apiKey: '',
        identifier: row.clientIdentifier,
        role: row.adoptedRole,
        permissions: row.permissions,
        expiresAtMs: Date.now() + 365 * 24 * 60 * 60 * 1000,
      });
    }
  }
  saveDisplays([...byId.values()]);

  await pushLocalDisplaysWithoutServerCopy(remote);
}

async function pushLocalDisplaysWithoutServerCopy(
  remote: { displayId: string }[],
): Promise<void> {
  const remoteIds = new Set(remote.map((r) => r.displayId));
  for (const display of loadDisplays()) {
    if (remoteIds.has(display.id)) continue;
    const session = loadSession(display.id);
    if (!session?.apiKey) continue;
    await syncUserDisplayToServer(display, session);
  }
}

/** Push browser-local displays (and sessions) to the server, then reload from the BFF. */
export async function migrateLocalDisplaysToServer(): Promise<void> {
  if (!isDisplayProxyAuthEnabled()) {
    throw new Error('Controller authentication is required to migrate displays');
  }
  const displays = loadDisplays();
  for (const display of displays) {
    const session = loadSession(display.id);
    if (!session?.apiKey) continue;
    await syncUserDisplayToServer(display, session);
  }
  clearDisplaysStorage();
  clearAllSessions();
  setLocalDisplaysMigrationComplete();
  await pullUserDisplaysFromServer();
}
