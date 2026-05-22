import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import {
  createGooglePhotosPickerSession,
  deleteGooglePhotosPickerSession,
  getGooglePhotosPickerSession,
  listGooglePhotosPickedMedia,
  pickerUriForWeb,
  pollGooglePhotosPickerUntilReady,
} from './googlePhotosPicker';

const display = { id: 'd1', label: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('./client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from './client';

describe('googlePhotosPicker api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('createGooglePhotosPickerSession POSTs optional requestId', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      sessionId: 's1',
      pickerUri: 'https://picker',
      mediaItemsSet: false,
    });
    const session = await createGooglePhotosPickerSession(display, 'acct-1', 'req-1');
    expect(session.sessionId).toBe('s1');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/integration-accounts/acct-1/google-photos/picker/sessions',
      { method: 'POST', body: JSON.stringify({ requestId: 'req-1' }) },
    );
  });

  it('getGooglePhotosPickerSession and listGooglePhotosPickedMedia with pagination', async () => {
    vi.mocked(apiJson)
      .mockResolvedValueOnce({
        sessionId: 's1',
        pickerUri: 'https://picker',
        mediaItemsSet: true,
      })
      .mockResolvedValueOnce({
        items: [{ id: 'm1', mimeType: 'image/jpeg', filename: 'a.jpg', type: 'photo' }],
        nextPageToken: 'page-2',
      })
      .mockResolvedValueOnce({
        items: [{ id: 'm2', mimeType: 'image/jpeg', filename: 'b.jpg', type: 'photo' }],
      });
    const session = await getGooglePhotosPickerSession(display, 'acct-1', 's1');
    expect(session.mediaItemsSet).toBe(true);
    const items = await listGooglePhotosPickedMedia(display, 'acct-1', 's1');
    expect(items).toHaveLength(2);
  });

  it('deleteGooglePhotosPickerSession and pickerUriForWeb', async () => {
    vi.mocked(apiJson).mockResolvedValue({});
    await deleteGooglePhotosPickerSession(display, 'acct-1', 's1');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/integration-accounts/acct-1/google-photos/picker/sessions/s1',
      { method: 'DELETE' },
    );
    expect(pickerUriForWeb('https://picker/')).toBe('https://picker/autoclose');
    expect(pickerUriForWeb('https://picker/autoclose')).toBe('https://picker/autoclose');
  });

  it('pollGooglePhotosPickerUntilReady waits until mediaItemsSet', async () => {
    vi.mocked(apiJson)
      .mockResolvedValueOnce({
        sessionId: 's1',
        pickerUri: 'https://picker',
        mediaItemsSet: false,
        recommendedPollIntervalMs: 10,
      })
      .mockResolvedValueOnce({
        sessionId: 's1',
        pickerUri: 'https://picker',
        mediaItemsSet: true,
      });
    vi.useFakeTimers();
    const pending = pollGooglePhotosPickerUntilReady(display, 'acct-1', 's1', {
      maxAttempts: 5,
    });
    await vi.advanceTimersByTimeAsync(15);
    const session = await pending;
    vi.useRealTimers();
    expect(session.mediaItemsSet).toBe(true);
  });
});
