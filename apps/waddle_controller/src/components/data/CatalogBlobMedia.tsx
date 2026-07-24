import { useEffect, useState } from 'react';
import { Box, Typography } from '@mui/material';
import { fetchBlobObjectUrl } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export function CatalogBlobMedia({
  display,
  blobKey,
  variant,
}: {
  display: SavedDisplay;
  blobKey: string | null | undefined;
  variant: 'image' | 'video';
}) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!blobKey?.trim()) {
      setUrl(null);
      return;
    }
    let revoked: string | null = null;
    let cancelled = false;
    void (async () => {
      const u = await fetchBlobObjectUrl(display, blobKey.trim());
      if (cancelled) {
        if (u) URL.revokeObjectURL(u);
        return;
      }
      revoked = u;
      setUrl(u);
    })();
    return () => {
      cancelled = true;
      if (revoked) URL.revokeObjectURL(revoked);
    };
  }, [display, blobKey]);

  if (!url) {
    return (
      <Typography variant="caption" sx={{
        color: "text.secondary"
      }}>
        {blobKey ? '…' : '—'}
      </Typography>
    );
  }
  if (variant === 'video') {
    return (
      <video
        src={url}
        controls
        muted
        playsInline
        style={{ maxWidth: 280, maxHeight: 160, borderRadius: 4, background: '#000' }}
      />
    );
  }
  return (
    <Box
      component="img"
      src={url}
      alt=""
      sx={{ maxWidth: 200, maxHeight: 120, objectFit: 'cover', borderRadius: 1, display: 'block' }}
    />
  );
}
