import { describe, expect, it } from 'vitest';
import { geolocationErrorMessage } from './geolocationErrorMessage';

describe('geolocationErrorMessage', () => {
  it('maps permission denied without [object Object] text', () => {
    const msg = geolocationErrorMessage({ code: 1, message: '' });
    expect(msg).toContain('denied');
    expect(msg).not.toContain('[object');
  });

  it('maps position unavailable', () => {
    const msg = geolocationErrorMessage({ code: 2, message: 'Position update is unavailable' });
    expect(msg).toContain('could not be determined');
    expect(msg).toContain('Position update is unavailable');
  });

  it('maps timeout', () => {
    expect(geolocationErrorMessage({ code: 3, message: '' })).toContain('timed out');
  });

  it('falls back for standard errors', () => {
    expect(geolocationErrorMessage(new Error('network down'))).toBe('network down');
  });
});
