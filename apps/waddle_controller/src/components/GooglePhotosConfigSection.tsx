import { useCallback, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import {
  createGooglePhotosPickerSession,
  deleteGooglePhotosPickerSession,
  listGooglePhotosPickedMedia,
  pickerUriForWeb,
  pollGooglePhotosPickerUntilReady,
} from '@/api/googlePhotosPicker';
import { ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { IntegrationAccountRow } from '@/util/integrationAccounts';
import { ContentCategorySelectField } from '@/components/config/ContentCategorySelectField';
import { DISPLAY_SETTINGS_ACCOUNTS_LABEL } from '@/constants/displaySettingsTabs';
import {
  mergePickedMediaIds,
  newGooglePhotosSourceId,
  type GooglePhotosConfigState,
  type GooglePhotosSourceState,
} from '@/util/googlePhotosConfig';
import type { ContentCategoryOption } from '@/components/OutlookCalendarConfigSection';

type Props = {
  display: SavedDisplay;
  value: GooglePhotosConfigState;
  onChange: (next: GooglePhotosConfigState) => void;
  googleAccounts: IntegrationAccountRow[];
  categories: ContentCategoryOption[];
  mediaKind: 'photo' | 'video';
};

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

function filterPickedIds(
  items: { id: string; mimeType: string; type: string }[],
  mediaKind: 'photo' | 'video',
): string[] {
  return items
    .filter((item) => {
      if (mediaKind === 'photo') {
        return item.type === 'PHOTO' || item.mimeType.startsWith('image/');
      }
      return item.type === 'VIDEO' || item.mimeType.startsWith('video/');
    })
    .map((item) => item.id);
}

export function GooglePhotosConfigSection({
  display,
  value,
  onChange,
  googleAccounts,
  categories,
  mediaKind,
}: Props) {
  const [pickerBusySourceId, setPickerBusySourceId] = useState<string | null>(null);
  const [pickerError, setPickerError] = useState<string | null>(null);

  const configuredGoogleAccounts = googleAccounts.filter((a) => a.configured);

  const patch = (partial: Partial<GooglePhotosConfigState>) => {
    onChange({ ...value, ...partial });
  };

  const patchSource = (sourceId: string, partial: Partial<GooglePhotosSourceState>) => {
    onChange({
      ...value,
      sources: value.sources.map((s) =>
        s.sourceId === sourceId ? { ...s, ...partial } : s,
      ),
    });
  };

  const addSource = () => {
    onChange({
      ...value,
      sources: [
        ...value.sources,
        {
          sourceId: newGooglePhotosSourceId(),
          albumLabel: '',
          albumSearchHint: '',
          category: categories[0]?.id ?? 'general',
          maxFiles: 50,
          perPollLimit: 10,
          mediaItemIds: [],
          pickerSessionId: '',
          lastPickedAtMs: null,
        },
      ],
    });
  };

  const removeSource = (sourceId: string) => {
    onChange({
      ...value,
      sources: value.sources.filter((s) => s.sourceId !== sourceId),
    });
  };

  const runPicker = useCallback(
    async (source: GooglePhotosSourceState, replaceIds: boolean) => {
      if (!value.googleAccountKey) {
        setPickerError('Choose a Google account first.');
        return;
      }
      setPickerError(null);
      setPickerBusySourceId(source.sourceId);
      try {
        const created = await createGooglePhotosPickerSession(
          display,
          value.googleAccountKey,
        );
        window.open(pickerUriForWeb(created.pickerUri), '_blank', 'noopener,noreferrer');
        await pollGooglePhotosPickerUntilReady(
          display,
          value.googleAccountKey,
          created.sessionId,
        );
        const items = await listGooglePhotosPickedMedia(
          display,
          value.googleAccountKey,
          created.sessionId,
        );
        const ids = filterPickedIds(items, mediaKind);
        const merged = replaceIds ? ids : mergePickedMediaIds(source.mediaItemIds, ids);
        patchSource(source.sourceId, {
          mediaItemIds: merged,
          pickerSessionId: created.sessionId,
          lastPickedAtMs: Date.now(),
        });
        try {
          await deleteGooglePhotosPickerSession(
            display,
            value.googleAccountKey,
            created.sessionId,
          );
        } catch {
          // Best-effort session cleanup.
        }
      } catch (e) {
        setPickerError(errMsg(e));
      } finally {
        setPickerBusySourceId(null);
      }
    },
    [display, value.googleAccountKey, mediaKind],
  );

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Google Photos album sources</Typography>
      <Typography variant="body2" color="text.secondary">
        Shared albums: open Google Photos, search for your album name, then select items. New
        photos in a shared album require <strong>Refresh selection</strong>.
      </Typography>
      {configuredGoogleAccounts.length === 0 ? (
        <Alert severity="info">
          Add a Google account under <strong>{DISPLAY_SETTINGS_ACCOUNTS_LABEL}</strong>, complete
          sign-in on the display, then return here.
        </Alert>
      ) : (
        <FormControl fullWidth size="small">
          <InputLabel id="google-photos-account-label">Google account</InputLabel>
          <Select
            labelId="google-photos-account-label"
            label="Google account"
            value={value.googleAccountKey}
            onChange={(e) => patch({ googleAccountKey: e.target.value })}
          >
            {configuredGoogleAccounts.map((a) => (
              <MenuItem key={a.id} value={a.id}>
                {a.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      )}
      <TextField
        label="Global per-poll download cap"
        type="number"
        size="small"
        fullWidth
        value={value.globalPerPollLimit}
        onChange={(e) =>
          patch({ globalPerPollLimit: Math.max(1, Number(e.target.value) || 50) })
        }
        inputProps={{ min: 1 }}
      />
      {pickerError ? <Alert severity="error">{pickerError}</Alert> : null}
      {value.sources.map((source) => (
        <Box
          key={source.sourceId}
          sx={{
            border: 1,
            borderColor: 'divider',
            borderRadius: 1,
            p: 2,
          }}
        >
          <Stack spacing={1.5}>
            <Stack direction="row" alignItems="center" justifyContent="space-between">
              <Typography variant="body2" fontWeight={600}>
                Album source
              </Typography>
              <IconButton
                size="small"
                aria-label="Remove source"
                onClick={() => removeSource(source.sourceId)}
              >
                <DeleteOutlineIcon fontSize="small" />
              </IconButton>
            </Stack>
            <TextField
              label="Label"
              size="small"
              fullWidth
              value={source.albumLabel}
              onChange={(e) => patchSource(source.sourceId, { albumLabel: e.target.value })}
            />
            <TextField
              label="Search hint (album name in Google Photos)"
              size="small"
              fullWidth
              value={source.albumSearchHint}
              onChange={(e) =>
                patchSource(source.sourceId, { albumSearchHint: e.target.value })
              }
              helperText="Shown when opening Google Photos; search for this name (works for shared albums)."
            />
            <ContentCategorySelectField
              id={`google-photos-cat-${source.sourceId}`}
              label="Category"
              value={source.category}
              onChange={(category) => patchSource(source.sourceId, { category })}
              categories={categories}
            />
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
              <TextField
                label="Max files (retention)"
                type="number"
                size="small"
                fullWidth
                value={source.maxFiles}
                onChange={(e) =>
                  patchSource(source.sourceId, {
                    maxFiles: Math.max(1, Number(e.target.value) || 50),
                  })
                }
                inputProps={{ min: 1 }}
              />
              <TextField
                label="Per poll limit"
                type="number"
                size="small"
                fullWidth
                value={source.perPollLimit}
                onChange={(e) =>
                  patchSource(source.sourceId, {
                    perPollLimit: Math.max(1, Number(e.target.value) || 10),
                  })
                }
                inputProps={{ min: 1 }}
              />
            </Stack>
            <Typography variant="body2" color="text.secondary">
              {source.mediaItemIds.length} {mediaKind === 'photo' ? 'photo' : 'video'}
              {source.mediaItemIds.length === 1 ? '' : 's'} linked
            </Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Button
                variant="outlined"
                size="small"
                disabled={!value.googleAccountKey || pickerBusySourceId != null}
                onClick={() => void runPicker(source, true)}
              >
                {pickerBusySourceId === source.sourceId ? (
                  <CircularProgress size={18} sx={{ mr: 1 }} />
                ) : null}
                Open Google Photos
              </Button>
              <Button
                variant="text"
                size="small"
                disabled={
                  !value.googleAccountKey ||
                  pickerBusySourceId != null ||
                  source.mediaItemIds.length === 0
                }
                onClick={() => void runPicker(source, false)}
              >
                Refresh selection
              </Button>
            </Stack>
          </Stack>
        </Box>
      ))}
      <Button variant="outlined" size="small" onClick={addSource}>
        Add album source
      </Button>
    </Stack>
  );
}
