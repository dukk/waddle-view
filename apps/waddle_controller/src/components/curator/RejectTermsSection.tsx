import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Button,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableFooter,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import type { SavedDisplay } from '@/storage/displays';
import { apiJson, ApiError } from '@/api/client';
import { maskRejectTermForDisplay } from '@/util/maskRejectTerm';

type RejectTermRow = {
  id: string;
  term: string;
  action: string;
};

const censorFormats = [
  { id: 'asterisks_full', label: 'Asterisks (full length)' },
  { id: 'asterisks_fixed', label: 'Asterisks (fixed 4)' },
  { id: 'first_last', label: 'First / last letter' },
  { id: 'bracketed_token', label: 'Bracketed [censored]' },
];

const defaultRejRowsPerPage = 10;

export function RejectTermsSection({ display }: { display: SavedDisplay }) {
  const [loading, setLoading] = useState(true);
  const [rejectMsg, setRejectMsg] = useState<string | null>(null);
  const [rejectItems, setRejectItems] = useState<RejectTermRow[]>([]);
  const [censorFormat, setCensorFormat] = useState('asterisks_full');
  const [newTerm, setNewTerm] = useState({ term: '', action: 'censor' });
  const [rejFilter, setRejFilter] = useState('');
  const [rejPage, setRejPage] = useState(0);
  const [rejRowsPerPage, setRejRowsPerPage] = useState(defaultRejRowsPerPage);

  const load = useCallback(async () => {
    setLoading(true);
    setRejectMsg(null);
    try {
      const rj = await apiJson<{ items: RejectTermRow[]; censor_format: string }>(
        display,
        '/v1/reject-terms',
      );
      setRejectItems(rj.items);
      setCensorFormat(rj.censor_format || 'asterisks_full');
    } catch (e) {
      setRejectMsg(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setLoading(false);
    }
  }, [display]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    setRejPage(0);
  }, [rejFilter]);

  const filteredRejectItems = useMemo(() => {
    const q = rejFilter.trim().toLowerCase();
    if (!q) return rejectItems;
    return rejectItems.filter(
      (r) => r.term.toLowerCase().includes(q) || r.action.toLowerCase().includes(q),
    );
  }, [rejectItems, rejFilter]);

  const pagedRejectItems = useMemo(
    () => filteredRejectItems.slice(rejPage * rejRowsPerPage, rejPage * rejRowsPerPage + rejRowsPerPage),
    [filteredRejectItems, rejPage, rejRowsPerPage],
  );

  useEffect(() => {
    const last = Math.max(0, Math.ceil(filteredRejectItems.length / rejRowsPerPage) - 1);
    if (rejPage > last) setRejPage(last);
  }, [filteredRejectItems.length, rejRowsPerPage, rejPage]);

  const addRejectTerm = async () => {
    const t = newTerm.term.trim().toLowerCase();
    if (!t) return;
    setRejectMsg(null);
    try {
      await apiJson(display, '/v1/reject-terms', {
        method: 'POST',
        body: JSON.stringify({ term: t, action: newTerm.action }),
      });
      setNewTerm({ term: '', action: 'censor' });
      await load();
    } catch (e) {
      setRejectMsg(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const removeRejectTerm = async (id: string) => {
    setRejectMsg(null);
    try {
      await apiJson(display, `/v1/reject-terms/${encodeURIComponent(id)}`, {
        method: 'DELETE',
      });
      await load();
    } catch (e) {
      setRejectMsg(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const saveCensorFormat = async () => {
    setRejectMsg(null);
    try {
      await apiJson(display, '/v1/reject-terms/format', {
        method: 'PUT',
        body: JSON.stringify({ format: censorFormat }),
      });
      await load();
    } catch (e) {
      setRejectMsg(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  if (loading) {
    return <Typography variant="body2">Loading rejected terms…</Typography>;
  }

  return (
    <Stack spacing={2}>
      {rejectMsg && (
        <Alert severity="error" onClose={() => setRejectMsg(null)}>
          {rejectMsg}
        </Alert>
      )}
      <Typography variant="body2" color="text.secondary">
        Terms matched in incoming content are censored or blocked according to each row&apos;s
        action. The mask format applies to censored terms in the UI and on displays.
      </Typography>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems="center">
        <FormControl size="small" sx={{ minWidth: 220 }}>
          <InputLabel id="censor-fmt">Censor mask format</InputLabel>
          <Select
            labelId="censor-fmt"
            label="Censor mask format"
            value={censorFormat}
            onChange={(e) => setCensorFormat(String(e.target.value))}
          >
            {censorFormats.map((f) => (
              <MenuItem key={f.id} value={f.id}>
                {f.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        <Button variant="outlined" onClick={() => void saveCensorFormat()}>
          Save format
        </Button>
      </Stack>
      <TextField
        label="Filter terms"
        size="small"
        value={rejFilter}
        onChange={(e) => setRejFilter(e.target.value)}
        fullWidth
        sx={{ maxWidth: 400 }}
        placeholder="Term or action"
      />
      <TableContainer>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Term</TableCell>
              <TableCell>Action</TableCell>
              <TableCell align="right"> </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {pagedRejectItems.map((r) => (
              <TableRow key={r.id}>
                <TableCell>
                  <Tooltip title={r.term} enterDelay={400}>
                    <Typography
                      component="span"
                      variant="body2"
                      sx={{ cursor: 'help', fontFamily: 'monospace' }}
                    >
                      {maskRejectTermForDisplay(r.term)}
                    </Typography>
                  </Tooltip>
                </TableCell>
                <TableCell>{r.action}</TableCell>
                <TableCell align="right">
                  <IconButton
                    size="small"
                    aria-label="Delete term"
                    onClick={() => void removeRejectTerm(r.id)}
                  >
                    <DeleteOutlineIcon fontSize="small" />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
          <TableFooter>
            <TableRow>
              <TableCell colSpan={3} sx={{ borderBottom: 'none', py: 0 }}>
                <TablePagination
                  component="div"
                  count={filteredRejectItems.length}
                  page={rejPage}
                  onPageChange={(_, p) => setRejPage(p)}
                  rowsPerPage={rejRowsPerPage}
                  onRowsPerPageChange={(e) => {
                    setRejRowsPerPage(parseInt(e.target.value, 10));
                    setRejPage(0);
                  }}
                  rowsPerPageOptions={[5, 10, 25, 50]}
                />
              </TableCell>
            </TableRow>
          </TableFooter>
        </Table>
      </TableContainer>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems="center">
        <TextField
          label="New term"
          size="small"
          value={newTerm.term}
          onChange={(e) => setNewTerm({ ...newTerm, term: e.target.value })}
        />
        <FormControl size="small" sx={{ minWidth: 120 }}>
          <InputLabel id="rej-act">Action</InputLabel>
          <Select
            labelId="rej-act"
            label="Action"
            value={newTerm.action}
            onChange={(e) => setNewTerm({ ...newTerm, action: String(e.target.value) })}
          >
            <MenuItem value="censor">censor</MenuItem>
            <MenuItem value="block">block</MenuItem>
          </Select>
        </FormControl>
        <Button variant="outlined" onClick={() => void addRejectTerm()}>
          Add term
        </Button>
      </Stack>
    </Stack>
  );
}
