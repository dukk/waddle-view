import { useCallback, useEffect, useRef, useState } from 'react';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import UploadFileIcon from '@mui/icons-material/UploadFile';
import {
  Box,
  Button,
  CircularProgress,
  IconButton,
  Slider,
  Stack,
  Typography,
} from '@mui/material';
import { fetchBlobObjectUrl } from '@/api/client';
import { uploadOverlayImageBlob } from '@/api/overlayBlobs';
import type { SavedDisplay } from '@/storage/displays';

function readBlobKeys(config: Record<string, unknown>): string[] {
  const raw = config.image_blob_keys;
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const e of raw) {
    if (typeof e === 'string' && e.trim()) out.push(e.trim());
  }
  return out;
}

function readNumber(config: Record<string, unknown>, key: string, fallback: number): number {
  const v = config[key];
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  return fallback;
}

type Props = {
  display: SavedDisplay;
  config: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

export function FallingImagesOverlayConfig({
  display,
  config,
  onChange,
  disabled = false,
}: Props) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [previewUrls, setPreviewUrls] = useState<Record<string, string>>({});

  const keys = readBlobKeys(config);
  const dropIntervalSec = readNumber(config, 'drop_interval_sec', 45);
  const fallSpeed = readNumber(config, 'fall_speed', 0.12);

  useEffect(() => {
    let cancelled = false;
    const urls: Record<string, string> = {};
    void (async () => {
      for (const key of keys) {
        if (previewUrls[key]) {
          urls[key] = previewUrls[key]!;
          continue;
        }
        try {
          const u = await fetchBlobObjectUrl(display, key);
          if (!cancelled && u) urls[key] = u;
        } catch {
          /* preview optional */
        }
      }
      if (!cancelled) setPreviewUrls((prev) => ({ ...prev, ...urls }));
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- keys drive reload
  }, [display, keys.join('\u241e')]);

  useEffect(
    () => () => {
      for (const u of Object.values(previewUrls)) {
        URL.revokeObjectURL(u);
      }
    },
    [previewUrls],
  );

  const patch = useCallback(
    (partial: Record<string, unknown>) => {
      onChange({ ...config, ...partial });
    },
    [config, onChange],
  );

  const onPickFiles = async (files: FileList | null) => {
    if (!files?.length) return;
    setErr(null);
    setUploading(true);
    try {
      const nextKeys = [...keys];
      for (const file of Array.from(files)) {
        const { blob_key } = await uploadOverlayImageBlob(display, file);
        if (!nextKeys.includes(blob_key)) nextKeys.push(blob_key);
      }
      patch({ image_blob_keys: nextKeys });
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setUploading(false);
      if (fileRef.current) fileRef.current.value = '';
    }
  };

  const removeKey = (key: string) => {
    patch({ image_blob_keys: keys.filter((k) => k !== key) });
    setPreviewUrls((prev) => {
      const u = prev[key];
      if (u) URL.revokeObjectURL(u);
      const next = { ...prev };
      delete next[key];
      return next;
    });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Falling images</Typography>
      <Typography variant="caption" color="text.secondary">
        Upload images to the display blob store. The overlay randomly picks one and drops it
        occasionally, rocking side to side as it falls.
      </Typography>
      <input
        ref={fileRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif"
        multiple
        hidden
        disabled={disabled || uploading}
        onChange={(e) => void onPickFiles(e.target.files)}
      />
      <Button
        variant="outlined"
        startIcon={uploading ? <CircularProgress size={18} /> : <UploadFileIcon />}
        disabled={disabled || uploading}
        onClick={() => fileRef.current?.click()}
      >
        {uploading ? 'Uploading…' : 'Upload images'}
      </Button>
      {err ? (
        <Typography variant="body2" color="error">
          {err}
        </Typography>
      ) : null}
      {keys.length > 0 ? (
        <Stack direction="row" flexWrap="wrap" gap={1}>
          {keys.map((key) => (
            <Box
              key={key}
              sx={{
                position: 'relative',
                width: 72,
                height: 72,
                borderRadius: 1,
                border: 1,
                borderColor: 'divider',
                overflow: 'hidden',
                bgcolor: 'action.hover',
              }}
            >
              {previewUrls[key] ? (
                <Box
                  component="img"
                  src={previewUrls[key]}
                  alt=""
                  sx={{ width: '100%', height: '100%', objectFit: 'cover' }}
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
                  <CircularProgress size={20} />
                </Box>
              )}
              <IconButton
                size="small"
                aria-label="Remove image"
                disabled={disabled}
                onClick={() => removeKey(key)}
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
          ))}
        </Stack>
      ) : (
        <Typography variant="body2" color="text.secondary">
          No images yet — upload at least one for the overlay to show anything.
        </Typography>
      )}
      <Typography gutterBottom>
        Drop interval: {dropIntervalSec}s (average time between drops)
      </Typography>
      <Slider
        value={dropIntervalSec}
        min={15}
        max={180}
        step={5}
        disabled={disabled}
        valueLabelDisplay="auto"
        onChange={(_, v) => patch({ drop_interval_sec: v as number })}
      />
      <Typography gutterBottom>
        Fall speed: {fallSpeed.toFixed(2)} (screen-heights per second; lower = slower)
      </Typography>
      <Slider
        value={fallSpeed}
        min={0.05}
        max={1}
        step={0.01}
        disabled={disabled}
        valueLabelDisplay="auto"
        onChange={(_, v) => patch({ fall_speed: v as number })}
      />
    </Stack>
  );
}
