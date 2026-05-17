import { confirmAdoption, sessionFromAdoption } from '@/api/adoption';
import { addDisplay, normalizeBaseUrl } from '@/storage/displays';
import { suggestDisplayLabel } from '@/util/adoptionDisplayIdentity';
import type { SavedDisplay } from '@/storage/displays';
import { saveSession, type DisplaySession } from '@/storage/sessions';
import { normalizeAdoptionChallengeCode } from '@/util/adoptionChallengeCode';
import { adoptionError, adoptionLog } from '@/util/adoptionLog';
import { syncUserDisplayToServer } from '@/storage/userDisplaysSync';

export type CompleteAdoptionInput = {
  baseUrl: string;
  label?: string;
  identifier: string;
  challengeCode: string;
};

export async function completeDisplayAdoption(
  input: CompleteAdoptionInput,
): Promise<{ display: SavedDisplay; session: DisplaySession }> {
  const normalized = normalizeBaseUrl(input.baseUrl);
  adoptionLog('persist.start', 'confirming adoption before saving display', {
    baseUrl: normalized,
    label: input.label ?? null,
    identifier: input.identifier.trim(),
    challenge_code: input.challengeCode.trim(),
  });
  try {
    void new URL(normalized);
    const challengeCode = normalizeAdoptionChallengeCode(input.challengeCode);
    const result = await confirmAdoption(normalized, {
      identifier: input.identifier.trim(),
      challenge_code: challengeCode,
    });
    const session = sessionFromAdoption(normalized, result);
    const display = addDisplay({
      baseUrl: normalized,
      label: suggestDisplayLabel(normalized, session.role, input.label),
    });
    saveSession(display.id, session);
    await syncUserDisplayToServer(display, session).catch(() => undefined);
    adoptionLog('persist.success', 'display and session saved', {
      displayId: display.id,
      displayLabel: display.label,
      baseUrl: display.baseUrl,
      identifier: session.identifier,
      role: session.role,
    });
    return { display, session };
  } catch (e) {
    adoptionError('persist.failed', 'adoption not saved', {
      baseUrl: normalized,
      identifier: input.identifier.trim(),
      error: e instanceof Error ? e.message : String(e),
    });
    throw e;
  }
}
