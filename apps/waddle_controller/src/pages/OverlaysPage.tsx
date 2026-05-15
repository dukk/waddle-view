import { useCallback, useEffect, useState } from 'react';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Stack,
  Typography,
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';

export function OverlaysPage() {
  const { active } = useDisplay();
  const [items, setItems] = useState<Record<string, unknown>[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    try {
      const res = await apiJson<{ items: Record<string, unknown>[] }>(
        active,
        '/v1/display/overlays',
      );
      setItems(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  }, [active]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={2}>
      <Typography variant="h5" fontWeight={600}>
        Overlays
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Read-only view of overlay schedules from the display. Create or change rows from the admin
        UI or REST as documented in <code>docs/pi/api.md</code>.
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      {items.map((row) => {
        const id = String(row.id ?? 'unknown');
        return (
          <Accordion key={id}>
            <AccordionSummary expandIcon={<ExpandMoreIcon />}>
              <Typography fontWeight={600}>{id}</Typography>
              <Typography sx={{ ml: 2 }} color="text.secondary">
                {String(row.overlay_kind ?? '')}
              </Typography>
            </AccordionSummary>
            <AccordionDetails>
              <Typography
                component="pre"
                sx={{ fontFamily: 'monospace', fontSize: 12, m: 0, whiteSpace: 'pre-wrap' }}
              >
                {JSON.stringify(row, null, 2)}
              </Typography>
            </AccordionDetails>
          </Accordion>
        );
      })}
      {items.length === 0 && <Typography color="text.secondary">No overlay rows.</Typography>}
    </Stack>
  );
}
