import { useCallback, useState } from 'react';
import {
  Alert,
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
import { useDisplay } from '@/context/DisplayContext';
import { useAuth } from '@/context/AuthContext';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { dismissActiveDisplayAlert, postDisplayNavigation } from '@/util/displayRemote';

export function RemoteControlPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const [navSnack, setNavSnack] = useState<string | null>(null);

  const runRemote = useCallback(
    async (action: () => Promise<string | null>) => {
      if (!active) return;
      const err = await action();
      if (err) setNavSnack(err);
    },
    [active],
  );

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

  return (
    <Stack spacing={3} sx={{ maxWidth: 480 }}>
      <Snackbar
        open={navSnack != null}
        autoHideDuration={6000}
        onClose={() => setNavSnack(null)}
        message={navSnack ?? ''}
      />

      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Slideshow, ticker & alerts
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Control the active display slideshow, ticker, and overlay alerts. Keyboard shortcuts work
          anywhere in the controller: ← → for slides, ↑ ↓ for ticker
          {canDismissAlerts ? ', Enter to dismiss the active alert' : ''}.
        </Typography>
      </Box>

      <Paper variant="outlined" sx={{ p: 3 }}>
        <Typography variant="subtitle2" fontWeight={600} sx={{ mb: 2 }}>
          Slides
        </Typography>
        <Stack direction="row" spacing={2} justifyContent="center">
          <Tooltip title="Previous slide (←)">
            <IconButton
              size="large"
              onClick={() => void runRemote(() => postDisplayNavigation(active, 'screen', 'back'))}
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
                void runRemote(() => postDisplayNavigation(active, 'screen', 'forward'))
              }
              aria-label="Next slide"
              sx={{ border: 1, borderColor: 'divider' }}
            >
              <KeyboardArrowRightIcon fontSize="large" />
            </IconButton>
          </Tooltip>
        </Stack>
      </Paper>

      <Paper variant="outlined" sx={{ p: 3 }}>
        <Typography variant="subtitle2" fontWeight={600} sx={{ mb: 2 }}>
          Ticker
        </Typography>
        <Stack direction="row" spacing={2} justifyContent="center">
          <Tooltip title="Ticker backward (↑)">
            <IconButton
              size="large"
              onClick={() => void runRemote(() => postDisplayNavigation(active, 'ticker', 'back'))}
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
                void runRemote(() => postDisplayNavigation(active, 'ticker', 'forward'))
              }
              aria-label="Ticker next"
              sx={{ border: 1, borderColor: 'divider' }}
            >
              <KeyboardArrowDownIcon fontSize="large" />
            </IconButton>
          </Tooltip>
        </Stack>
      </Paper>

      <Paper variant="outlined" sx={{ p: 3 }}>
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
                onClick={() => void runRemote(() => dismissActiveDisplayAlert(active))}
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
