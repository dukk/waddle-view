import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import {
  createCuratorConfiguration,
  deleteCuratorConfiguration,
  fetchActiveCurator,
  fetchCuratorConfiguration,
  fetchCuratorStatePredicates,
  listCuratorConfigurations,
  updateCuratorConfiguration,
} from './curatorConfigurations';

const display = { id: 'd1', label: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('./client', () => ({
  apiJson: vi.fn(),
  apiFetch: vi.fn(),
}));

import { apiFetch, apiJson } from './client';

describe('curatorConfigurations api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
    vi.mocked(apiFetch).mockReset();
  });

  it('listCuratorConfigurations calls GET /v1/curator/configurations', async () => {
    vi.mocked(apiJson).mockResolvedValue({ items: [{ id: 'evening', name: 'Evening' }] });
    const items = await listCuratorConfigurations(display);
    expect(items).toHaveLength(1);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/curator/configurations');
  });

  it('fetchCuratorConfiguration loads detail by id', async () => {
    vi.mocked(apiJson).mockResolvedValue({ id: 'evening', name: 'Evening', rules: [], members: {} });
    const detail = await fetchCuratorConfiguration(display, 'evening');
    expect(detail.id).toBe('evening');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/curator/configurations/evening',
    );
  });

  it('fetchActiveCurator and state predicates', async () => {
    vi.mocked(apiJson)
      .mockResolvedValueOnce({ exclusive: null, base: null, enhancements: [] })
      .mockResolvedValueOnce({ items: [{ id: 'night', label: 'Night', implemented: true }] });
    const active = await fetchActiveCurator(display);
    expect(active.enhancements).toEqual([]);
    const preds = await fetchCuratorStatePredicates(display);
    expect(preds[0]!.id).toBe('night');
  });

  it('create, update, and delete configurations', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response(null, { status: 204 }));
    await createCuratorConfiguration(display, { id: 'new', name: 'New' });
    await updateCuratorConfiguration(display, 'new', { name: 'Renamed' });
    await deleteCuratorConfiguration(display, 'new');
    expect(apiFetch).toHaveBeenCalledWith(display, '/v1/curator/configurations', {
      method: 'POST',
      body: JSON.stringify({ id: 'new', name: 'New' }),
    });
    expect(apiFetch).toHaveBeenCalledWith(display, '/v1/curator/configurations/new', {
      method: 'PATCH',
      body: JSON.stringify({ name: 'Renamed' }),
    });
    expect(apiFetch).toHaveBeenCalledWith(display, '/v1/curator/configurations/new', {
      method: 'DELETE',
    });
  });
});
