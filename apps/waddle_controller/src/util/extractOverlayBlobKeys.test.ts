import { describe, expect, it } from 'vitest';
import { extractOverlayBlobKeys } from './extractOverlayBlobKeys';

describe('extractOverlayBlobKeys', () => {
  it('collects image_blob_key', () => {
    expect(
      extractOverlayBlobKeys({ image_blob_key: 'overlay/pool/a', color: '#fff' }),
    ).toEqual(['overlay/pool/a']);
  });

  it('collects image_blob_keys array', () => {
    expect(
      extractOverlayBlobKeys({
        image_blob_keys: ['overlay/pool/1', 'overlay/pool/2'],
      }),
    ).toEqual(['overlay/pool/1', 'overlay/pool/2']);
  });

  it('dedupes and ignores empty strings', () => {
    expect(
      extractOverlayBlobKeys({
        image_blob_key: '  ',
        nested: { image_blob_key: 'k1', image_blob_keys: ['k1', ''] },
      }),
    ).toEqual(['k1']);
  });
});
