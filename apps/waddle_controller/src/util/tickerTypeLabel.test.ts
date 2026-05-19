import { describe, expect, it } from 'vitest';
import { tickerTypeLabel } from './tickerTypeLabel';

describe('tickerTypeLabel', () => {
  it('prefers registry label when present', () => {
    expect(
      tickerTypeLabel('news', {
        ticker_type: 'news',
        label: 'News',
      }),
    ).toBe('News');
  });

  it('falls back to underscore-separated words', () => {
    expect(tickerTypeLabel('stock_quotes')).toBe('stock quotes');
  });
});
