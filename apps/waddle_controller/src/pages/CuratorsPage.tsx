import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
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
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { curatorCategoryMaterialIconComponent } from '@/util/curatorCategoryMaterialIcon';

type CuratorSettings = {
  require_news_photo_for_screens: boolean;
};

type CuratorCategoryRow = {
  id: string;
  label: string;
  material_icon_name: string | null;
  icon_blob_key: string | null;
  reserved: boolean;
};

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

/** Partial mask with literal `***`; full term in tooltip. */
export function maskRejectTermForDisplay(term: string): string {
  const t = term.trim();
  if (t.length === 0) return '';
  if (t.length === 1) return '*';
  if (t.length === 2) return `${t[0]}*`;
  return `${t[0]}***${t[t.length - 1]}`;
}

const defaultCatRowsPerPage = 10;
const defaultRejRowsPerPage = 10;

export function CuratorsPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canCuratorRead = hasPermission('curator.read');
  const canCuratorWrite = hasPermission('curator.write');
  const canRejectTerms = hasPermission('reject_terms.manage');

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [photoForm, setPhotoForm] = useState<CuratorSettings | null>(null);

  const [categories, setCategories] = useState<CuratorCategoryRow[]>([]);
  const [catEdits, setCatEdits] = useState<Record<string, { label: string; material: string }>>({});
  const [newCat, setNewCat] = useState({ id: '', label: '', material: '' });
  const [catFilter, setCatFilter] = useState('');
  const [catPage, setCatPage] = useState(0);
  const [catRowsPerPage, setCatRowsPerPage] = useState(defaultCatRowsPerPage);

  const [rejectItems, setRejectItems] = useState<RejectTermRow[]>([]);
  const [censorFormat, setCensorFormat] = useState('asterisks_full');
  const [newTerm, setNewTerm] = useState({ term: '', action: 'censor' });
  const [rejectMsg, setRejectMsg] = useState<string | null>(null);
  const [rejFilter, setRejFilter] = useState('');
  const [rejPage, setRejPage] = useState(0);
  const [rejRowsPerPage, setRejRowsPerPage] = useState(defaultRejRowsPerPage);

  const load = useCallback(async () => {
    if (!active) return;
    setLoading(true);
    setError(null);
    setRejectMsg(null);
    try {
      if (canCuratorRead) {
        const settings = await apiJson<{
          require_news_photo_for_screens: boolean;
        }>(active, '/v1/curator/settings');
        setPhotoForm({ require_news_photo_for_screens: settings.require_news_photo_for_screens });

        const catBody = await apiJson<{ items: CuratorCategoryRow[] }>(active, '/v1/curator/categories');
        setCategories(catBody.items);
        const next: Record<string, { label: string; material: string }> = {};
        for (const c of catBody.items) {
          next[c.id] = {
            label: c.label,
            material: c.material_icon_name ?? '',
          };
        }
        setCatEdits(next);
      } else {
        setPhotoForm(null);
        setCategories([]);
      }

      if (canRejectTerms) {
        const rj = await apiJson<{ items: RejectTermRow[]; censor_format: string }>(
          active,
          '/v1/reject-terms',
        );
        setRejectItems(rj.items);
        setCensorFormat(rj.censor_format || 'asterisks_full');
      } else {
        setRejectItems([]);
      }
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setLoading(false);
    }
  }, [active, canCuratorRead, canRejectTerms]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    setCatPage(0);
  }, [catFilter]);

  useEffect(() => {
    setRejPage(0);
  }, [rejFilter]);

  const filteredCategories = useMemo(() => {
    const q = catFilter.trim().toLowerCase();
    if (!q) return categories;
    return categories.filter((c) => {
      const ed = catEdits[c.id];
      const mat = (ed?.material ?? c.material_icon_name ?? '').toLowerCase();
      return (
        c.id.toLowerCase().includes(q) ||
        c.label.toLowerCase().includes(q) ||
        mat.includes(q) ||
        (c.reserved ? 'seeded' : '').includes(q)
      );
    });
  }, [categories, catFilter, catEdits]);

  const pagedCategories = useMemo(
    () => filteredCategories.slice(catPage * catRowsPerPage, catPage * catRowsPerPage + catRowsPerPage),
    [filteredCategories, catPage, catRowsPerPage],
  );

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
    const last = Math.max(0, Math.ceil(filteredCategories.length / catRowsPerPage) - 1);
    if (catPage > last) setCatPage(last);
  }, [filteredCategories.length, catRowsPerPage, catPage]);

  useEffect(() => {
    const last = Math.max(0, Math.ceil(filteredRejectItems.length / rejRowsPerPage) - 1);
    if (rejPage > last) setRejPage(last);
  }, [filteredRejectItems.length, rejRowsPerPage, rejPage]);

  const saveNewsPhoto = async () => {
    if (!active || !photoForm || !canCuratorWrite) return;
    setError(null);
    setSaved(false);
    try {
      await apiJson(active, '/v1/curator/settings', {
        method: 'PUT',
        body: JSON.stringify({
          require_news_photo_for_screens: photoForm.require_news_photo_for_screens,
        }),
      });
      setSaved(true);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const saveCategoryRow = async (id: string) => {
    if (!active || !canCuratorWrite) return;
    const ed = catEdits[id];
    if (!ed) return;
    setError(null);
    try {
      await apiJson(active, `/v1/curator/categories/${encodeURIComponent(id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          label: ed.label,
          material_icon_name: ed.material.trim() || null,
        }),
      });
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const addCategory = async () => {
    if (!active || !canCuratorWrite) return;
    setError(null);
    try {
      await apiJson(active, '/v1/curator/categories', {
        method: 'POST',
        body: JSON.stringify({
          id: newCat.id.trim(),
          label: newCat.label.trim(),
          material_icon_name: newCat.material.trim() || null,
        }),
      });
      setNewCat({ id: '', label: '', material: '' });
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const removeCategory = async (id: string) => {
    if (!active || !canCuratorWrite) return;
    setError(null);
    try {
      await apiJson(active, `/v1/curator/categories/${encodeURIComponent(id)}`, {
        method: 'DELETE',
      });
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const addRejectTerm = async () => {
    if (!active || !canRejectTerms) return;
    const t = newTerm.term.trim().toLowerCase();
    if (!t) return;
    setRejectMsg(null);
    try {
      await apiJson(active, '/v1/reject-terms', {
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
    if (!active || !canRejectTerms) return;
    setRejectMsg(null);
    try {
      await apiJson(active, `/v1/reject-terms/${encodeURIComponent(id)}`, {
        method: 'DELETE',
      });
      await load();
    } catch (e) {
      setRejectMsg(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const saveCensorFormat = async () => {
    if (!active || !canRejectTerms) return;
    setRejectMsg(null);
    try {
      await apiJson(active, '/v1/reject-terms/format', {
        method: 'PUT',
        body: JSON.stringify({ format: censorFormat }),
      });
      await load();
    } catch (e) {
      setRejectMsg(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  if (!canCuratorRead && !canRejectTerms) {
    return (
      <Typography color="text.secondary">
        You do not have permission to view curator categories or rejected terms.
      </Typography>
    );
  }

  if (loading) {
    return <Typography>Loading curator…</Typography>;
  }

  return (
    <Stack spacing={3} sx={{ maxWidth: 960 }}>
      {error && <Alert severity="error">{error}</Alert>}
      {saved && <Alert severity="success">News photo setting saved.</Alert>}

      {canCuratorWrite && photoForm && (
        <Box>
          <Typography variant="subtitle1" gutterBottom>
            News slides
          </Typography>
          <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
            <Switch
              checked={photoForm.require_news_photo_for_screens}
              onChange={(_, v) => setPhotoForm({ ...photoForm, require_news_photo_for_screens: v })}
            />
            <Typography>Require news photo for screen slides</Typography>
          </Stack>
          <Button variant="contained" onClick={() => void saveNewsPhoto()}>
            Save news photo setting
          </Button>
        </Box>
      )}

      {canCuratorRead && (
        <Box>
          <Typography variant="subtitle1" gutterBottom>
            Curator categories
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
            Shared labels for RSS, media, calendar, and other content. Ids are lowercase slugs; seeded
            defaults cannot be deleted.
          </Typography>
          <TextField
            label="Filter categories"
            size="small"
            value={catFilter}
            onChange={(e) => setCatFilter(e.target.value)}
            fullWidth
            sx={{ maxWidth: 400, mb: 1 }}
            placeholder="Id, label, or material icon name"
          />
          <TableContainer>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell sx={{ minWidth: 200 }}>Category</TableCell>
                  <TableCell>Label</TableCell>
                  <TableCell sx={{ minWidth: 140 }}>Material icon name</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {pagedCategories.map((c) => {
                  const ed = catEdits[c.id] ?? { label: c.label, material: c.material_icon_name ?? '' };
                  const iconName = ed.material.trim() || c.material_icon_name;
                  const IconComp = curatorCategoryMaterialIconComponent(iconName);
                  return (
                    <TableRow key={c.id}>
                      <TableCell>
                        <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                          <IconComp sx={{ fontSize: 22, color: 'action.active' }} aria-hidden />
                          <Typography variant="body2" component="span" fontWeight={600}>
                            {c.id}
                          </Typography>
                          {c.reserved && <Chip size="small" label="seeded" variant="outlined" />}
                        </Stack>
                      </TableCell>
                      <TableCell sx={{ minWidth: 160 }}>
                        <TextField
                          size="small"
                          fullWidth
                          value={ed.label}
                          disabled={!canCuratorWrite}
                          onChange={(e) =>
                            setCatEdits({
                              ...catEdits,
                              [c.id]: { ...ed, label: e.target.value },
                            })
                          }
                        />
                      </TableCell>
                      <TableCell>
                        <TextField
                          size="small"
                          fullWidth
                          value={ed.material}
                          disabled={!canCuratorWrite}
                          onChange={(e) =>
                            setCatEdits({
                              ...catEdits,
                              [c.id]: { ...ed, material: e.target.value },
                            })
                          }
                        />
                      </TableCell>
                      <TableCell align="right">
                        {canCuratorWrite && (
                          <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                            <Button size="small" onClick={() => void saveCategoryRow(c.id)}>
                              Save
                            </Button>
                            {!c.reserved && (
                              <IconButton
                                size="small"
                                aria-label="Delete category"
                                onClick={() => void removeCategory(c.id)}
                              >
                                <DeleteOutlineIcon fontSize="small" />
                              </IconButton>
                            )}
                          </Stack>
                        )}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
              <TableFooter>
                <TableRow>
                  <TableCell colSpan={4} sx={{ borderBottom: 'none', py: 0 }}>
                    <TablePagination
                      component="div"
                      count={filteredCategories.length}
                      page={catPage}
                      onPageChange={(_, p) => setCatPage(p)}
                      rowsPerPage={catRowsPerPage}
                      onRowsPerPageChange={(e) => {
                        setCatRowsPerPage(parseInt(e.target.value, 10));
                        setCatPage(0);
                      }}
                      rowsPerPageOptions={[5, 10, 25, 50]}
                    />
                  </TableCell>
                </TableRow>
              </TableFooter>
            </Table>
          </TableContainer>

          {canCuratorWrite && (
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{ mt: 2 }} alignItems="flex-start">
              <TextField
                label="New id (slug)"
                size="small"
                value={newCat.id}
                onChange={(e) => setNewCat({ ...newCat, id: e.target.value })}
              />
              <TextField
                label="Label"
                size="small"
                value={newCat.label}
                onChange={(e) => setNewCat({ ...newCat, label: e.target.value })}
              />
              <TextField
                label="Material icon"
                size="small"
                value={newCat.material}
                onChange={(e) => setNewCat({ ...newCat, material: e.target.value })}
              />
              <Button variant="outlined" onClick={() => void addCategory()}>
                Add category
              </Button>
            </Stack>
          )}
        </Box>
      )}

      {canRejectTerms && (
        <Box>
          <Typography variant="subtitle1" gutterBottom>
            Rejected terms
          </Typography>
          {rejectMsg && <Alert severity="error">{rejectMsg}</Alert>}
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{ mb: 2 }} alignItems="center">
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
            sx={{ maxWidth: 400, mb: 1 }}
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
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{ mt: 2 }} alignItems="center">
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
        </Box>
      )}
    </Stack>
  );
}
