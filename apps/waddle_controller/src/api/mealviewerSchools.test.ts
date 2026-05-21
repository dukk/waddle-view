import { describe, expect, it, vi } from 'vitest';
import { searchMealviewerSchools } from './mealviewerSchools';

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from '@/api/client';

describe('mealviewerSchools', () => {
  it('searchMealviewerSchools calls proxy path', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      items: [{ school_slug: 'X', label: 'X School' }],
    });
    const display = { id: 'd1', baseUrl: 'http://localhost:8080' } as const;
    const items = await searchMealviewerSchools(display as never, 'elm');
    expect(items).toHaveLength(1);
    expect(apiJson).toHaveBeenCalledWith(
      display,
      expect.stringContaining('/v1/mealviewer/schools/search?q=elm'),
    );
  });
});
