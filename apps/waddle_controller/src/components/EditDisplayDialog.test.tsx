import { render, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { EditDisplayDialog } from '@/components/EditDisplayDialog';
import { addDisplay, applyDisplayAdoption } from '@/storage/displays';
import * as displaySettingsApi from '@/api/displaySettings';

vi.mock('@/api/displaySettings', () => ({
  fetchDisplaySettings: vi.fn(),
}));

describe('EditDisplayDialog', () => {
  it('loads remote view settings once on mount for adopted displays', async () => {
    const display = addDisplay({ baseUrl: 'https://display.test/', label: 'Lab' });
    applyDisplayAdoption(display.id, {
      apiKey: 'wd_test_key',
      role: 'admin',
      identifier: 'test-host',
    });

    vi.mocked(displaySettingsApi.fetchDisplaySettings).mockResolvedValue({
      display_remote_view_enabled: false,
      display_remote_view_host: '127.0.0.1',
      display_remote_view_port: 6080,
      display_remote_view_path: '/',
      display_remote_view_password_configured: false,
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
