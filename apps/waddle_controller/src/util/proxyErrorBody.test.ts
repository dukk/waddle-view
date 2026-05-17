import { describe, expect, it } from 'vitest';
import { messageFromProxyErrorBody } from './proxyErrorBody';

describe('messageFromProxyErrorBody', () => {
  it('returns JSON error field when present', () => {
    const msg = messageFromProxyErrorBody(
      JSON.stringify({ error: 'Could not reach the display', code: 'display_unreachable' }),
      'fallback',
    );
    expect(msg).toBe('Could not reach the display');
  });

  it('falls back when body is empty', () => {
    expect(messageFromProxyErrorBody('', 'Bad Gateway')).toBe('Bad Gateway');
  });
});
