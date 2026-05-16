import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  addDisplay,
  exportDisplaysJson,
  importDisplaysJson,
  importDisplaysJsonLegacy,
  loadDisplays,
  normalizeBaseUrl,
  removeDisplay,
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

  it('importDisplaysJsonLegacy strips apiKey', () => {
    importDisplaysJsonLegacy(
      JSON.stringify([
        {
          id: 'legacy1',
          label: 'L',
          baseUrl: 'https://legacy.test/',
          apiKey: 'must-not-persist',
        },
      ]),
    );
    const rows = loadDisplays();
    expect(rows).toHaveLength(1);
    expect(rows[0]!.baseUrl).toBe('https://legacy.test');
    expect(JSON.stringify(rows)).not.toContain('apiKey');
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
});
