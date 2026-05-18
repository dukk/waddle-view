import { useCallback, useEffect, useRef, useState } from 'react';
import type { FieldProps } from '@rjsf/utils';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import UploadFileIcon from '@mui/icons-material/UploadFile';
import {
  Box,
  Button,
  CircularProgress,
  FormControl,
  FormHelperText,
  FormLabel,
  IconButton,
  Stack,
  Typography,
} from '@mui/material';
import { fetchBlobObjectUrl } from '@/api/client';
import { uploadOverlayImageBlob } from '@/api/overlayBlobs';
import type { SavedDisplay } from '@/storage/displays';

function readKeys(formData: unknown): string[] {
  if (!Array.isArray(formData)) return [];
  const out: string[] = [];
  for (const e of formData) {
    if (typeof e === 'string' && e.trim()) out.push(e.trim());
  }
  return out;
}

type Props = FieldProps & {
  display: SavedDisplay;
};

export function OverlayBlobKeysField(props: Props) {
  const { display, formData, onChange, disabled, schema, rawErrors } = props;
  const fileRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadErr, setUploadErr] = useState<string | null>(null);
  const [previewUrls, setPreviewUrls] = useState<Record<string, string>>({});

  const keys = readKeys(formData);
  const label = (schema.title as string | undefined) ?? 'Images';

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

  const setKeys = useCallback(
    (next: string[]) => {
      onChange(next);
    },
    [onChange],
  );

  const onPickFiles = async (files: FileList | null) => {
    if (!files?.length) return;
    setUploadErr(null);
    setUploading(true);
    try {
      const nextKeys = [...keys];
      for (const file of Array.from(files)) {
        const { blob_key } = await uploadOverlayImageBlob(display, file);
        if (!nextKeys.includes(blob_key)) nextKeys.push(blob_key);
      }
      setKeys(nextKeys);
    } catch (e) {
      setUploadErr(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setUploading(false);
      if (fileRef.current) fileRef.current.value = '';
    }
  };

  const removeKey = (key: string) => {
    setKeys(keys.filter((k) => k !== key));
    setPreviewUrls((prev) => {
      const u = prev[key];
      if (u) URL.revokeObjectURL(u);
      const next = { ...prev };
      delete next[key];
      return next;
    });
  };

  return (
    <FormControl fullWidth margin="normal" error={Boolean(rawErrors?.length)}>
      <FormLabel>{label}</FormLabel>
      {schema.description ? (
        <Typography variant="caption" color="text.secondary" sx={{ mb: 1 }}>
          {String(schema.description)}
        </Typography>
      ) : null}
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
        size="small"
        startIcon={uploading ? <CircularProgress size={18} /> : <UploadFileIcon />}
        disabled={disabled || uploading}
        onClick={() => fileRef.current?.click()}
        sx={{ alignSelf: 'flex-start', mb: 1 }}
      >
        {uploading ? 'Uploading…' : 'Upload images'}
      </Button>
      {uploadErr ? (
        <Typography variant="body2" color="error">
          {uploadErr}
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
          No images uploaded yet.
        </Typography>
      )}
      {rawErrors?.length ? <FormHelperText>{rawErrors.join(', ')}</FormHelperText> : null}
    </FormControl>
  );
}
