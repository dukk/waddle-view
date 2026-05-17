import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import EditIcon from '@mui/icons-material/Edit';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import {
  createJokeCategory,
  createRssFeed,
  createStockSymbol,
  createTriviaCategory,
  createWeatherLocation,
  deleteJokeCategory,
  deleteRssFeed,
  deleteStockSymbol,
  deleteTriviaCategory,
  deleteWeatherLocation,
  listJokeCategories,
  listRssFeeds,
  listStockSymbols,
  listTriviaCategories,
  listWeatherLocations,
  patchJokeCategory,
  patchRssFeed,
  patchStockSymbol,
  patchTriviaCategory,
  patchWeatherLocation,
  type CategoryInterestRow,
  type RssFeedRow,
  type StockSymbolRow,
  type WeatherLocationRow,
} from '@/api/interests';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';

type TabId = 'weather' | 'rss' | 'stocks' | 'jokes' | 'trivia';

type CuratorCategoryOption = { id: string; label: string };

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

export function InterestsPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('interests.write');
  const { loading, wrapRefresh } = useDisplayRefresh();

  const [tab, setTab] = useState<TabId>('weather');
  const [error, setError] = useState<string | null>(null);

  const [weather, setWeather] = useState<WeatherLocationRow[]>([]);
  const [rss, setRss] = useState<RssFeedRow[]>([]);
  const [stocks, setStocks] = useState<StockSymbolRow[]>([]);
  const [jokes, setJokes] = useState<CategoryInterestRow[]>([]);
  const [trivia, setTrivia] = useState<CategoryInterestRow[]>([]);
  const [curatorCategories, setCuratorCategories] = useState<CuratorCategoryOption[]>([]);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingWeather, setEditingWeather] = useState<WeatherLocationRow | null>(null);
  const [editingRss, setEditingRss] = useState<RssFeedRow | null>(null);
  const [editingStock, setEditingStock] = useState<StockSymbolRow | null>(null);
  const [editingJoke, setEditingJoke] = useState<CategoryInterestRow | null>(null);
  const [editingTrivia, setEditingTrivia] = useState<CategoryInterestRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const [w, r, s, j, t, cats] = await Promise.all([
          listWeatherLocations(active),
          listRssFeeds(active),
          listStockSymbols(active),
          listJokeCategories(active),
          listTriviaCategories(active),
          apiJson<{ items: CuratorCategoryOption[] }>(active, '/v1/curator/categories'),
        ]);
        setWeather(w);
        setRss(r);
        setStocks(s);
        setJokes(j);
        setTrivia(t);
        setCuratorCategories(cats.items.map((c) => ({ id: c.id, label: c.label })));
      } catch (e) {
        setError(errMsg(e));
      }
    });
  }, [active, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  const openAdd = () => {
    setEditingWeather(null);
    setEditingRss(null);
    setEditingStock(null);
    setEditingJoke(null);
    setEditingTrivia(null);
    setDialogOpen(true);
  };

  const openEditWeather = (row: WeatherLocationRow) => {
    setEditingWeather(row);
    setDialogOpen(true);
  };

  const openEditRss = (row: RssFeedRow) => {
    setEditingRss(row);
    setDialogOpen(true);
  };

  const openEditStock = (row: StockSymbolRow) => {
    setEditingStock(row);
    setDialogOpen(true);
  };

  const openEditJoke = (row: CategoryInterestRow) => {
    setEditingJoke(row);
    setDialogOpen(true);
  };

  const openEditTrivia = (row: CategoryInterestRow) => {
    setEditingTrivia(row);
    setDialogOpen(true);
  };

  const dialogTitle = useMemo(() => {
    if (tab === 'weather') return editingWeather ? 'Edit weather location' : 'Add weather location';
    if (tab === 'rss') return editingRss ? 'Edit RSS feed' : 'Add RSS feed';
    if (tab === 'stocks') return editingStock ? 'Edit stock symbol' : 'Add stock symbol';
    if (tab === 'jokes') return editingJoke ? 'Edit joke category' : 'Add joke category';
    return editingTrivia ? 'Edit trivia category' : 'Add trivia category';
  }, [tab, editingWeather, editingRss, editingStock, editingJoke, editingTrivia]);

  if (!active) {
    return <NoDisplayPlaceholder title="Interests" />;
  }

  return (
    <Stack spacing={2}>
      <Stack direction="row" alignItems="center" justifyContent="space-between" flexWrap="wrap" gap={1}>
        <Box>
          <Typography variant="h5">Interests</Typography>
          <Typography variant="body2" color="text.secondary">
            Configure what weather locations, news feeds, stocks, joke categories, and trivia categories
            the display collects.
          </Typography>
        </Box>
        <Stack direction="row" alignItems="center" spacing={1}>
          {canWrite && (
            <Button variant="contained" startIcon={<AddIcon />} onClick={openAdd}>
              Add
            </Button>
          )}
        </Stack>
      </Stack>

      <DisplayRefreshIndicator loading={loading} />

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Tabs value={tab} onChange={(_, v: TabId) => setTab(v)} variant="scrollable">
        <Tab value="weather" label="Weather" />
        <Tab value="rss" label="RSS" />
        <Tab value="stocks" label="Stocks" />
        <Tab value="jokes" label="Jokes" />
        <Tab value="trivia" label="Trivia" />
      </Tabs>

      {tab === 'weather' && (
        <InterestTable
          columns={['ID', 'Name', 'Lat', 'Lon', 'Enabled', 'Alerts', '']}
          rows={weather.map((row) => (
            <TableRow key={row.id}>
              <TableCell>{row.id}</TableCell>
              <TableCell>{row.name}</TableCell>
              <TableCell>{row.latitude}</TableCell>
              <TableCell>{row.longitude}</TableCell>
              <TableCell>{row.enabled ? 'Yes' : 'No'}</TableCell>
              <TableCell>{row.include_active_weather_alerts ? 'Yes' : 'No'}</TableCell>
              <TableCell align="right">
                {canWrite && (
                  <RowActions
                    onEdit={() => openEditWeather(row)}
                    onDelete={async () => {
                      try {
                        await deleteWeatherLocation(active, row.id);
                        await load();
                      } catch (e) {
                        setError(errMsg(e));
                      }
                    }}
                  />
                )}
              </TableCell>
            </TableRow>
          ))}
        />
      )}

      {tab === 'rss' && (
        <InterestTable
          columns={['ID', 'URL', 'Category', 'Poll (s)', 'Max', 'Enabled', '']}
          rows={rss.map((row) => (
            <TableRow key={row.id}>
              <TableCell>{row.id}</TableCell>
              <TableCell sx={{ maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {row.url}
              </TableCell>
              <TableCell>{row.category}</TableCell>
              <TableCell>{row.poll_seconds}</TableCell>
              <TableCell>{row.max_articles}</TableCell>
              <TableCell>{row.enabled ? 'Yes' : 'No'}</TableCell>
              <TableCell align="right">
                {canWrite && (
                  <RowActions
                    onEdit={() => openEditRss(row)}
                    onDelete={async () => {
                      try {
                        await deleteRssFeed(active, row.id);
                        await load();
                      } catch (e) {
                        setError(errMsg(e));
                      }
                    }}
                  />
                )}
              </TableCell>
            </TableRow>
          ))}
        />
      )}

      {tab === 'stocks' && (
        <InterestTable
          columns={['ID', 'Symbol', 'Display name', 'Enabled', '']}
          rows={stocks.map((row) => (
            <TableRow key={row.id}>
              <TableCell>{row.id}</TableCell>
              <TableCell>{row.symbol}</TableCell>
              <TableCell>{row.display_name}</TableCell>
              <TableCell>{row.enabled ? 'Yes' : 'No'}</TableCell>
              <TableCell align="right">
                {canWrite && (
                  <RowActions
                    onEdit={() => openEditStock(row)}
                    onDelete={async () => {
                      try {
                        await deleteStockSymbol(active, row.id);
                        await load();
                      } catch (e) {
                        setError(errMsg(e));
                      }
                    }}
                  />
                )}
              </TableCell>
            </TableRow>
          ))}
        />
      )}

      {tab === 'jokes' && (
        <CategoryTable
          rows={jokes}
          canWrite={canWrite}
          onEdit={openEditJoke}
          onDelete={async (id) => {
            await deleteJokeCategory(active, id);
            await load();
          }}
          onError={setError}
        />
      )}

      {tab === 'trivia' && (
        <CategoryTable
          rows={trivia}
          canWrite={canWrite}
          onEdit={openEditTrivia}
          onDelete={async (id) => {
            await deleteTriviaCategory(active, id);
            await load();
          }}
          onError={setError}
        />
      )}

      <InterestDialog
        open={dialogOpen}
        title={dialogTitle}
        tab={tab}
        canWrite={canWrite}
        curatorCategories={curatorCategories}
        editingWeather={editingWeather}
        editingRss={editingRss}
        editingStock={editingStock}
        editingJoke={editingJoke}
        editingTrivia={editingTrivia}
        onClose={() => setDialogOpen(false)}
        onSaved={async () => {
          setDialogOpen(false);
          await load();
        }}
        onError={setError}
        display={active}
      />
    </Stack>
  );
}

function InterestTable({
  columns,
  rows,
}: {
  columns: string[];
  rows: ReactNode[];
}) {
  return (
    <TableContainer>
      <Table size="small">
        <TableHead>
          <TableRow>
            {columns.map((c) => (
              <TableCell key={c}>{c}</TableCell>
            ))}
          </TableRow>
        </TableHead>
        <TableBody>{rows}</TableBody>
      </Table>
    </TableContainer>
  );
}

function RowActions({ onEdit, onDelete }: { onEdit: () => void; onDelete: () => Promise<void> }) {
  return (
    <>
      <IconButton size="small" aria-label="Edit" onClick={onEdit}>
        <EditIcon fontSize="small" />
      </IconButton>
      <IconButton
        size="small"
        aria-label="Delete"
        onClick={() => {
          void onDelete();
        }}
      >
        <DeleteOutlineIcon fontSize="small" />
      </IconButton>
    </>
  );
}

function CategoryTable({
  rows,
  canWrite,
  onEdit,
  onDelete,
  onError,
}: {
  rows: CategoryInterestRow[];
  canWrite: boolean;
  onEdit: (row: CategoryInterestRow) => void;
  onDelete: (id: string) => Promise<void>;
  onError: (msg: string) => void;
}) {
  return (
    <InterestTable
      columns={['ID', 'Label', 'Seasonal', 'Min', 'Max', '']}
      rows={rows.map((row) => (
        <TableRow key={row.id}>
          <TableCell>{row.id}</TableCell>
          <TableCell>{row.label}</TableCell>
          <TableCell>{row.is_seasonal ? 'Yes' : 'No'}</TableCell>
          <TableCell>{row.min_jokes ?? row.min_questions ?? '—'}</TableCell>
          <TableCell>{row.max_jokes ?? row.max_questions ?? '—'}</TableCell>
          <TableCell align="right">
            {canWrite && (
              <RowActions
                onEdit={() => onEdit(row)}
                onDelete={async () => {
                  try {
                    await onDelete(row.id);
                  } catch (e) {
                    onError(errMsg(e));
                  }
                }}
              />
            )}
          </TableCell>
        </TableRow>
      ))}
    />
  );
}

function InterestDialog({
  open,
  title,
  tab,
  canWrite,
  curatorCategories,
  editingWeather,
  editingRss,
  editingStock,
  editingJoke,
  editingTrivia,
  onClose,
  onSaved,
  onError,
  display,
}: {
  open: boolean;
  title: string;
  tab: TabId;
  canWrite: boolean;
  curatorCategories: CuratorCategoryOption[];
  editingWeather: WeatherLocationRow | null;
  editingRss: RssFeedRow | null;
  editingStock: StockSymbolRow | null;
  editingJoke: CategoryInterestRow | null;
  editingTrivia: CategoryInterestRow | null;
  onClose: () => void;
  onSaved: () => Promise<void>;
  onError: (msg: string) => void;
  display: NonNullable<ReturnType<typeof useDisplay>['active']>;
}) {
  const [weatherForm, setWeatherForm] = useState({
    id: '',
    name: '',
    latitude: '',
    longitude: '',
    enabled: true,
    include_active_weather_alerts: true,
  });
  const [rssForm, setRssForm] = useState({
    id: '',
    url: '',
    category: 'general',
    poll_seconds: '3600',
    max_articles: '3',
    enabled: true,
    title: '',
  });
  const [stockForm, setStockForm] = useState({
    id: '',
    symbol: '',
    display_name: '',
    enabled: true,
  });
  const [categoryForm, setCategoryForm] = useState({
    id: '',
    label: '',
    is_seasonal: false,
    category_prompt: '',
    min_pool: '10',
    max_pool: '100',
  });

  useEffect(() => {
    if (!open) return;
    if (editingWeather) {
      setWeatherForm({
        id: editingWeather.id,
        name: editingWeather.name,
        latitude: String(editingWeather.latitude),
        longitude: String(editingWeather.longitude),
        enabled: editingWeather.enabled,
        include_active_weather_alerts: editingWeather.include_active_weather_alerts,
      });
    } else if (tab === 'weather') {
      setWeatherForm({
        id: '',
        name: '',
        latitude: '',
        longitude: '',
        enabled: true,
        include_active_weather_alerts: true,
      });
    }
    if (editingRss) {
      setRssForm({
        id: editingRss.id,
        url: editingRss.url,
        category: editingRss.category,
        poll_seconds: String(editingRss.poll_seconds),
        max_articles: String(editingRss.max_articles),
        enabled: editingRss.enabled,
        title: editingRss.title ?? '',
      });
    } else if (tab === 'rss') {
      setRssForm({
        id: '',
        url: '',
        category: curatorCategories[0]?.id ?? 'general',
        poll_seconds: '3600',
        max_articles: '3',
        enabled: true,
        title: '',
      });
    }
    if (editingStock) {
      setStockForm({
        id: editingStock.id,
        symbol: editingStock.symbol,
        display_name: editingStock.display_name,
        enabled: editingStock.enabled,
      });
    } else if (tab === 'stocks') {
      setStockForm({ id: '', symbol: '', display_name: '', enabled: true });
    }
    const cat = editingJoke ?? editingTrivia;
    if (cat) {
      setCategoryForm({
        id: cat.id,
        label: cat.label,
        is_seasonal: cat.is_seasonal,
        category_prompt: cat.category_prompt ?? '',
        min_pool: String(cat.min_jokes ?? cat.min_questions ?? 10),
        max_pool: String(cat.max_jokes ?? cat.max_questions ?? 100),
      });
    } else if (tab === 'jokes' || tab === 'trivia') {
      setCategoryForm({
        id: '',
        label: '',
        is_seasonal: false,
        category_prompt: '',
        min_pool: '10',
        max_pool: '100',
      });
    }
  }, [
    open,
    tab,
    editingWeather,
    editingRss,
    editingStock,
    editingJoke,
    editingTrivia,
    curatorCategories,
  ]);

  const save = async () => {
    if (!canWrite) return;
    try {
      if (tab === 'weather') {
        const lat = Number.parseFloat(weatherForm.latitude);
        const lon = Number.parseFloat(weatherForm.longitude);
        if (editingWeather) {
          await patchWeatherLocation(display, editingWeather.id, {
            name: weatherForm.name,
            latitude: lat,
            longitude: lon,
            enabled: weatherForm.enabled,
            include_active_weather_alerts: weatherForm.include_active_weather_alerts,
          });
        } else {
          await createWeatherLocation(display, {
            id: weatherForm.id,
            name: weatherForm.name,
            latitude: lat,
            longitude: lon,
            enabled: weatherForm.enabled,
            include_active_weather_alerts: weatherForm.include_active_weather_alerts,
          });
        }
      } else if (tab === 'rss') {
        const body = {
          url: rssForm.url,
          category: rssForm.category,
          poll_seconds: Number.parseInt(rssForm.poll_seconds, 10),
          max_articles: Number.parseInt(rssForm.max_articles, 10),
          enabled: rssForm.enabled,
          title: rssForm.title.trim() || null,
        };
        if (editingRss) {
          await patchRssFeed(display, editingRss.id, body);
        } else {
          await createRssFeed(display, { id: rssForm.id, ...body });
        }
      } else if (tab === 'stocks') {
        if (editingStock) {
          await patchStockSymbol(display, editingStock.id, {
            symbol: stockForm.symbol,
            display_name: stockForm.display_name,
            enabled: stockForm.enabled,
          });
        } else {
          await createStockSymbol(display, {
            id: stockForm.id,
            symbol: stockForm.symbol,
            display_name: stockForm.display_name,
            enabled: stockForm.enabled,
          });
        }
      } else if (tab === 'jokes') {
        const pool = {
          label: categoryForm.label,
          is_seasonal: categoryForm.is_seasonal,
          category_prompt: categoryForm.category_prompt || null,
          min_jokes: Number.parseInt(categoryForm.min_pool, 10),
          max_jokes: Number.parseInt(categoryForm.max_pool, 10),
        };
        if (editingJoke) {
          await patchJokeCategory(display, editingJoke.id, pool);
        } else {
          await createJokeCategory(display, { id: categoryForm.id, ...pool });
        }
      } else if (tab === 'trivia') {
        const pool = {
          label: categoryForm.label,
          is_seasonal: categoryForm.is_seasonal,
          category_prompt: categoryForm.category_prompt || null,
          min_questions: Number.parseInt(categoryForm.min_pool, 10),
          max_questions: Number.parseInt(categoryForm.max_pool, 10),
        };
        if (editingTrivia) {
          await patchTriviaCategory(display, editingTrivia.id, pool);
        } else {
          await createTriviaCategory(display, { id: categoryForm.id, ...pool });
        }
      }
      await onSaved();
    } catch (e) {
      onError(errMsg(e));
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>{title}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {tab === 'weather' && (
            <>
              <TextField
                label="ID"
                value={weatherForm.id}
                disabled={Boolean(editingWeather)}
                onChange={(e) => setWeatherForm((f) => ({ ...f, id: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Name"
                value={weatherForm.name}
                onChange={(e) => setWeatherForm((f) => ({ ...f, name: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Latitude"
                value={weatherForm.latitude}
                onChange={(e) => setWeatherForm((f) => ({ ...f, latitude: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Longitude"
                value={weatherForm.longitude}
                onChange={(e) => setWeatherForm((f) => ({ ...f, longitude: e.target.value }))}
                fullWidth
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={weatherForm.enabled}
                    onChange={(e) =>
                      setWeatherForm((f) => ({ ...f, enabled: e.target.checked }))
                    }
                  />
                }
                label="Enabled"
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={weatherForm.include_active_weather_alerts}
                    onChange={(e) =>
                      setWeatherForm((f) => ({
                        ...f,
                        include_active_weather_alerts: e.target.checked,
                      }))
                    }
                  />
                }
                label="Include active weather alerts"
              />
            </>
          )}
          {tab === 'rss' && (
            <>
              <TextField
                label="ID"
                value={rssForm.id}
                disabled={Boolean(editingRss)}
                onChange={(e) => setRssForm((f) => ({ ...f, id: e.target.value }))}
                fullWidth
              />
              <TextField
                label="URL"
                value={rssForm.url}
                onChange={(e) => setRssForm((f) => ({ ...f, url: e.target.value }))}
                fullWidth
              />
              <FormControl fullWidth>
                <InputLabel id="rss-cat-label">Category</InputLabel>
                <Select
                  labelId="rss-cat-label"
                  label="Category"
                  value={rssForm.category}
                  onChange={(e) => setRssForm((f) => ({ ...f, category: e.target.value }))}
                >
                  {curatorCategories.map((c) => (
                    <MenuItem key={c.id} value={c.id}>
                      {c.label} ({c.id})
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
              <TextField
                label="Poll seconds"
                value={rssForm.poll_seconds}
                onChange={(e) => setRssForm((f) => ({ ...f, poll_seconds: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Max articles"
                value={rssForm.max_articles}
                onChange={(e) => setRssForm((f) => ({ ...f, max_articles: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Title (optional)"
                value={rssForm.title}
                onChange={(e) => setRssForm((f) => ({ ...f, title: e.target.value }))}
                fullWidth
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={rssForm.enabled}
                    onChange={(e) => setRssForm((f) => ({ ...f, enabled: e.target.checked }))}
                  />
                }
                label="Enabled"
              />
            </>
          )}
          {tab === 'stocks' && (
            <>
              <TextField
                label="ID"
                value={stockForm.id}
                disabled={Boolean(editingStock)}
                onChange={(e) => setStockForm((f) => ({ ...f, id: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Symbol"
                value={stockForm.symbol}
                onChange={(e) => setStockForm((f) => ({ ...f, symbol: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Display name"
                value={stockForm.display_name}
                onChange={(e) => setStockForm((f) => ({ ...f, display_name: e.target.value }))}
                fullWidth
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={stockForm.enabled}
                    onChange={(e) => setStockForm((f) => ({ ...f, enabled: e.target.checked }))}
                  />
                }
                label="Enabled"
              />
            </>
          )}
          {(tab === 'jokes' || tab === 'trivia') && (
            <>
              <Typography variant="caption" color="text.secondary">
                Category id must match a curator category (for icons and labels).
              </Typography>
              <TextField
                label="ID (curator category slug)"
                value={categoryForm.id}
                disabled={Boolean(editingJoke || editingTrivia)}
                onChange={(e) => setCategoryForm((f) => ({ ...f, id: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Label"
                value={categoryForm.label}
                onChange={(e) => setCategoryForm((f) => ({ ...f, label: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Category prompt"
                value={categoryForm.category_prompt}
                onChange={(e) =>
                  setCategoryForm((f) => ({ ...f, category_prompt: e.target.value }))
                }
                fullWidth
                multiline
                minRows={2}
              />
              <TextField
                label="Min pool size"
                value={categoryForm.min_pool}
                onChange={(e) => setCategoryForm((f) => ({ ...f, min_pool: e.target.value }))}
                fullWidth
              />
              <TextField
                label="Max pool size"
                value={categoryForm.max_pool}
                onChange={(e) => setCategoryForm((f) => ({ ...f, max_pool: e.target.value }))}
                fullWidth
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={categoryForm.is_seasonal}
                    onChange={(e) =>
                      setCategoryForm((f) => ({ ...f, is_seasonal: e.target.checked }))
                    }
                  />
                }
                label="Seasonal"
              />
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        {canWrite && (
          <Button variant="contained" onClick={() => void save()}>
            Save
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
}
