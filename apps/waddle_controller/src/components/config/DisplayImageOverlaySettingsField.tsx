import { useCallback, useEffect, useRef, useState } from 'react';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import UploadFileIcon from '@mui/icons-material/UploadFile';
import {
  Box,
  Button,
  CircularProgress,
  Divider,
  FormControlLabel,
  IconButton,
  Stack,
  Switch,
  Typography,
} from '@mui/material';
import { fetchBlobObjectUrl } from '@/api/client';
import { uploadOverlayImageBlob } from '@/api/overlayBlobs';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import {
  DISPLAY_IMAGE_OVERLAY_SCALE_MAX,
  DISPLAY_IMAGE_OVERLAY_SCALE_MIN,
  type DisplayImageOverlaySettings,
} from '@/constants/displayImageOverlaySettings';
import type { SavedDisplay } from '@/storage/displays';

type Props = {
  display: SavedDisplay;
  value: DisplayImageOverlaySettings;
  onChange: (next: DisplayImageOverlaySettings) => void;
  disabled?: boolean;
};

export function DisplayImageOverlaySettingsField({
  display,
  value,
  onChange,
  disabled,
}: Props) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadErr, setUploadErr] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const blobKey = value.image_blob_key?.trim() ?? '';

  useEffect(() => {
    let cancelled = false;
    if (!blobKey) {
      setPreviewUrl(null);
      return;
    }
    void (async () => {
      try {
        const u = await fetchBlobObjectUrl(display, blobKey);
        if (!cancelled) setPreviewUrl(u);
      } catch {
        if (!cancelled) setPreviewUrl(null);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [display, blobKey]);

  useEffect(
    () => () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    },
    [previewUrl],
  );

  const patch = useCallback(
    (partial: Partial<DisplayImageOverlaySettings>) => {
      onChange({ ...value, ...partial });
    },
    [onChange, value],
  );

  const onPickFile = async (files: FileList | null) => {
    const file = files?.[0];
    if (!file) return;
    setUploadErr(null);
    setUploading(true);
    try {
      const { blob_key } = await uploadOverlayImageBlob(display, file);
      patch({ image_blob_key: blob_key, enabled: true });
    } catch (e) {
      setUploadErr(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setUploading(false);
      if (fileRef.current) fileRef.current.value = '';
    }
  };

  const opacity = value.opacity ?? 1;

  return (
    <Stack spacing={2}>
      <Divider />
      <Typography variant="subtitle2" fontWeight={600}>
        Always-on image overlay
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Shows a logo or watermark on top of slides and the ticker at all times. Independent of
        curator programs and celebration overlays.
      </Typography>
      <FormControlLabel
        control={
          <Switch
            checked={value.enabled}
            disabled={disabled}
            onChange={(_, enabled) => patch({ enabled })}
          />
        }
        label="Enable image overlay"
      />
      <input
        ref={fileRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif,image/svg+xml,.svg"
        hidden
        disabled={disabled || uploading}
        onChange={(e) => void onPickFile(e.target.files)}
      />
      <Button
        variant="outlined"
        size="small"
        startIcon={uploading ? <CircularProgress size={18} /> : <UploadFileIcon />}
        disabled={disabled || uploading}
        onClick={() => fileRef.current?.click()}
        sx={{ alignSelf: 'flex-start' }}
      >
        {uploading ? 'Uploading…' : blobKey ? 'Replace image' : 'Upload image'}
      </Button>
      {uploadErr ? (
        <Typography variant="body2" color="error">
          {uploadErr}
        </Typography>
      ) : null}
      {blobKey ? (
        <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1 }}>
          <Box
            sx={{
              position: 'relative',
              width: 96,
              height: 96,
              borderRadius: 1,
              border: 1,
              borderColor: 'divider',
              overflow: 'hidden',
              bgcolor: 'action.hover',
            }}
          >
            {previewUrl ? (
              <Box
                component="img"
                src={previewUrl}
                alt=""
                sx={{ width: '100%', height: '100%', objectFit: 'contain' }}
              />
            ) : (
              <Box
                sx={{
                  width: '100%',
                  height: '100%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <CircularProgress size={24} />
              </Box>
            )}
            <IconButton
              size="small"
              aria-label="Remove image"
              disabled={disabled}
              onClick={() => patch({ image_blob_key: undefined })}
              sx={{
                position: 'absolute',
                top: 0,
                right: 0,
                bgcolor: 'background.paper',
              }}
            >
              <DeleteOutlineIcon fontSize="small" />
            </IconButton>
          </Box>
          <Typography variant="caption" color="text.secondary" sx={{ pt: 0.5, wordBreak: 'break-all' }}>
            {blobKey}
          </Typography>
        </Box>
      ) : (
        <Typography variant="body2" color="text.secondary">
          Upload JPEG, PNG, WebP, GIF, or SVG (max 4 MB).
        </Typography>
      )}
      <CuratorSliderField
        label="Horizontal position"
        value={value.x}
        onChange={(x) => patch({ x })}
        min={0}
        max={1}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v * 100)}%`}
      />
      <Typography variant="caption" color="text.secondary" sx={{ mt: -1.5, display: 'block' }}>
        0% = left edge; 100% = right edge (image anchors at top-left).
      </Typography>
      <CuratorSliderField
        label="Vertical position"
        value={value.y}
        onChange={(y) => patch({ y })}
        min={0}
        max={1}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v * 100)}%`}
      />
      <CuratorSliderField
        label="Scale"
        value={value.scale}
        onChange={(scale) => patch({ scale })}
        min={DISPLAY_IMAGE_OVERLAY_SCALE_MIN}
        max={DISPLAY_IMAGE_OVERLAY_SCALE_MAX}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <Typography variant="caption" color="text.secondary" sx={{ mt: -1.5, display: 'block' }}>
        Image width as a fraction of the viewport shortest side (
        {DISPLAY_IMAGE_OVERLAY_SCALE_MIN}–{DISPLAY_IMAGE_OVERLAY_SCALE_MAX}).
      </Typography>
      <CuratorSliderField
        label="Opacity"
        value={opacity}
        onChange={(next) => patch({ opacity: next >= 1 ? undefined : next })}
        min={0}
        max={1}
        step={0.05}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v * 100)}%`}
      />
    </Stack>
  );
}
