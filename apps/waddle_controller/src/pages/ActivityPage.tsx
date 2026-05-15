import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';

type Line = { at_ms: number; channel: string; message: string };

export function ActivityPage() {
  const { active } = useDisplay();
  const [items, setItems] = useState<Line[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    try {
      const res = await apiJson<{ items: Line[] }>(active, '/v1/telemetry/providers?limit=300');
      setItems(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  }, [active]);

  useEffect(() => {
    void load();
    const id = window.setInterval(() => void load(), 4000);
    return () => window.clearInterval(id);
  }, [load]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={2}>
      <Typography variant="h5" fontWeight={600}>
        Activity log
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Provider and engine lines captured in-memory on the display (newest at the bottom of the
        buffer; this table shows the latest chunk, newest first).
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell width={160}>at_ms</TableCell>
              <TableCell width={100}>channel</TableCell>
              <TableCell>message</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {[...items].reverse().map((row) => (
              <TableRow key={`${row.at_ms}-${row.channel}-${row.message.slice(0, 40)}`}>
                <TableCell>{row.at_ms}</TableCell>
                <TableCell>{row.channel}</TableCell>
                <TableCell sx={{ fontFamily: 'monospace', fontSize: 12, whiteSpace: 'pre-wrap' }}>
                  {row.message}
                </TableCell>
              </TableRow>
            ))}
            {items.length === 0 && (
              <TableRow>
                <TableCell colSpan={3}>No telemetry lines yet.</TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Stack>
  );
}
