import { fetchAdoptionSession } from '@/api/adoption';
import { addDisplay, normalizeBaseUrl } from '@/storage/displays';
import { suggestDisplayLabel } from '@/util/adoptionDisplayIdentity';
import type { SavedDisplay } from '@/storage/displays';
import { saveSession, type DisplaySession } from '@/storage/sessions';
import { adoptionError, adoptionLog } from '@/util/adoptionLog';
import { syncUserDisplayToServer } from '@/storage/userDisplaysSync';

export type ConnectDisplayWithApiKeyInput = {
  baseUrl: string;
  apiKey: string;
  label?: string;
};

export async function connectDisplayWithApiKey(
  input: ConnectDisplayWithApiKeyInput,
): Promise<{ display: SavedDisplay; session: DisplaySession }> {
  const normalized = normalizeBaseUrl(input.baseUrl);
  const trimmedKey = input.apiKey.trim();
  adoptionLog('persist.apiKey.start', 'connecting with provided api key', {
    baseUrl: normalized,
    label: input.label ?? null,
  });
  try {
    void new URL(normalized);
    if (!trimmedKey) {
      throw new Error('API key is required');
    }
    const sessionInfo = await fetchAdoptionSession(normalized, trimmedKey);
    const session: DisplaySession = {
      apiKey: trimmedKey,
      identifier: sessionInfo.identifier,
      role: sessionInfo.role,
      permissions: sessionInfo.permissions,
      expiresAtMs: Date.now() + 365 * 24 * 60 * 60 * 1000,
    };
    const display = addDisplay({
      baseUrl: normalized,
      label: suggestDisplayLabel(normalized, session.role, input.label),
    });
    saveSession(display.id, session);
    await syncUserDisplayToServer(display, session).catch(() => undefined);
    adoptionLog('persist.apiKey.success', 'display connected with api key', {
      displayId: display.id,
      identifier: session.identifier,
      role: session.role,
    });
    return { display, session };
  } catch (e) {
    adoptionError('persist.apiKey.failed', 'api key connect not saved', {
      baseUrl: normalized,
      error: e instanceof Error ? e.message : String(e),
    });
    throw e;
  }
}
