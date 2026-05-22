import { useEffect, useState } from 'react';
import {
  Alert,
  Grid,
  Paper,
  Stack,
  Typography,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import { useDisplay } from '@/context/DisplayContext';
import { useAuth } from '@/context/AuthContext';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { LivePreviewPanel } from '@/components/remote/LivePreviewPanel';
import { RemoteControlsPanel } from '@/components/remote/RemoteControlsPanel';
import { fetchLivePreviewInfo } from '@/api/displayLivePreview';
import type { LivePreviewInfo } from '@/api/displayLivePreview';

export function RemoteControlPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const theme = useTheme();
  const wide = useMediaQuery(theme.breakpoints.up('md'));
  const [livePreviewInfo, setLivePreviewInfo] = useState<LivePreviewInfo | null>(null);
  const [previewLoadError, setPreviewLoadError] = useState<string | null>(null);

  useEffect(() => {
    if (!active || !hasPermission('navigation.control')) {
      setLivePreviewInfo(null);
      return;
    }
    let cancelled = false;
    void (async () => {
      try {
        const live = await fetchLivePreviewInfo(active);
        if (!cancelled) {
          setLivePreviewInfo(live);
          setPreviewLoadError(null);
        }
      } catch (e) {
        if (!cancelled) {
          setLivePreviewInfo(null);
          setPreviewLoadError(String(e));
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [active, hasPermission]);

  if (!hasPermission('navigation.control')) {
    return (
      <Alert severity="warning" sx={{ maxWidth: 720 }}>
        Your role does not include display remote control. Ask an operator or admin if you need
        navigation access.
      </Alert>
    );
  }

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  const canDismissAlerts = hasPermission('alerts.write');
  const livePreviewConfigured = livePreviewInfo?.configured === true;

  const controls = (
    <Stack spacing={3} sx={{ maxWidth: wide ? 480 : undefined }}>
      {previewLoadError && (
        <Alert severity="warning" sx={{ maxWidth: 720 }}>
          Could not load live preview settings: {previewLoadError}
        </Alert>
      )}
      <RemoteControlsPanel display={active} canDismissAlerts={canDismissAlerts} variant="full" />
    </Stack>
  );

  const livePreviewSection = livePreviewConfigured ? (
    <Paper variant="outlined" sx={{ p: 2, minHeight: 420 }}>
      <Typography variant="subtitle2" fontWeight={600} sx={{ mb: 1 }}>
        Live preview
      </Typography>
      <LivePreviewPanel display={active} />
    </Paper>
  ) : null;

  if (!livePreviewConfigured) {
    return controls;
  }

  if (wide) {
    return (
      <Grid container spacing={3} sx={{ alignItems: 'flex-start' }}>
        <Grid item xs={12} md={5}>
          {controls}
        </Grid>
        <Grid item xs={12} md={7}>
          {livePreviewSection}
        </Grid>
      </Grid>
    );
  }

  return (
    <Stack spacing={3}>
      {controls}
      {livePreviewSection}
    </Stack>
  );
}
