import { useCallback, useState } from 'react';
import {
  Box,
  Button,
  IconButton,
  Paper,
  Snackbar,
  Stack,
  Tooltip,
  Typography,
} from '@mui/material';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import KeyboardArrowLeftIcon from '@mui/icons-material/KeyboardArrowLeft';
import KeyboardArrowRightIcon from '@mui/icons-material/KeyboardArrowRight';
import KeyboardReturnIcon from '@mui/icons-material/KeyboardReturn';
import type { SavedDisplay } from '@/storage/displays';
import { dismissActiveDisplayAlert, postDisplayNavigation } from '@/util/displayRemote';

type Props = {
  display: SavedDisplay;
  canDismissAlerts: boolean;
  variant?: 'full' | 'compact';
  /** Merged with internal snack from failed remote actions. */
  externalSnack?: string | null;
  onExternalSnackClose?: () => void;
};

export function RemoteControlsPanel({
  display,
  canDismissAlerts,
  variant = 'full',
  externalSnack,
  onExternalSnackClose,
}: Props) {
  const [navSnack, setNavSnack] = useState<string | null>(null);
  const compact = variant === 'compact';

  const runRemote = useCallback(
    async (action: () => Promise<string | null>) => {
      const err = await action();
      if (err) setNavSnack(err);
    },
    [],
  );

  const snackMessage = externalSnack ?? navSnack;
  const closeSnack = () => {
    onExternalSnackClose?.();
    setNavSnack(null);
  };

  return (
    <Stack spacing={compact ? 2 : 3}>
      <Snackbar
        open={snackMessage != null}
        autoHideDuration={6000}
        onClose={closeSnack}
        message={snackMessage ?? ''}
      />

      {!compact && (
        <Box>
          <Typography variant="h6" fontWeight={600} gutterBottom>
            Slideshow, ticker & alerts
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Control the active display slideshow, ticker, and overlay alerts. Keyboard shortcuts:
            ← → slides, ↑ ↓ ticker
            {canDismissAlerts ? ', Enter to dismiss the active alert' : ''}.
          </Typography>
        </Box>
      )}

      <Paper variant="outlined" sx={{ p: compact ? 2 : 3 }}>
        <Typography variant="subtitle2" fontWeight={600} sx={{ mb: 2 }}>
          Slides
        </Typography>
        <Stack direction="row" spacing={2} justifyContent="center">
          <Tooltip title="Previous slide (←)">
            <IconButton
              size="large"
              onClick={() => void runRemote(() => postDisplayNavigation(display, 'screen', 'back'))}
              aria-label="Previous slide"
              sx={{ border: 1, borderColor: 'divider' }}
            >
              <KeyboardArrowLeftIcon fontSize="large" />
            </IconButton>
          </Tooltip>
          <Tooltip title="Next slide (→)">
            <IconButton
              size="large"
              onClick={() =>
                void runRemote(() => postDisplayNavigation(display, 'screen', 'forward'))
              }
              aria-label="Next slide"
              sx={{ border: 1, borderColor: 'divider' }}
            >
              <KeyboardArrowRightIcon fontSize="large" />
            </IconButton>
          </Tooltip>
        </Stack>
      </Paper>

      <Paper variant="outlined" sx={{ p: compact ? 2 : 3 }}>
        <Typography variant="subtitle2" fontWeight={600} sx={{ mb: 2 }}>
          Ticker
        </Typography>
        <Stack direction="row" spacing={2} justifyContent="center">
          <Tooltip title="Ticker backward (↑)">
            <IconButton
              size="large"
              onClick={() => void runRemote(() => postDisplayNavigation(display, 'ticker', 'back'))}
              aria-label="Ticker previous"
              sx={{ border: 1, borderColor: 'divider' }}
            >
              <KeyboardArrowUpIcon fontSize="large" />
            </IconButton>
          </Tooltip>
          <Tooltip title="Ticker forward (↓)">
            <IconButton
              size="large"
              onClick={() =>
                void runRemote(() => postDisplayNavigation(display, 'ticker', 'forward'))
              }
              aria-label="Ticker next"
              sx={{ border: 1, borderColor: 'divider' }}
            >
              <KeyboardArrowDownIcon fontSize="large" />
            </IconButton>
          </Tooltip>
        </Stack>
      </Paper>

      <Paper variant="outlined" sx={{ p: compact ? 2 : 3 }}>
        <Typography variant="subtitle2" fontWeight={600} sx={{ mb: 2 }}>
          Overlay alerts
        </Typography>
        <Stack alignItems="center">
          <Tooltip
            title={
              canDismissAlerts
                ? 'Dismiss active alert (Enter)'
                : 'Your role cannot dismiss alerts via the API'
            }
          >
            <span>
              <Button
                variant="outlined"
                size="large"
                startIcon={<KeyboardReturnIcon />}
                disabled={!canDismissAlerts}
                onClick={() => void runRemote(() => dismissActiveDisplayAlert(display))}
                aria-label="Dismiss active alert"
              >
                Dismiss alert
              </Button>
            </span>
          </Tooltip>
        </Stack>
      </Paper>
    </Stack>
  );
}
