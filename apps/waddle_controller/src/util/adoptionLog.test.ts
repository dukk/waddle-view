import { describe, expect, it, vi } from 'vitest';
import {
  adoptionLog,
  sanitizeAdoptionLogData,
} from '@/util/adoptionLog';

describe('adoptionLog', () => {
  it('redacts api keys in log data', () => {
    expect(
      sanitizeAdoptionLogData({
        api_key: 'secret-key-value',
        identifier: 'ctrl-1',
        challenge_code: 'ABCD1234',
      }),
    ).toEqual({
      api_key: '<redacted len=16>',
      identifier: 'ctrl-1',
      challenge_code: 'ABCD1234',
    });
  });

  it('logs with prefix', () => {
    const spy = vi.spyOn(console, 'info').mockImplementation(() => {});
    adoptionLog('test.step', 'hello', { role: 'admin' });
    expect(spy).toHaveBeenCalledWith(
      '[waddle-adoption]',
      'test.step',
      'hello',
      { role: 'admin' },
    );
    spy.mockRestore();
  });
});
