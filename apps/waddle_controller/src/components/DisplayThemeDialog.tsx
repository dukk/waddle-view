import { useEffect, useState } from 'react';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
} from '@mui/material';

import { createDisplayTheme, updateDisplayTheme } from '@/api/displayThemes';
import { ApiError } from '@/api/client';
import { DisplayThemeChromeEditor } from '@/components/DisplayThemeChromeEditor';
import { DisplayThemePaletteSwatches } from '@/components/DisplayThemePaletteSwatches';
import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';
import type { DisplayCustomTheme } from '@/constants/displayThemes';
import { DEFAULT_DISPLAY_THEME_PREVIEW } from '@/constants/displayThemes';
import { clonePreviewGroups } from '@/util/displayThemeOptions';
import { isValidPreviewGroups } from '@/util/displayThemeChromeForm';
import { completeDialogSave } from '@/util/dialogSave';
import type { SavedDisplay } from '@/storage/displays';

type Props = {
  open: boolean;
  display: SavedDisplay;
  theme: DisplayCustomTheme | null;
  onClose: () => void;
  onSaved: () => void | Promise<void>;
};

export function DisplayThemeDialog({
  open,
  display,
  theme,
  onClose,
  onSaved,
}: Props) {
  const isEdit = theme != null;
  const [label, setLabel] = useState('');
  const [preview, setPreview] = useState<DisplayThemePreviewGroups>(
    clonePreviewGroups(DEFAULT_DISPLAY_THEME_PREVIEW),
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setError(null);
    if (theme) {
      setLabel(theme.label);
      setPreview(clonePreviewGroups(theme.preview));
    } else {
      setLabel('');
      setPreview(clonePreviewGroups(DEFAULT_DISPLAY_THEME_PREVIEW));
    }
  }, [open, theme]);

  const canSubmit =
    label.trim().length > 0 && label.trim().length <= 64 && isValidPreviewGroups(preview);

  const submit = async () => {
    if (!canSubmit) return;
    setSaving(true);
    setError(null);
    try {
      if (isEdit && theme) {
        await updateDisplayTheme(display, theme.id, {
          label: label.trim(),
          preview,
        });
      } else {
        await createDisplayTheme(display, {
          label: label.trim(),
          preview,
        });
      }
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onClose={saving ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>{isEdit ? 'Edit custom theme' : 'Create custom theme'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 0.5 }}>
          {error ? <Alert severity="error">{error}</Alert> : null}
          <TextField
            label="Theme name"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            disabled={saving}
            fullWidth
            required
            inputProps={{ maxLength: 64 }}
          />
          <Stack direction="row" alignItems="center" spacing={1}>
            <span style={{ flex: 1 }} />
            <DisplayThemePaletteSwatches groups={preview} size={18} />
          </Stack>
          <DisplayThemeChromeEditor
            key={theme?.id ?? 'create'}
            preview={preview}
            disabled={saving}
            onChange={setPreview}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={saving}>
          Cancel
        </Button>
        <Button variant="contained" onClick={() => void submit()} disabled={saving || !canSubmit}>
          {saving ? 'Saving…' : isEdit ? 'Save' : 'Create'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
