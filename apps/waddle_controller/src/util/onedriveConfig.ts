export type OneDriveSourceState = {
  sourceId: string;
  folderLabel: string;
  path: string;
  categoryIds: string[];
  maxFiles: number;
};

export type OneDriveAccountState = {
  graphAccountKey: string;
  sources: OneDriveSourceState[];
};

export type OneDriveConfigState = {
  accounts: OneDriveAccountState[];
  globalPerPollLimit: number;
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

function parseCategoryIds(m: Record<string, unknown>): string[] {
  const fromArray = stringList(m.categoryIds);
  if (fromArray.length > 0) return fromArray;
  const legacy = String(m.category ?? '').trim();
  return legacy ? [legacy] : [];
}

function sourceFromRaw(raw: unknown): OneDriveSourceState | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const m = raw as Record<string, unknown>;
  const pathRaw = m.path ?? m.folder;
  const path = typeof pathRaw === 'string' ? pathRaw.trim() : '';
  const categoryIds = parseCategoryIds(m);
  if (categoryIds.length === 0) return null;
  const sourceId = String(m.sourceId ?? (path || 'source')).trim() || newOneDriveSourceId();
  return {
    sourceId,
    folderLabel: String(m.folderLabel ?? m.label ?? (path || 'Folder')).trim(),
    path,
    categoryIds,
    maxFiles: positiveInt(m.maxFiles, 50),
  };
}

function accountFromRaw(raw: unknown): OneDriveAccountState | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const m = raw as Record<string, unknown>;
  const graphAccountKey = String(m.graphAccountKey ?? '').trim();
  if (!graphAccountKey) return null;
  const sources: OneDriveSourceState[] = [];
  const rawSources = m.sources;
  if (Array.isArray(rawSources)) {
    for (const s of rawSources) {
      const parsed = sourceFromRaw(s);
      if (parsed) sources.push(parsed);
    }
  }
  return { graphAccountKey, sources };
}

export function parseOneDriveConfig(
  raw: Record<string, unknown>,
  _mediaKind: 'photo' | 'video',
): OneDriveConfigState {
  const globalPerPollLimit = positiveInt(raw.globalPerPollLimit, 50);
  const accounts: OneDriveAccountState[] = [];
  const rawAccounts = raw.accounts;
  if (Array.isArray(rawAccounts)) {
    for (const a of rawAccounts) {
      const parsed = accountFromRaw(a);
      if (parsed) accounts.push(parsed);
    }
  }
  return { accounts, globalPerPollLimit };
}

export function buildOneDriveConfigJson(
  state: OneDriveConfigState,
  mediaKind: 'photo' | 'video',
): Record<string, unknown> {
  return {
    globalPerPollLimit: state.globalPerPollLimit,
    accounts: state.accounts
      .filter((a) => a.graphAccountKey.trim() !== '')
      .map((a) => ({
        graphAccountKey: a.graphAccountKey,
        sources: a.sources.map((s) => ({
          sourceId: s.sourceId,
          folderLabel: s.folderLabel,
          path: s.path,
          kind: mediaKind,
          categoryIds: s.categoryIds,
          maxFiles: s.maxFiles,
        })),
      })),
  };
}

export function newOneDriveSourceId(): string {
  return `src_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

export function newOneDriveAccountBlock(): OneDriveAccountState {
  return { graphAccountKey: '', sources: [] };
}

/** True when [path] looks like a Windows local path instead of a Graph root-relative path. */
export function isWindowsLocalOneDrivePath(path: string): boolean {
  const t = path.trim();
  if (/^[A-Za-z]:[\\/]/.test(t)) return true;
  if (t.includes('\\')) return true;
  return /(?:^|[\\/])Users[\\/][^\\/]+[\\/]OneDrive\b/i.test(t);
}

export function onedriveConfigReady(state: OneDriveConfigState): boolean {
  if (state.accounts.length === 0) return false;
  return state.accounts.some(
    (a) =>
      a.graphAccountKey.trim() !== '' &&
      a.sources.some(
        (s) => s.categoryIds.length > 0 && !isWindowsLocalOneDrivePath(s.path),
      ),
  );
}
