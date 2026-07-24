import { useState } from 'react';
import { Alert, Box, Button, Divider, Stack, Typography } from '@mui/material';
import { apiFetch, ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';

export function CatalogDefaultsResetSection({
  display,
  canWrite,
  onApplied,
}: {
  display: SavedDisplay;
  canWrite: boolean;
  onApplied: () => void;
}) {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savedMsg, setSavedMsg] = useState<string | null>(null);

  const runReset = async () => {
    const ok = await confirm({
      title: 'Reset screens, tickers, and overlays?',
      message: (
        <>
          This permanently deletes <strong>all</strong> custom screens, ticker tapes, and overlays
          on this display and restores the factory catalog and built-in program membership.
          Themes, integrations, curator program definitions, and config key–values are not changed.
        </>
      ),
      confirmLabel: 'Reset to defaults',
      severity: 'warning',
      busyLabel: 'Resetting…',
    });
    if (!ok) return;

    setBusy(true);
    setError(null);
    setSavedMsg(null);
    try {
      await apiFetch(
        display,
        '/v1/display/catalog/reset-defaults?confirm=yes',
        { method: 'POST' },
      );
      setSavedMsg('Catalog reset to system defaults.');
      onApplied();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Box sx={{ mt: 3 }}>
      <Divider sx={{ mb: 2 }} />
      <Typography variant="subtitle1" gutterBottom sx={{
        fontWeight: 600
      }}>
        Catalog defaults
      </Typography>
      <Typography
        variant="body2"
        sx={{
          color: "text.secondary",
          mb: 2
        }}>
        Remove every custom screen, ticker tape, and overlay and restore the seeded factory catalog
        plus default curator membership for those items. Does not reset display themes,
        integrations, or key–value tuning above.
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 1 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      {savedMsg && (
        <Alert severity="success" sx={{ mb: 1 }} onClose={() => setSavedMsg(null)}>
          {savedMsg}
        </Alert>
      )}
      <Stack direction="row" spacing={1} useFlexGap sx={{
        flexWrap: "wrap"
      }}>
        <Button
          variant="outlined"
          color="warning"
          disabled={!canWrite || busy}
          onClick={() => void runReset()}
        >
          {busy ? 'Resetting…' : 'Reset screens, tickers & overlays'}
        </Button>
      </Stack>
      <ConfirmDialogHost />
    </Box>
  );
}
