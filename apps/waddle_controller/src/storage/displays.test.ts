import { beforeEach, describe, expect, it, vi } from 'vitest';

import {

  addDisplay,

  applyDisplayAdoption,

  clearDisplaysStorage,

  clearLocalDisplaysMigrationComplete,

  exportDisplaysJson,

  hasStoredDisplaysInBrowser,

  importDisplaysJson,

  importDisplaysJsonLegacy,

  isLocalDisplaysMigrationComplete,

  loadDisplays,

  normalizeBaseUrl,

  removeDisplay,

  updateDisplayLabel,

  updateDisplaySettings,

  setLocalDisplaysMigrationComplete,

  shouldOfferLocalDisplaysMigration,

  upsertDisplayByBaseUrl,

} from './displays';



describe('normalizeBaseUrl', () => {

  it('trims trailing slashes', () => {

    expect(normalizeBaseUrl(' https://kiosk.example/ ')).toBe('https://kiosk.example');

  });

});



describe('displays storage', () => {

  beforeEach(() => {

    localStorage.clear();

  });



  it('round-trips displays through localStorage', () => {

    const d = addDisplay({ baseUrl: 'https://a.test/', label: 'A' });

    expect(d.baseUrl).toBe('https://a.test');

    expect(loadDisplays()).toHaveLength(1);

  });

  it('updateDisplayLabel changes label and rejects blank', () => {
    const d = addDisplay({ baseUrl: 'https://a.test/', label: 'A' });
    const updated = updateDisplayLabel(d.id, 'Lab kiosk');
    expect(updated?.label).toBe('Lab kiosk');
    expect(loadDisplays()[0]?.label).toBe('Lab kiosk');
    expect(updateDisplayLabel(d.id, '   ')).toBeNull();
    expect(loadDisplays()[0]?.label).toBe('Lab kiosk');
  });

  it('updateDisplaySettings changes base URL and rejects invalid URL', () => {
    const d = addDisplay({ baseUrl: 'https://a.test/', label: 'A' });
    const updated = updateDisplaySettings(d.id, {
      baseUrl: 'https://b.test/',
    });
    expect(updated?.baseUrl).toBe('https://b.test');
    expect(updateDisplaySettings(d.id, { baseUrl: 'not-a-url' })).toBeNull();
    expect(loadDisplays()[0]?.baseUrl).toBe('https://b.test');
  });

  it('ignores legacy setupMode field on load', () => {

    localStorage.setItem(

      'waddle_controller_displays_v1',

      JSON.stringify([

        { id: 'legacy', label: 'L', baseUrl: 'https://legacy.test', setupMode: 'new' },

      ]),

    );

    const row = loadDisplays()[0]!;

    expect(row.baseUrl).toBe('https://legacy.test');

    expect('setupMode' in row).toBe(false);

  });



  it('upsertDisplayByBaseUrl returns existing row', () => {

    const first = addDisplay({ baseUrl: 'https://dup.test' });

    const second = upsertDisplayByBaseUrl({ baseUrl: 'https://dup.test/' });

    expect(second.id).toBe(first.id);

    expect(loadDisplays()).toHaveLength(1);

  });



  it('removeDisplay deletes by id', () => {

    const d = addDisplay({ baseUrl: 'https://rm.test' });

    removeDisplay(d.id);

    expect(loadDisplays()).toEqual([]);

  });



  it('importDisplaysJson rejects non-arrays', () => {

    expect(() => importDisplaysJson('{}')).toThrow('Expected array');

  });



  it('importDisplaysJson preserves apiKey and role', () => {

    importDisplaysJson(

      JSON.stringify([

        {

          id: 'legacy1',

          label: 'L',

          baseUrl: 'https://legacy.test/',

          apiKey: 'wd_secret',

          role: 'operator',

          identifier: 'host-1',

        },

      ]),

    );

    const rows = loadDisplays();

    expect(rows).toHaveLength(1);

    expect(rows[0]).toMatchObject({

      baseUrl: 'https://legacy.test',

      apiKey: 'wd_secret',

      role: 'operator',

      identifier: 'host-1',

    });

  });



  it('importDisplaysJsonLegacy preserves adoption fields', () => {

    importDisplaysJsonLegacy(

      JSON.stringify([

        {

          id: 'legacy1',

          label: 'L',

          baseUrl: 'https://legacy.test/',

          apiKey: 'wd_secret',

          role: 'admin',

        },

      ]),

    );

    expect(loadDisplays()[0]?.apiKey).toBe('wd_secret');

    expect(loadDisplays()[0]?.role).toBe('admin');

  });



  it('exportDisplaysJson includes adoption fields', () => {

    const d = addDisplay({ baseUrl: 'https://export.test' });

    applyDisplayAdoption(d.id, {

      apiKey: 'wd_export',

      role: 'viewer',

      identifier: 'viewer-host',

    });

    const exported = JSON.parse(exportDisplaysJson()) as Record<string, unknown>[];

    expect(exported[0]).toMatchObject({

      apiKey: 'wd_export',

      role: 'viewer',

      identifier: 'viewer-host',

    });

  });



  it('loadDisplays returns empty on corrupt storage', () => {

    localStorage.setItem('waddle_controller_displays_v1', '{bad');

    expect(loadDisplays()).toEqual([]);

  });



  it('exportDisplaysJson matches stored rows', () => {

    addDisplay({ baseUrl: 'https://export.test' });

    expect(JSON.parse(exportDisplaysJson())).toHaveLength(1);

  });



  it('filters rows missing required fields', () => {

    importDisplaysJson(

      JSON.stringify([{ id: 'x', label: 'ok', baseUrl: 'https://ok.test' }, { id: 'bad' }]),

    );

    expect(loadDisplays()).toHaveLength(1);

  });



  it('generates unique ids', () => {

    vi.spyOn(Math, 'random').mockReturnValueOnce(0.1).mockReturnValueOnce(0.9);

    const a = addDisplay({ baseUrl: 'https://id-a.test' });

    const b = addDisplay({ baseUrl: 'https://id-b.test' });

    expect(a.id).not.toBe(b.id);

    vi.restoreAllMocks();

  });



  it('tracks local display migration offer state', () => {

    addDisplay({ baseUrl: 'https://migrate.test' });

    expect(hasStoredDisplaysInBrowser()).toBe(true);

    expect(shouldOfferLocalDisplaysMigration()).toBe(true);

    setLocalDisplaysMigrationComplete();

    expect(isLocalDisplaysMigrationComplete()).toBe(true);

    expect(shouldOfferLocalDisplaysMigration()).toBe(false);

    clearLocalDisplaysMigrationComplete();

    expect(shouldOfferLocalDisplaysMigration()).toBe(true);

  });



  it('clearDisplaysStorage removes saved rows', () => {

    addDisplay({ baseUrl: 'https://clear.test' });

    clearDisplaysStorage();

    expect(loadDisplays()).toEqual([]);

    expect(hasStoredDisplaysInBrowser()).toBe(false);

  });



  it('merges legacy per-display session keys into display rows', () => {

    addDisplay({ baseUrl: 'https://merge.test', label: 'Merge' });

    const id = loadDisplays()[0]!.id;

    localStorage.setItem(

      `waddle_controller_session_v1:${id}`,

      JSON.stringify({

        apiKey: 'wd_legacy',

        role: 'operator',

        identifier: 'legacy-host',

        permissions: ['telemetry.read'],

        expiresAtMs: Date.now() + 60_000,

      }),

    );

    const row = loadDisplays()[0]!;

    expect(row.apiKey).toBe('wd_legacy');

    expect(row.role).toBe('operator');

    expect(row.identifier).toBe('legacy-host');

    expect(localStorage.getItem(`waddle_controller_session_v1:${id}`)).toBeNull();

  });

});

