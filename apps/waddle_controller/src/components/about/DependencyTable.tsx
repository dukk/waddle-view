import {
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { useMemo, useState } from 'react';
import type { DependencyInfo } from '@/api/bffAbout';

export function DependencyTable({
  title,
  rows,
  emptyMessage,
}: {
  title: string;
  rows: DependencyInfo[];
  emptyMessage?: string;
}) {
  const [filter, setFilter] = useState('');

  const filtered = useMemo(() => {
    const q = filter.trim().toLowerCase();
    const sorted = [...rows].sort((a, b) => a.name.localeCompare(b.name));
    if (!q) return sorted;
    return sorted.filter(
      (r) =>
        r.name.toLowerCase().includes(q) ||
        r.version.toLowerCase().includes(q) ||
        (r.license ?? '').toLowerCase().includes(q),
    );
  }, [rows, filter]);

  return (
    <>
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        {title}
      </Typography>
      <TextField
        size="small"
        label="Filter dependencies"
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        fullWidth
        sx={{ mb: 1.5, maxWidth: 400 }}
      />
      {filtered.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          {emptyMessage ?? 'No dependencies match the filter.'}
        </Typography>
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Package</TableCell>
                <TableCell>Version</TableCell>
                <TableCell>License</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filtered.map((row) => (
                <TableRow key={`${row.name}@${row.version}`}>
                  <TableCell sx={{ fontFamily: 'monospace' }}>{row.name}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace' }}>{row.version}</TableCell>
                  <TableCell>{row.license?.trim() || '—'}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </>
  );
}
