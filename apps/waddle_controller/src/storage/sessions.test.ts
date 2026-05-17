import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { loadDisplays, saveDisplays } from './displays';
import {
  clearAllSessions,
  clearSession,
  loadSession,
  saveSession,
  type DisplaySession,
} from './sessions';

const sampleSession = (expiresAtMs: number): DisplaySession => ({
  apiKey: 'wd_test_key',
  expiresAtMs,
  identifier: 'controller-host',
  role: 'operator',
  permissions: ['telemetry.read'],
});

describe('sessions storage', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-16T12:00:00Z'));
    saveDisplays([{ id: 'd1', label: 'D1', baseUrl: 'https://d1.test' }]);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('saves and loads a valid session from the display row', () => {
    saveSession('d1', sampleSession(Date.now() + 60_000));
    expect(loadSession('d1')?.apiKey).toBe('wd_test_key');
    expect(loadDisplays()[0]).toMatchObject({
      apiKey: 'wd_test_key',
      role: 'operator',
      identifier: 'controller-host',
    });
    expect(localStorage.getItem('waddle_controller_session_v1:d1')).toBeNull();
  });

  it('migrates legacy sessionStorage entries', () => {
    sessionStorage.setItem(
      'waddle_controller_session_v1:d1',
      JSON.stringify(sampleSession(Date.now() + 60_000)),
    );
    expect(loadSession('d1')?.apiKey).toBe('wd_test_key');
    expect(loadDisplays()[0]?.apiKey).toBe('wd_test_key');
    expect(sessionStorage.getItem('waddle_controller_session_v1:d1')).toBeNull();
  });

  it('clears expired legacy sessions on load', () => {
    localStorage.setItem(
      'waddle_controller_session_v1:d1',
      JSON.stringify(sampleSession(Date.now() - 1)),
    );
    saveDisplays([{ id: 'd1', label: 'D1', baseUrl: 'https://d1.test' }]);
    expect(loadSession('d1')).toBeNull();
    expect(localStorage.getItem('waddle_controller_session_v1:d1')).toBeNull();
  });

  it('clearSession removes adoption from the display row', () => {
    saveSession('d1', sampleSession(Date.now() + 60_000));
    saveDisplays([
      { id: 'd1', label: 'D1', baseUrl: 'https://d1.test' },
      { id: 'd2', label: 'D2', baseUrl: 'https://d2.test' },
    ]);
    saveSession('d2', sampleSession(Date.now() + 60_000));
    clearSession('d1');
    expect(loadSession('d1')).toBeNull();
    expect(loadDisplays()[0]?.apiKey).toBeUndefined();
    expect(loadSession('d2')).not.toBeNull();
  });

  it('clearAllSessions removes adoption from every display row', () => {
    saveSession('d1', sampleSession(Date.now() + 60_000));
    saveDisplays([
      { id: 'd1', label: 'D1', baseUrl: 'https://d1.test' },
      { id: 'd2', label: 'D2', baseUrl: 'https://d2.test' },
    ]);
    saveSession('d2', sampleSession(Date.now() + 60_000));
    clearAllSessions();
    expect(loadSession('d1')).toBeNull();
    expect(loadSession('d2')).toBeNull();
    expect(loadDisplays().every((d) => d.apiKey == null)).toBe(true);
  });

  it('returns null for corrupt legacy session JSON', () => {
    localStorage.setItem('waddle_controller_session_v1:d1', '{');
    expect(loadSession('d1')).toBeNull();
  });

  it('returns null when apiKey missing on display and legacy blob', () => {
    saveDisplays([{ id: 'd1', label: 'D1', baseUrl: 'https://d1.test', role: 'operator' }]);
    expect(loadSession('d1')).toBeNull();
  });
});
