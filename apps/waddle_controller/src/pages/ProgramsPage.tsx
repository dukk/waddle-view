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

type Items<T> = { items: T[] };

export function ProgramsPage() {
  const { active } = useDisplay();
  const [screen, setScreen] = useState<Record<string, unknown>[]>([]);
  const [ticker, setTicker] = useState<Record<string, unknown>[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    try {
      const [s, t] = await Promise.all([
        apiJson<Items<Record<string, unknown>>>(active, '/v1/telemetry/programs'),
        apiJson<Items<Record<string, unknown>>>(active, '/v1/telemetry/ticker-programs'),
      ]);
      setScreen(s.items ?? []);
      setTicker(t.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  }, [active]);

  useEffect(() => {
    void load();
    const id = window.setInterval(() => void load(), 5000);
    return () => window.clearInterval(id);
  }, [load]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      <Typography variant="h5" fontWeight={600}>
        Programs (telemetry)
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      <Typography variant="subtitle1">Screen programs</Typography>
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>at_ms</TableCell>
              <TableCell>reason</TableCell>
              <TableCell>slides</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {[...screen].reverse().map((row, i) => (
              <TableRow key={`${row.at_ms}-${i}`}>
                <TableCell>{String(row.at_ms)}</TableCell>
                <TableCell>{String(row.reason ?? '')}</TableCell>
                <TableCell sx={{ fontFamily: 'monospace', fontSize: 12, maxWidth: 480 }}>
                  {JSON.stringify(row.slides)}
                </TableCell>
              </TableRow>
            ))}
            {screen.length === 0 && (
              <TableRow>
                <TableCell colSpan={3}>
                  No samples yet (wait for the display to build a program).
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <Typography variant="subtitle1">Ticker programs</Typography>
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>at_ms</TableCell>
              <TableCell>items</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {[...ticker].reverse().map((row, i) => (
              <TableRow key={`${row.at_ms}-t-${i}`}>
                <TableCell>{String(row.at_ms)}</TableCell>
                <TableCell sx={{ fontFamily: 'monospace', fontSize: 12, maxWidth: 640 }}>
                  {JSON.stringify(row.items)}
                </TableCell>
              </TableRow>
            ))}
            {ticker.length === 0 && (
              <TableRow>
                <TableCell colSpan={2}>No ticker program snapshots yet.</TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Stack>
  );
}
