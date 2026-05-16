import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearAllSessions,
  clearSession,
  loadSession,
  saveSession,
  type DisplaySession,
} from './sessions';

const sampleSession = (expiresAtMs: number): DisplaySession => ({
  token: 'tok',
  expiresAtMs,
  user: {
    id: 'u1',
    username: 'op',
    display_name: 'Op',
    role: 'operator',
    is_bootstrap: false,
    disabled: false,
  },
  permissions: ['telemetry.read'],
  warnings: [],
});

describe('sessions storage', () => {
  beforeEach(() => {
    sessionStorage.clear();
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-16T12:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('saves and loads a valid session', () => {
    saveSession('d1', sampleSession(Date.now() + 60_000));
    expect(loadSession('d1')?.token).toBe('tok');
  });

  it('clears expired sessions on load', () => {
    saveSession('d1', sampleSession(Date.now() - 1));
    expect(loadSession('d1')).toBeNull();
    expect(sessionStorage.getItem('waddle_controller_session_v1:d1')).toBeNull();
  });

  it('clearSession removes one display', () => {
    saveSession('d1', sampleSession(Date.now() + 60_000));
    saveSession('d2', sampleSession(Date.now() + 60_000));
    clearSession('d1');
    expect(loadSession('d1')).toBeNull();
    expect(loadSession('d2')).not.toBeNull();
  });

  it('clearAllSessions removes every session key', () => {
    saveSession('d1', sampleSession(Date.now() + 60_000));
    saveSession('d2', sampleSession(Date.now() + 60_000));
    clearAllSessions();
    expect(loadSession('d1')).toBeNull();
    expect(loadSession('d2')).toBeNull();
  });

  it('returns null for corrupt session JSON', () => {
    sessionStorage.setItem('waddle_controller_session_v1:d1', '{');
    expect(loadSession('d1')).toBeNull();
  });
});
