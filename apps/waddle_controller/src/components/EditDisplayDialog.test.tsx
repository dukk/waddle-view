import { render, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { EditDisplayDialog } from '@/components/EditDisplayDialog';
import { addDisplay, applyDisplayAdoption } from '@/storage/displays';
import * as displaySettingsApi from '@/api/displaySettings';

vi.mock('@/api/displaySettings', () => ({
  fetchDisplaySettings: vi.fn(),
}));

describe('EditDisplayDialog', () => {
  it('loads live preview settings once on mount for adopted displays', async () => {
    const display = addDisplay({ baseUrl: 'https://display.test/', label: 'Lab' });
    applyDisplayAdoption(display.id, {
      apiKey: 'wd_test_key',
      role: 'admin',
      identifier: 'test-host',
    });

    vi.mocked(displaySettingsApi.fetchDisplaySettings).mockResolvedValue({
      display_live_preview_enabled: false,
      display_live_preview_fps: 10,
      display_live_preview_width: 1280,
      display_live_preview_quality: 75,
    });

    render(
      <EditDisplayDialog
        display={display}
        onClose={() => {}}
        onSave={async () => {}}
      />,
    );

    await waitFor(() => {
      expect(displaySettingsApi.fetchDisplaySettings).toHaveBeenCalledTimes(1);
    });

    await new Promise((r) => setTimeout(r, 50));
    expect(displaySettingsApi.fetchDisplaySettings).toHaveBeenCalledTimes(1);
  });
});
