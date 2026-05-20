import { describe, expect, it, vi } from 'vitest';
import { fetchMicrosoftGraphDriveChildren } from './microsoftGraphDriveChildren';
import * as client from '@/api/client';

const display = { id: 'd1', name: 'Test', baseUrl: 'http://127.0.0.1:1' } as never;

describe('fetchMicrosoftGraphDriveChildren', () => {
  it('requests children with encoded path', async () => {
    const spy = vi.spyOn(client, 'apiJson').mockResolvedValue({
      items: [{ id: 'f1', name: 'Pictures', path: '/Pictures', folder: true }],
    });
    const items = await fetchMicrosoftGraphDriveChildren(display, 'acct1', '/Pictures');
    expect(spy).toHaveBeenCalledWith(
      display,
      '/v1/integration-accounts/acct1/microsoft-graph/drive/children?path=%2FPictures',
    );
    expect(items).toHaveLength(1);
    expect(items[0]?.name).toBe('Pictures');
    spy.mockRestore();
  });
});
