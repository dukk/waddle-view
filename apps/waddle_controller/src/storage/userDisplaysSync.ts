import { upsertUserDisplay, fetchUserDisplays } from '@/api/bffUserDisplays';
import { isDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import { BffError } from '@/api/bffClient';
import {
  clearDisplaysStorage,
  importDisplaysJson,
  importDisplaysJsonLegacy,
  loadDisplays,
  saveDisplays,
  setLocalDisplaysMigrationComplete,
  type SavedDisplay,
} from '@/storage/displays';
import { clearAllSessions, loadSession, saveSession } from '@/storage/sessions';
import type { DisplaySession } from '@/storage/sessions';
import { permissionsForRole } from '@/auth/rolePermissions';

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

function mergeRemoteIntoLocal(remote: Awaited<ReturnType<typeof fetchUserDisplays>>['displays']): void {
  const local = loadDisplays();
  const byId = new Map(local.map((d) => [d.id, d]));
  const remoteIds = new Set<string>();

  for (const row of remote) {
    remoteIds.add(row.displayId);
    const existing = byId.get(row.displayId);
    const merged: SavedDisplay = {
      id: row.displayId,
      label: row.label,
      baseUrl: row.baseUrl,
      role: row.adoptedRole,
      identifier: row.clientIdentifier,
      apiKey: existing?.apiKey,
    };
    byId.set(row.displayId, merged);
    const session = loadSession(row.displayId);
    if (!session?.apiKey && row.hasApiKey) {
      // API key stays on server; proxy injects Bearer. Keep role/identifier in local session.
      saveSession(row.displayId, {
        apiKey: existing?.apiKey ?? session?.apiKey ?? '',
        identifier: row.clientIdentifier,
        role: row.adoptedRole,
        permissions: row.permissions,
        expiresAtMs: Date.now() + 365 * 24 * 60 * 60 * 1000,
      });
    }
  }

  const serverAuthoritative = [...byId.values()].filter((d) => remoteIds.has(d.id));
  saveDisplays(serverAuthoritative);
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

  await pushLocalDisplaysWithoutServerCopy(remote);
  mergeRemoteIntoLocal(remote);

  try {
    remote = (await fetchUserDisplays()).displays;
  } catch (e) {
    if (isUserDisplaysSyncSkippedError(e)) {
      return;
    }
    throw e;
  }
  mergeRemoteIntoLocal(remote);
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
    throw new Error('User mode is required to migrate displays');
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

/** Import JSON backup into server user_displays, then refresh local cache from server. */
export async function importDisplaysToServer(json: string): Promise<void> {
  if (!isDisplayProxyAuthEnabled()) {
    throw new Error('User mode is required to import displays to the server');
  }
  let displays: SavedDisplay[];
  try {
    const parsed = JSON.parse(json) as unknown;
    if (!Array.isArray(parsed)) throw new Error('Expected array');
    importDisplaysJson(json);
    displays = loadDisplays();
  } catch {
    importDisplaysJsonLegacy(json);
    displays = loadDisplays();
  }

  for (const display of displays) {
    const session = loadSession(display.id);
    const apiKey = session?.apiKey ?? display.apiKey ?? '';
    if (!apiKey) continue;
    const role = session?.role ?? display.role ?? 'operator';
    const identifier = session?.identifier ?? display.identifier ?? 'controller';
    const permissions = session?.permissions ?? permissionsForRole(role);
    await upsertUserDisplay({
      displayId: display.id,
      label: display.label,
      baseUrl: display.baseUrl,
      clientIdentifier: identifier,
      adoptedRole: role,
      apiKey,
      permissions,
    });
    saveSession(display.id, {
      apiKey,
      identifier,
      role,
      permissions,
      expiresAtMs: Date.now() + 365 * 24 * 60 * 60 * 1000,
    });
  }

  await pullUserDisplaysFromServer();
}
