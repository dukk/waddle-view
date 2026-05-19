export type GooglePhotosSourceState = {
  sourceId: string;
  albumLabel: string;
  albumSearchHint: string;
  category: string;
  maxFiles: number;
  perPollLimit: number;
  mediaItemIds: string[];
  pickerSessionId: string;
  lastPickedAtMs: number | null;
};

export type GooglePhotosConfigState = {
  googleAccountKey: string;
  globalPerPollLimit: number;
  sources: GooglePhotosSourceState[];
};

function positiveInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
    return Math.floor(value);
  }
  return fallback;
}

function stringList(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const e of raw) {
    if (typeof e === 'string') {
      const t = e.trim();
      if (t && !out.includes(t)) out.push(t);
    }
  }
  return out;
}

function sourceFromRaw(raw: unknown): GooglePhotosSourceState | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const m = raw as Record<string, unknown>;
  const sourceId = String(m.sourceId ?? '').trim();
  const category = String(m.category ?? '').trim();
  if (!sourceId || !category) return null;
  return {
    sourceId,
    albumLabel: String(m.albumLabel ?? '').trim(),
    albumSearchHint: String(m.albumSearchHint ?? '').trim(),
    category,
    maxFiles: positiveInt(m.maxFiles, 50),
    perPollLimit: positiveInt(m.perPollLimit, positiveInt(m.maxFiles, 50)),
    mediaItemIds: stringList(m.mediaItemIds),
    pickerSessionId: String(m.pickerSessionId ?? '').trim(),
    lastPickedAtMs:
      typeof m.lastPickedAtMs === 'number' && Number.isFinite(m.lastPickedAtMs)
        ? Math.floor(m.lastPickedAtMs)
        : null,
  };
}

export function parseGooglePhotosConfig(
  raw: Record<string, unknown>,
): GooglePhotosConfigState {
  const globalPerPollLimit = positiveInt(raw.globalPerPollLimit, 50);
  const accounts = raw.accounts;
  if (!Array.isArray(accounts) || accounts.length === 0) {
    return { googleAccountKey: '', globalPerPollLimit, sources: [] };
  }
  const first = accounts[0];
  if (!first || typeof first !== 'object' || Array.isArray(first)) {
    return { googleAccountKey: '', globalPerPollLimit, sources: [] };
  }
  const account = first as Record<string, unknown>;
  const googleAccountKey = String(account.googleAccountKey ?? '').trim();
  const sources: GooglePhotosSourceState[] = [];
  const rawSources = account.sources;
  if (Array.isArray(rawSources)) {
    for (const s of rawSources) {
      const parsed = sourceFromRaw(s);
      if (parsed) sources.push(parsed);
    }
  }
  return { googleAccountKey, globalPerPollLimit, sources };
}

export function buildGooglePhotosConfigJson(
  state: GooglePhotosConfigState,
): Record<string, unknown> {
  return {
    globalPerPollLimit: state.globalPerPollLimit,
    accounts: state.googleAccountKey
      ? [
          {
            googleAccountKey: state.googleAccountKey,
            sources: state.sources.map((s) => ({
              sourceId: s.sourceId,
              albumLabel: s.albumLabel,
              albumSearchHint: s.albumSearchHint,
              category: s.category,
              maxFiles: s.maxFiles,
              perPollLimit: s.perPollLimit,
              mediaItemIds: s.mediaItemIds,
              ...(s.pickerSessionId ? { pickerSessionId: s.pickerSessionId } : {}),
              ...(s.lastPickedAtMs != null ? { lastPickedAtMs: s.lastPickedAtMs } : {}),
            })),
          },
        ]
      : [],
  };
}

export function mergePickedMediaIds(
  existing: string[],
  picked: string[],
): string[] {
  const seen = new Set(existing);
  const out = [...existing];
  for (const id of picked) {
    if (!seen.has(id)) {
      seen.add(id);
      out.push(id);
    }
  }
  return out;
}

export function newGooglePhotosSourceId(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return `src-${Date.now()}`;
}
