import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  IconButton,
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
  Typography,
} from '@mui/material';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import type { SavedDisplay } from '@/storage/displays';
import { apiJson, ApiError } from '@/api/client';
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

const defaultCatRowsPerPage = 10;

export function CuratorCategoriesSection({
  display,
  canWrite,
}: {
  display: SavedDisplay;
  canWrite: boolean;
}) {
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

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const settings = await apiJson<{
        require_news_photo_for_screens: boolean;
      }>(display, '/v1/curator/settings');
      setPhotoForm({ require_news_photo_for_screens: settings.require_news_photo_for_screens });

      const catBody = await apiJson<{ items: CuratorCategoryRow[] }>(display, '/v1/curator/categories');
      setCategories(catBody.items);
      const next: Record<string, { label: string; material: string }> = {};
      for (const c of catBody.items) {
        next[c.id] = {
          label: c.label,
          material: c.material_icon_name ?? '',
        };
      }
      setCatEdits(next);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    } finally {
      setLoading(false);
    }
  }, [display]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    setCatPage(0);
  }, [catFilter]);

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

  useEffect(() => {
    const last = Math.max(0, Math.ceil(filteredCategories.length / catRowsPerPage) - 1);
    if (catPage > last) setCatPage(last);
  }, [filteredCategories.length, catRowsPerPage, catPage]);

  const saveNewsPhoto = async () => {
    if (!photoForm || !canWrite) return;
    setError(null);
    setSaved(false);
    try {
      await apiJson(display, '/v1/curator/settings', {
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
    if (!canWrite) return;
    const ed = catEdits[id];
    if (!ed) return;
    setError(null);
    try {
      await apiJson(display, `/v1/curator/categories/${encodeURIComponent(id)}`, {
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
    if (!canWrite) return;
    setError(null);
    try {
      await apiJson(display, '/v1/curator/categories', {
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
    if (!canWrite) return;
    setError(null);
    try {
      await apiJson(display, `/v1/curator/categories/${encodeURIComponent(id)}`, {
        method: 'DELETE',
      });
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  if (loading) {
    return <Typography variant="body2">Loading categories…</Typography>;
  }

  return (
    <Stack spacing={3}>
      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {canWrite && photoForm && (
        <Box>
          <Typography variant="subtitle2" gutterBottom>
            News slides
          </Typography>
          {saved && (
            <Alert severity="success" sx={{ mb: 1 }} onClose={() => setSaved(false)}>
              News photo setting saved.
            </Alert>
          )}
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch
              checked={photoForm.require_news_photo_for_screens}
              onChange={(_, v) =>
                setPhotoForm({ ...photoForm, require_news_photo_for_screens: v })
              }
            />
            <Typography variant="body2">Require news photo for screen slides</Typography>
          </Stack>
          <Button variant="contained" size="small" sx={{ mt: 1 }} onClick={() => void saveNewsPhoto()}>
            Save news photo setting
          </Button>
        </Box>
      )}

      <Box>
        <Typography variant="subtitle2" gutterBottom>
          Content categories
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Shared labels for RSS, media, calendar, and other content. Ids are lowercase slugs; seeded
          defaults cannot be deleted.
        </Typography>
        <TextField
          label="Filter categories"
          size="small"
          value={catFilter}
          onChange={(e) => setCatFilter(e.target.value)}
          fullWidth
          sx={{ maxWidth: 400, mb: 2 }}
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
                        disabled={!canWrite}
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
                        disabled={!canWrite}
                        onChange={(e) =>
                          setCatEdits({
                            ...catEdits,
                            [c.id]: { ...ed, material: e.target.value },
                          })
                        }
                      />
                    </TableCell>
                    <TableCell align="right">
                      {canWrite && (
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

        {canWrite && (
          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={1}
            sx={{ mt: 2 }}
            alignItems="flex-start"
          >
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
    </Stack>
  );
}
