import { describe, expect, it } from 'vitest';
import { validateCatalogId } from './catalogId';

describe('validateCatalogId', () => {
  it('accepts slug-like ids', () => {
    expect(validateCatalogId('news_rss')).toBeNull();
    expect(validateCatalogId('Tape-2')).toBeNull();
  });

  it('rejects empty and invalid characters', () => {
    expect(validateCatalogId('')).toMatch(/required/i);
    expect(validateCatalogId('9bad')).toMatch(/letter/i);
    expect(validateCatalogId('has space')).toMatch(/letter/i);
  });
});
