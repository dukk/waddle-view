import { describe, expect, it } from 'vitest';
import { adoptionConnectErrorMessage, adoptionErrorMessage } from './adoptionFetchError';

describe('adoptionConnectErrorMessage', () => {
  it('describes unreachable display instead of Failed to fetch', () => {
    const msg = adoptionConnectErrorMessage('https://127.0.0.1:8787', new TypeError('Failed to fetch'));
    expect(msg).toContain('https://127.0.0.1:8787');
    expect(msg).not.toContain('TypeError');
    expect(msg).not.toMatch(/Failed to fetch/i);
    expect(msg).toMatch(/could not reach|connect/i);
  });

  it('mentions mixed content when controller is HTTPS and display is HTTP', () => {
    const original = globalThis.window;
    Object.defineProperty(globalThis, 'window', {
      configurable: true,
      value: { location: { protocol: 'https:', hostname: 'controller.local' } },
    });
    try {
      const msg = adoptionConnectErrorMessage(
        'https://192.168.1.10:8787',
        new TypeError('Failed to fetch'),
      );
      expect(msg).toMatch(/HTTPS/i);
      expect(msg).toMatch(/HTTP/i);
    } finally {
      if (original === undefined) {
        Reflect.deleteProperty(globalThis, 'window');
      } else {
        Object.defineProperty(globalThis, 'window', {
          configurable: true,
          value: original,
        });
      }
    }
  });

  it('preserves non-network error messages', () => {
    expect(adoptionConnectErrorMessage('http://kiosk', new Error('Invalid URL'))).toBe(
      'Invalid URL',
    );
  });
});

describe('adoptionErrorMessage', () => {
  it('returns message without Error prefix', () => {
    expect(adoptionErrorMessage(new Error('denied'))).toBe('denied');
  });
});
