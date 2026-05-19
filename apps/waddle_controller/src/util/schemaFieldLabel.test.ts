import { describe, expect, it } from 'vitest';
import { schemaPropertyLabel, splitSchemaPropertyKey } from './schemaFieldLabel';

describe('schemaFieldLabel', () => {
  it('splits camelCase and snake_case keys', () => {
    expect(splitSchemaPropertyKey('maxPhotos')).toEqual(['max', 'Photos']);
    expect(splitSchemaPropertyKey('graph_account_key')).toEqual(['graph', 'account', 'key']);
    expect(splitSchemaPropertyKey('defaultLocation')).toEqual(['default', 'Location']);
  });

  it('formats operator-facing labels with known tokens', () => {
    expect(schemaPropertyLabel('maxVideoDownloadWidth')).toBe('Max Video Download Width');
    expect(schemaPropertyLabel('oauth_client_id')).toBe('OAuth Client ID');
    expect(schemaPropertyLabel('baseUrl')).toBe('Base URL');
  });
});
