import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import MyLocationIcon from '@mui/icons-material/MyLocation';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Checkbox,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Paper,
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
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { applyClientListPipeline, type SortOption } from '@/util/clientListPipeline';
import { paginateList } from '@/util/listPagination';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import type { ListLayoutMode } from '@/storage/listLayoutPreference';
import type { SavedDisplay } from '@/storage/displays';
import {
  rssFeedInterestId,
  stockSymbolInterestId,
  weatherLocationInterestId,
} from '@/util/interestSlug';
import { categorySeasonPayload, formatCategorySeason } from '@/util/categorySeason';
import { completeDialogSave } from '@/util/dialogSave';
import {
  interestCategoryLabel,
  weatherLocationCategoryFromName,
} from '@/util/weatherLocationCategory';

type TabId = 'locations' | 'rss' | 'stocks' | 'jokes' | 'trivia';

type CuratorCategoryOption = { id: string; label: string };

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

export function InterestsPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('interests.write');
  const { loading: locationsLoading, wrapRefresh: wrapLocationsRefresh } = useDisplayRefresh();
  const { loading: rssLoading, wrapRefresh: wrapRssRefresh } = useDisplayRefresh();
  const { loading: stocksLoading, wrapRefresh: wrapStocksRefresh } = useDisplayRefresh();
  const { loading: jokesLoading, wrapRefresh: wrapJokesRefresh } = useDisplayRefresh();
  const { loading: triviaLoading, wrapRefresh: wrapTriviaRefresh } = useDisplayRefresh();
  const { wrapRefresh: wrapCategoriesRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('interests');
  const loadedTabsRef = useRef<Set<TabId>>(new Set());

  const [tab, setTab] = useState<TabId>('locations');
  const [search, setSearch] = useState('');
  const [sortId, setSortId] = useState('name_asc');
  const [listPage, setListPage] = useState(0);
  const [listPageSize, setListPageSize] = useState(25);
  const [filterCategory, setFilterCategory] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [addingCurrentLocation, setAddingCurrentLocation] = useState(false);
  const [expandedNewsCategories, setExpandedNewsCategories] = useState<string[]>([]);

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

  const loadCategories = useCallback(async () => {
    if (!active) return;
    await wrapCategoriesRefresh(async () => {
      try {
        const cats = await apiJson<{ items: CuratorCategoryOption[] }>(
          active,
          '/v1/curator/categories',
        );
        setCuratorCategories(cats.items.map((c) => ({ id: c.id, label: c.label })));
      } catch {
        /* optional labels for filters */
      }
    });
  }, [active, wrapCategoriesRefresh]);

  const loadLocations = useCallback(async () => {
    if (!active) return;
    await wrapLocationsRefresh(async () => {
      setError(null);
      try {
        setWeather(await listWeatherLocations(active));
        loadedTabsRef.current.add('locations');
      } catch (e) {
        setError(errMsg(e));
      }
    });
  }, [active, wrapLocationsRefresh]);

  const loadRss = useCallback(async () => {
    if (!active) return;
    await wrapRssRefresh(async () => {
      setError(null);
      try {
        setRss(await listRssFeeds(active));
        loadedTabsRef.current.add('rss');
      } catch (e) {
        setError(errMsg(e));
      }
    });
  }, [active, wrapRssRefresh]);

  const loadStocks = useCallback(async () => {
    if (!active) return;
    await wrapStocksRefresh(async () => {
      setError(null);
      try {
        setStocks(await listStockSymbols(active));
        loadedTabsRef.current.add('stocks');
      } catch (e) {
        setError(errMsg(e));
      }
    });
  }, [active, wrapStocksRefresh]);

  const loadJokes = useCallback(async () => {
    if (!active) return;
    await wrapJokesRefresh(async () => {
      setError(null);
      try {
        setJokes(await listJokeCategories(active));
        loadedTabsRef.current.add('jokes');
      } catch (e) {
        setError(errMsg(e));
      }
    });
  }, [active, wrapJokesRefresh]);

  const loadTrivia = useCallback(async () => {
    if (!active) return;
    await wrapTriviaRefresh(async () => {
      setError(null);
      try {
        setTrivia(await listTriviaCategories(active));
        loadedTabsRef.current.add('trivia');
      } catch (e) {
        setError(errMsg(e));
      }
    });
  }, [active, wrapTriviaRefresh]);

  const reloadTab = useCallback(
    async (t: TabId) => {
      switch (t) {
        case 'locations':
          await loadLocations();
          break;
        case 'rss':
          await loadRss();
          break;
        case 'stocks':
          await loadStocks();
          break;
        case 'jokes':
          await loadJokes();
          break;
        case 'trivia':
          await loadTrivia();
          break;
      }
    },
    [loadLocations, loadRss, loadStocks, loadJokes, loadTrivia],
  );

  const reloadActiveTab = useCallback(async () => {
    await reloadTab(tab);
    if (tab === 'jokes' || tab === 'trivia' || tab === 'locations') {
      await loadCategories();
    }
  }, [reloadTab, tab, loadCategories]);

  useEffect(() => {
    loadedTabsRef.current = new Set();
    setWeather([]);
    setRss([]);
    setStocks([]);
    setJokes([]);
    setTrivia([]);
    setCuratorCategories([]);
  }, [active?.id]);

  useEffect(() => {
    void loadCategories();
  }, [loadCategories]);

  useEffect(() => {
    if (!active || loadedTabsRef.current.has(tab)) return;
    void reloadTab(tab);
  }, [active, tab, reloadTab]);

  useEffect(() => {
    setFilterCategory(null);
  }, [tab]);

  const categoryLabel = useCallback(
    (categoryId: string) => interestCategoryLabel(categoryId, curatorCategories),
    [curatorCategories],
  );

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
    if (tab === 'locations') return editingWeather ? 'Edit location' : 'Add location';
    if (tab === 'rss') return editingRss ? 'Edit news feed' : 'Add news feed';
    if (tab === 'stocks') return editingStock ? 'Edit stock symbol' : 'Add stock symbol';
    if (tab === 'jokes') return editingJoke ? 'Edit joke category' : 'Add joke category';
    return editingTrivia ? 'Edit trivia category' : 'Add trivia category';
  }, [tab, editingWeather, editingRss, editingStock, editingJoke, editingTrivia]);

  const filteredWeather = useMemo(() => {
    if (filterCategory == null) return weather;
    return weather.filter((r) => (r.category || 'general') === filterCategory);
  }, [weather, filterCategory]);

  const filteredJokes = useMemo(() => {
    if (filterCategory == null) return jokes;
    return jokes.filter((r) => r.id === filterCategory);
  }, [jokes, filterCategory]);

  const filteredTrivia = useMemo(() => {
    if (filterCategory == null) return trivia;
    return trivia.filter((r) => r.id === filterCategory);
  }, [trivia, filterCategory]);

  const jokeCategoryOptions = useMemo(() => categoryCounts(jokes, (r) => r.id), [jokes]);
  const triviaCategoryOptions = useMemo(
    () => categoryCounts(trivia, (r) => r.id),
    [trivia],
  );

  const interestNameSort = useMemo(
    (): SortOption<{ label: string }>[] => [
      {
        id: 'name_asc',
        label: 'Name (A–Z)',
        compare: (a, b) => a.label.localeCompare(b.label),
      },
      {
        id: 'name_desc',
        label: 'Name (Z–A)',
        compare: (a, b) => b.label.localeCompare(a.label),
      },
    ],
    [],
  );

  const sortedLocations = useMemo(
    () =>
      applyClientListPipeline({
        items: filteredWeather.map((r) => ({ ...r, label: r.name })),
        search,
        searchMatches: (row, q) =>
          row.label.toLowerCase().includes(q) || row.id.toLowerCase().includes(q),
        sortOptions: interestNameSort,
        sortId,
      }),
    [filteredWeather, search, sortId, interestNameSort],
  );

  const filteredRssForSearch = useMemo(() => {
    const pipeline = applyClientListPipeline({
      items: rss.map((r) => ({
        ...r,
        label: (r.title?.trim() || r.url).toLowerCase(),
      })),
      search,
      searchMatches: (row, q) =>
        row.label.includes(q) ||
        row.id.toLowerCase().includes(q) ||
        (row.url ?? '').toLowerCase().includes(q),
      sortOptions: interestNameSort,
      sortId,
    });
    return pipeline;
  }, [rss, search, sortId, interestNameSort]);

  const newsGroups = useMemo(() => {
    const byCategory = new Map<string, RssFeedRow[]>();
    for (const row of filteredRssForSearch) {
      const category = row.category || 'general';
      const list = byCategory.get(category) ?? [];
      list.push(row);
      byCategory.set(category, list);
    }
    const feedLabel = (row: RssFeedRow) => row.title?.trim() || row.url;
    return [...byCategory.entries()]
      .map(([id, rows]) => ({
        id,
        rows: [...rows].sort((a, b) => feedLabel(a).localeCompare(feedLabel(b))),
      }))
      .sort((a, b) => categoryLabel(a.id).localeCompare(categoryLabel(b.id)));
  }, [filteredRssForSearch, categoryLabel]);

  const stocksInterested = useMemo(
    () =>
      applyClientListPipeline({
        items: stocks
          .filter((r) => r.enabled)
          .map((r) => ({ ...r, label: r.symbol })),
        search,
        searchMatches: (row, q) =>
          row.symbol.toLowerCase().includes(q) || row.id.toLowerCase().includes(q),
        sortOptions: interestNameSort,
        sortId,
      }),
    [stocks, search, sortId, interestNameSort],
  );
  const stocksNotInterested = useMemo(
    () =>
      applyClientListPipeline({
        items: stocks
          .filter((r) => !r.enabled)
          .map((r) => ({ ...r, label: r.symbol })),
        search,
        searchMatches: (row, q) =>
          row.symbol.toLowerCase().includes(q) || row.id.toLowerCase().includes(q),
        sortOptions: interestNameSort,
        sortId,
      }),
    [stocks, search, sortId, interestNameSort],
  );
  const sortedJokes = useMemo(
    () =>
      applyClientListPipeline({
        items: filteredJokes.map((r) => ({ ...r, label: r.label })),
        search,
        searchMatches: (row, q) =>
          row.label.toLowerCase().includes(q) || row.id.toLowerCase().includes(q),
        sortOptions: interestNameSort,
        sortId,
      }),
    [filteredJokes, search, sortId, interestNameSort],
  );
  const sortedTrivia = useMemo(
    () =>
      applyClientListPipeline({
        items: filteredTrivia.map((r) => ({ ...r, label: r.label })),
        search,
        searchMatches: (row, q) =>
          row.label.toLowerCase().includes(q) || row.id.toLowerCase().includes(q),
        sortOptions: interestNameSort,
        sortId,
      }),
    [filteredTrivia, search, sortId, interestNameSort],
  );
  const tabListForPaging = useMemo(() => {
    switch (tab) {
      case 'locations':
        return sortedLocations;
      case 'jokes':
        return sortedJokes;
      case 'trivia':
        return sortedTrivia;
      case 'stocks':
        return [...stocksInterested, ...stocksNotInterested];
      default:
        return [];
    }
  }, [tab, sortedLocations, sortedJokes, sortedTrivia, stocksInterested, stocksNotInterested]);

  const tabPaged = useMemo(
    () => paginateList(tabListForPaging, listPage, listPageSize),
    [tabListForPaging, listPage, listPageSize],
  );

  useEffect(() => {
    setListPage(0);
  }, [tab, search, sortId, filterCategory]);

  const tabLoading =
    tab === 'locations'
      ? locationsLoading
      : tab === 'rss'
        ? rssLoading
        : tab === 'stocks'
          ? stocksLoading
          : tab === 'jokes'
            ? jokesLoading
            : triviaLoading;

  const pagedLocations = useMemo(() => {
    if (tab !== 'locations') return sortedLocations;
    return tabPaged.items;
  }, [tab, tabPaged.items, sortedLocations]);

  const pagedStocksInterested = useMemo(() => {
    const ids = new Set(stocksInterested.map((r) => r.id));
    return tabPaged.items.filter((r) => 'symbol' in r && ids.has(r.id)) as typeof stocksInterested;
  }, [tabPaged.items, stocksInterested]);

  const pagedStocksNotInterested = useMemo(() => {
    const ids = new Set(stocksNotInterested.map((r) => r.id));
    return tabPaged.items.filter((r) => 'symbol' in r && ids.has(r.id)) as typeof stocksNotInterested;
  }, [tabPaged.items, stocksNotInterested]);

  const pagedJokes = useMemo(() => {
    if (tab !== 'jokes') return sortedJokes;
    return tabPaged.items as typeof sortedJokes;
  }, [tab, tabPaged.items, sortedJokes]);

  const pagedTrivia = useMemo(() => {
    if (tab !== 'trivia') return sortedTrivia;
    return tabPaged.items as typeof sortedTrivia;
  }, [tab, tabPaged.items, sortedTrivia]);

  const patchWeather = useCallback(
    async (id: string, patch: Parameters<typeof patchWeatherLocation>[2]) => {
      if (!active) return;
      await patchWeatherLocation(active, id, patch);
      await loadLocations();
    },
    [active, loadLocations],
  );

  const addMyCurrentLocation = useCallback(async () => {
    if (!active || !canWrite) return;
    if (!navigator.geolocation) {
      setError('Geolocation is not available in this browser');
      return;
    }
    setAddingCurrentLocation(true);
    setError(null);
    try {
      const position = await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: 15000,
          maximumAge: 60_000,
        });
      });
      const lat = position.coords.latitude;
      const lon = position.coords.longitude;
      const name = `${lat.toFixed(4)}, ${lon.toFixed(4)}`;
      const id = weatherLocationInterestId(name, weather.map((w) => w.id));
      if (!id) {
        setError('Could not derive an id from the coordinates');
        return;
      }
      await createWeatherLocation(active, {
        id,
        name,
        latitude: lat,
        longitude: lon,
        category: 'general',
        include_weather: true,
        include_weather_alerts: true,
        include_local_news: true,
      });
      await loadLocations();
    } catch (e) {
      setError(errMsg(e));
    } finally {
      setAddingCurrentLocation(false);
    }
  }, [active, canWrite, weather, loadLocations]);

  const patchRss = useCallback(
    async (id: string, patch: Parameters<typeof patchRssFeed>[2]) => {
      if (!active) return;
      await patchRssFeed(active, id, patch);
      await loadRss();
    },
    [active, loadRss],
  );

  const patchRssCategory = useCallback(
    async (categoryId: string, enabled: boolean) => {
      if (!active) return;
      const rows = rss.filter((r) => (r.category || 'general') === categoryId);
      await Promise.all(rows.map((row) => patchRssFeed(active, row.id, { enabled })));
      await loadRss();
    },
    [active, loadRss, rss],
  );

  const patchStock = useCallback(
    async (id: string, patch: Parameters<typeof patchStockSymbol>[2]) => {
      if (!active) return;
      await patchStockSymbol(active, id, patch);
      await loadStocks();
    },
    [active, loadStocks],
  );

  const deleteWeather = useCallback(
    async (id: string) => {
      if (!active) return;
      try {
        await deleteWeatherLocation(active, id);
        await loadLocations();
      } catch (e) {
        setError(errMsg(e));
      }
    },
    [active, loadLocations],
  );

  const deleteRss = useCallback(
    async (id: string) => {
      if (!active) return;
      try {
        await deleteRssFeed(active, id);
        await loadRss();
      } catch (e) {
        setError(errMsg(e));
      }
    },
    [active, loadRss],
  );

  const deleteStock = useCallback(
    async (id: string) => {
      if (!active) return;
      try {
        await deleteStockSymbol(active, id);
        await loadStocks();
      } catch (e) {
        setError(errMsg(e));
      }
    },
    [active, loadStocks],
  );

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Interests
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Configure locations, news feeds, stocks, joke categories, and trivia categories the
          display collects.
        </Typography>
      </Box>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Tabs value={tab} onChange={(_, v: TabId) => setTab(v)} variant="scrollable">
        <Tab value="locations" label="Locations" />
        <Tab value="rss" label="News" />
        <Tab value="stocks" label="Stocks" />
        <Tab value="jokes" label="Jokes" />
        <Tab value="trivia" label="Trivia" />
      </Tabs>

      <DataViewToolbar
        layout={layout}
        onLayoutChange={setLayout}
        search={search}
        onSearchChange={setSearch}
        searchPlaceholder="Search interests…"
        sortOptions={interestNameSort}
        sortId={sortId}
        onSortChange={setSortId}
        onReload={() => void reloadTab(tab)}
        reloadDisabled={tabLoading}
        reloadAriaLabel="Reload interests"
      >
        {canWrite && tab === 'locations' && (
          <Button
            variant="outlined"
            startIcon={<MyLocationIcon />}
            disabled={addingCurrentLocation}
            onClick={() => void addMyCurrentLocation()}
          >
            {addingCurrentLocation ? 'Detecting…' : 'Add my current location'}
          </Button>
        )}
        {canWrite && (
          <Button variant="contained" onClick={openAdd}>
            Add
          </Button>
        )}
      </DataViewToolbar>

      {tab === 'jokes' && jokeCategoryOptions.length > 0 && (
        <InterestCategoryFilter
          categories={jokeCategoryOptions}
          filterCategory={filterCategory}
          onFilterChange={setFilterCategory}
          labelForCategory={categoryLabel}
        />
      )}
      {tab === 'trivia' && triviaCategoryOptions.length > 0 && (
        <InterestCategoryFilter
          categories={triviaCategoryOptions}
          filterCategory={filterCategory}
          onFilterChange={setFilterCategory}
          labelForCategory={categoryLabel}
        />
      )}

      {tab === 'locations' && (
        <Stack spacing={1.5}>
          <DisplayRefreshIndicator loading={locationsLoading} />
          <CatalogSection
            title="Locations"
            empty="No locations configured."
            layout={layout}
            isEmpty={sortedLocations.length === 0}
            cards={pagedLocations.map((row) => (
              <WeatherInterestCard
                key={row.id}
                row={row}
                canWrite={canWrite}
                onEdit={() => openEditWeather(row)}
                onDelete={() => void deleteWeather(row.id)}
                onPatch={(patch) =>
                  patchWeather(row.id, patch).catch((e) => setError(errMsg(e)))
                }
              />
            ))}
            table={
              <WeatherInterestTable
                rows={pagedLocations}
                canWrite={canWrite}
                onEdit={openEditWeather}
                onDelete={(id) => void deleteWeather(id)}
                onPatch={(id, patch) =>
                  patchWeather(id, patch).catch((e) => setError(errMsg(e)))
                }
              />
            }
          />
          {tab === 'locations' && (
            <DataViewPagination
              count={sortedLocations.length}
              page={tabPaged.page}
              pageSize={tabPaged.pageSize}
              onPageChange={setListPage}
              onPageSizeChange={setListPageSize}
            />
          )}
        </Stack>
      )}

      {tab === 'rss' && (
        <Stack spacing={2}>
          <DisplayRefreshIndicator loading={rssLoading} />
          {newsGroups.length === 0 && !rssLoading ? (
            <Typography variant="body2" color="text.secondary">
              No news feeds configured.
            </Typography>
          ) : newsGroups.length > 0 ? (
            newsGroups.map((group) => (
              <NewsCategoryAccordion
                key={group.id}
                title={categoryLabel(group.id)}
                rows={group.rows}
                layout={layout}
                expanded={expandedNewsCategories.includes(group.id)}
                onExpandedChange={(expanded) => {
                  setExpandedNewsCategories((prev) =>
                    expanded
                      ? prev.includes(group.id)
                        ? prev
                        : [...prev, group.id]
                      : prev.filter((id) => id !== group.id),
                  );
                }}
                canWrite={canWrite}
                onEdit={openEditRss}
                onDelete={(id) => void deleteRss(id)}
                onPatch={(id, patch) =>
                  patchRss(id, patch).catch((e) => setError(errMsg(e)))
                }
                onCategoryPatch={(enabled) =>
                  patchRssCategory(group.id, enabled).catch((e) => setError(errMsg(e)))
                }
              />
            ))
          ) : null}
        </Stack>
      )}

      {tab === 'stocks' && (
        <Stack spacing={3}>
          <DisplayRefreshIndicator loading={stocksLoading} />
          <CatalogSection
            title="Interested"
            empty="No stock symbols are marked interested."
            layout={layout}
            isEmpty={stocksInterested.length === 0}
            cards={pagedStocksInterested.map((row) => (
              <StockInterestCard
                key={row.id}
                row={row}
                canWrite={canWrite}
                onEdit={() => openEditStock(row)}
                onDelete={() => void deleteStock(row.id)}
                onPatch={(patch) => patchStock(row.id, patch).catch((e) => setError(errMsg(e)))}
              />
            ))}
            table={
              <StockInterestTable
                rows={pagedStocksInterested}
                canWrite={canWrite}
                onEdit={openEditStock}
                onDelete={(id) => void deleteStock(id)}
                onPatch={(id, patch) => patchStock(id, patch).catch((e) => setError(errMsg(e)))}
              />
            }
          />
          <CatalogSection
            title="Not interested"
            empty="All stock symbols are marked interested."
            layout={layout}
            isEmpty={stocksNotInterested.length === 0}
            cards={pagedStocksNotInterested.map((row) => (
              <StockInterestCard
                key={row.id}
                row={row}
                canWrite={canWrite}
                onEdit={() => openEditStock(row)}
                onDelete={() => void deleteStock(row.id)}
                onPatch={(patch) => patchStock(row.id, patch).catch((e) => setError(errMsg(e)))}
              />
            ))}
            table={
              <StockInterestTable
                rows={pagedStocksNotInterested}
                canWrite={canWrite}
                onEdit={openEditStock}
                onDelete={(id) => void deleteStock(id)}
                onPatch={(id, patch) => patchStock(id, patch).catch((e) => setError(errMsg(e)))}
              />
            }
          />
          <DataViewPagination
            count={tabListForPaging.length}
            page={tabPaged.page}
            pageSize={tabPaged.pageSize}
            onPageChange={setListPage}
            onPageSizeChange={setListPageSize}
          />
        </Stack>
      )}

      {tab === 'jokes' && (
        <Stack spacing={1.5}>
          <DisplayRefreshIndicator loading={jokesLoading} />
          <CatalogSection
          title="Joke categories"
          empty="No joke categories configured."
          layout={layout}
          isEmpty={sortedJokes.length === 0}
          cards={pagedJokes.map((row) => (
            <CategoryInterestCard
              key={row.id}
              row={row}
              canWrite={canWrite}
              onEdit={() => openEditJoke(row)}
              onDelete={async () => {
                try {
                  await deleteJokeCategory(active, row.id);
                  await loadJokes();
                } catch (e) {
                  setError(errMsg(e));
                }
              }}
            />
          ))}
          table={
            <CategoryInterestTable
              rows={pagedJokes}
              canWrite={canWrite}
              onEdit={openEditJoke}
              onDelete={async (id) => {
                try {
                  await deleteJokeCategory(active, id);
                  await loadJokes();
                } catch (e) {
                  setError(errMsg(e));
                }
              }}
            />
          }
        />
          <DataViewPagination
            count={sortedJokes.length}
            page={tabPaged.page}
            pageSize={tabPaged.pageSize}
            onPageChange={setListPage}
            onPageSizeChange={setListPageSize}
          />
        </Stack>
      )}

      {tab === 'trivia' && (
        <Stack spacing={1.5}>
          <DisplayRefreshIndicator loading={triviaLoading} />
          <CatalogSection
          title="Trivia categories"
          empty="No trivia categories configured."
          layout={layout}
          isEmpty={sortedTrivia.length === 0}
          cards={pagedTrivia.map((row) => (
            <CategoryInterestCard
              key={row.id}
              row={row}
              canWrite={canWrite}
              onEdit={() => openEditTrivia(row)}
              onDelete={async () => {
                try {
                  await deleteTriviaCategory(active, row.id);
                  await loadTrivia();
                } catch (e) {
                  setError(errMsg(e));
                }
              }}
            />
          ))}
          table={
            <CategoryInterestTable
              rows={pagedTrivia}
              canWrite={canWrite}
              onEdit={openEditTrivia}
              onDelete={async (id) => {
                try {
                  await deleteTriviaCategory(active, id);
                  await loadTrivia();
                } catch (e) {
                  setError(errMsg(e));
                }
              }}
            />
          }
        />
          <DataViewPagination
            count={sortedTrivia.length}
            page={tabPaged.page}
            pageSize={tabPaged.pageSize}
            onPageChange={setListPage}
            onPageSizeChange={setListPageSize}
          />
        </Stack>
      )}

      <InterestDialog
        open={dialogOpen}
        title={dialogTitle}
        tab={tab}
        canWrite={canWrite}
        curatorCategories={curatorCategories}
        weatherIds={weather.map((w) => w.id)}
        rssIds={rss.map((r) => r.id)}
        stockIds={stocks.map((s) => s.id)}
        editingWeather={editingWeather}
        editingRss={editingRss}
        editingStock={editingStock}
        editingJoke={editingJoke}
        editingTrivia={editingTrivia}
        onClose={() => setDialogOpen(false)}
        onSaved={async () => {
          setDialogOpen(false);
          await reloadActiveTab();
        }}
        onError={setError}
        display={active}
      />
    </Stack>
  );
}

function categoryCounts<T>(rows: T[], getCategory: (row: T) => string): { id: string; count: number }[] {
  const counts = new Map<string, number>();
  for (const row of rows) {
    const id = getCategory(row) || 'general';
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  return [...counts.entries()].map(([id, count]) => ({ id, count }));
}

function InterestCategoryFilter({
  categories,
  filterCategory,
  onFilterChange,
  labelForCategory,
}: {
  categories: { id: string; count: number }[];
  filterCategory: string | null;
  onFilterChange: (id: string | null) => void;
  labelForCategory: (id: string) => string;
}) {
  const total = categories.reduce((sum, c) => sum + c.count, 0);
  const sorted = [...categories].sort((a, b) =>
    labelForCategory(a.id).localeCompare(labelForCategory(b.id)),
  );
  return (
    <Stack spacing={1}>
      <Typography variant="subtitle2" color="text.secondary">
        Filter by category
      </Typography>
      <Stack direction="row" flexWrap="wrap" useFlexGap spacing={1}>
        <Chip
          label={`All (${total})`}
          onClick={() => onFilterChange(null)}
          color={filterCategory === null ? 'primary' : 'default'}
          variant={filterCategory === null ? 'filled' : 'outlined'}
          clickable
        />
        {sorted.map(({ id, count }) => {
          const selected = filterCategory === id;
          return (
            <Chip
              key={id}
              label={`${labelForCategory(id)} (${count})`}
              onClick={() => onFilterChange(id)}
              color={selected ? 'primary' : 'default'}
              variant={selected ? 'filled' : 'outlined'}
              clickable
            />
          );
        })}
      </Stack>
    </Stack>
  );
}

function CatalogSection({
  title,
  empty,
  layout,
  isEmpty,
  cards,
  table,
}: {
  title: string;
  empty: string;
  layout: ListLayoutMode;
  isEmpty: boolean;
  cards: ReactNode;
  table: ReactNode;
}) {
  return (
    <Stack spacing={1.5}>
      <Typography variant="subtitle1" fontWeight={600}>
        {title}
      </Typography>
      {isEmpty ? (
        <Typography variant="body2" color="text.secondary">
          {empty}
        </Typography>
      ) : layout === 'card' ? (
        <Box sx={catalogCardGridSx}>{cards}</Box>
      ) : (
        table
      )}
    </Stack>
  );
}

function InterestedToggleCell({
  checked,
  disabled,
  ariaLabel,
  onToggle,
}: {
  checked: boolean;
  disabled?: boolean;
  ariaLabel: string;
  onToggle: (enabled: boolean) => void;
}) {
  return (
    <TableCell>
      <Switch
        size="small"
        checked={checked}
        disabled={disabled}
        onChange={(_, enabled) => onToggle(enabled)}
        inputProps={{ 'aria-label': ariaLabel }}
      />
    </TableCell>
  );
}

function CatalogRowActions({
  canWrite,
  onEdit,
  onDelete,
}: {
  canWrite: boolean;
  onEdit: () => void;
  onDelete: () => void;
}) {
  if (!canWrite) return null;
  return (
    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
      <Button size="small" onClick={onEdit}>
        Edit
      </Button>
      <Button size="small" color="error" onClick={onDelete}>
        Delete
      </Button>
    </TableCell>
  );
}

function CatalogCardActions({
  canWrite,
  onEdit,
  onDelete,
}: {
  canWrite: boolean;
  onEdit: () => void;
  onDelete: () => void;
}) {
  if (!canWrite) return null;
  return (
    <CardActions sx={{ justifyContent: 'flex-end', px: 2, pb: 2 }}>
      <Button size="small" variant="outlined" onClick={onEdit}>
        Edit
      </Button>
      <Button size="small" variant="outlined" color="error" onClick={onDelete}>
        Delete
      </Button>
    </CardActions>
  );
}

function rssCategoryToggleState(rows: RssFeedRow[]) {
  const on = rows.filter((r) => r.enabled).length;
  if (on === 0) return { checked: false, indeterminate: false };
  if (on === rows.length) return { checked: true, indeterminate: false };
  return { checked: false, indeterminate: true };
}

function NewsCategoryAccordion({
  title,
  rows,
  layout,
  expanded,
  onExpandedChange,
  canWrite,
  onEdit,
  onDelete,
  onPatch,
  onCategoryPatch,
}: {
  title: string;
  rows: RssFeedRow[];
  layout: ListLayoutMode;
  expanded: boolean;
  onExpandedChange: (expanded: boolean) => void;
  canWrite: boolean;
  onEdit: (row: RssFeedRow) => void;
  onDelete: (id: string) => void;
  onPatch: (id: string, patch: Partial<RssFeedRow>) => void;
  onCategoryPatch: (enabled: boolean) => void;
}) {
  const interestedState = rssCategoryToggleState(rows);

  return (
    <Accordion
      expanded={expanded}
      onChange={(_, isExpanded) => onExpandedChange(isExpanded)}
      disableGutters
      variant="outlined"
    >
      <AccordionSummary expandIcon={<ExpandMoreIcon />}>
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          spacing={1}
          alignItems={{ xs: 'flex-start', sm: 'center' }}
          sx={{ width: '100%', pr: 1 }}
        >
          <Typography variant="subtitle1" fontWeight={600} sx={{ flexGrow: 1 }}>
            {title} ({rows.length})
          </Typography>
          <Stack direction="row" spacing={2} flexWrap="wrap" useFlexGap onClick={(e) => e.stopPropagation()}>
            <FormControlLabel
              control={
                <Checkbox
                  size="small"
                  checked={interestedState.checked}
                  indeterminate={interestedState.indeterminate}
                  disabled={!canWrite}
                  onChange={(_, checked) => onCategoryPatch(checked)}
                />
              }
              label="Interested"
            />
          </Stack>
        </Stack>
      </AccordionSummary>
      <AccordionDetails sx={{ pt: 0 }}>
        {layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {rows.map((row) => (
              <RssInterestCard
                key={row.id}
                row={row}
                canWrite={canWrite}
                onEdit={() => onEdit(row)}
                onDelete={() => onDelete(row.id)}
                onPatch={(patch) => onPatch(row.id, patch)}
              />
            ))}
          </Box>
        ) : (
          <RssInterestTable
            rows={rows}
            canWrite={canWrite}
            onEdit={onEdit}
            onDelete={onDelete}
            onPatch={onPatch}
          />
        )}
      </AccordionDetails>
    </Accordion>
  );
}

function WeatherInterestTable({
  rows,
  canWrite,
  onEdit,
  onDelete,
  onPatch,
}: {
  rows: WeatherLocationRow[];
  canWrite: boolean;
  onEdit: (row: WeatherLocationRow) => void;
  onDelete: (id: string) => void;
  onPatch: (id: string, patch: Partial<WeatherLocationRow>) => void;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Name</TableCell>
            <TableCell>Lat</TableCell>
            <TableCell>Lon</TableCell>
            <TableCell>Weather</TableCell>
            <TableCell>Weather Alerts</TableCell>
            <TableCell>Local News</TableCell>
            {canWrite ? <TableCell align="right">Actions</TableCell> : null}
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => (
            <TableRow key={row.id} hover>
              <TableCell sx={{ fontWeight: 600 }}>{row.name}</TableCell>
              <TableCell>{row.latitude}</TableCell>
              <TableCell>{row.longitude}</TableCell>
              <InterestedToggleCell
                checked={row.include_weather}
                disabled={!canWrite}
                ariaLabel={`Weather for ${row.name}`}
                onToggle={(include_weather) => onPatch(row.id, { include_weather })}
              />
              <InterestedToggleCell
                checked={row.include_weather_alerts}
                disabled={!canWrite}
                ariaLabel={`Weather alerts for ${row.name}`}
                onToggle={(include_weather_alerts) =>
                  onPatch(row.id, { include_weather_alerts })
                }
              />
              <InterestedToggleCell
                checked={row.include_local_news}
                disabled={!canWrite}
                ariaLabel={`Local news for ${row.name}`}
                onToggle={(include_local_news) => onPatch(row.id, { include_local_news })}
              />
              <CatalogRowActions
                canWrite={canWrite}
                onEdit={() => onEdit(row)}
                onDelete={() => onDelete(row.id)}
              />
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

function WeatherInterestCard({
  row,
  canWrite,
  onEdit,
  onDelete,
  onPatch,
}: {
  row: WeatherLocationRow;
  canWrite: boolean;
  onEdit: () => void;
  onDelete: () => void;
  onPatch: (patch: Partial<WeatherLocationRow>) => void;
}) {
  return (
    <Card variant="outlined" sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Typography variant="subtitle1" fontWeight={600}>
            {row.name}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {row.latitude}, {row.longitude}
          </Typography>
          <FormControlLabel
            control={
              <Switch
                size="small"
                checked={row.include_weather}
                disabled={!canWrite}
                onChange={(_, include_weather) => onPatch({ include_weather })}
              />
            }
            label="Weather"
          />
          <FormControlLabel
            control={
              <Switch
                size="small"
                checked={row.include_weather_alerts}
                disabled={!canWrite}
                onChange={(_, include_weather_alerts) =>
                  onPatch({ include_weather_alerts })
                }
              />
            }
            label="Weather Alerts"
          />
          <FormControlLabel
            control={
              <Switch
                size="small"
                checked={row.include_local_news}
                disabled={!canWrite}
                onChange={(_, include_local_news) => onPatch({ include_local_news })}
              />
            }
            label="Local News"
          />
        </Stack>
      </CardContent>
      <CatalogCardActions canWrite={canWrite} onEdit={onEdit} onDelete={onDelete} />
    </Card>
  );
}

function RssInterestTable({
  rows,
  canWrite,
  onEdit,
  onDelete,
  onPatch,
}: {
  rows: RssFeedRow[];
  canWrite: boolean;
  onEdit: (row: RssFeedRow) => void;
  onDelete: (id: string) => void;
  onPatch: (id: string, patch: Partial<RssFeedRow>) => void;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Feed name</TableCell>
            <TableCell>URL</TableCell>
            <TableCell>Poll (s)</TableCell>
            <TableCell>Max</TableCell>
            <TableCell>Interested</TableCell>
            {canWrite ? <TableCell align="right">Actions</TableCell> : null}
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => {
            const feedName = row.title?.trim() || '—';
            return (
              <TableRow key={row.id} hover>
                <TableCell sx={{ fontWeight: feedName !== '—' ? 600 : 400 }}>{feedName}</TableCell>
                <TableCell sx={{ maxWidth: 280, wordBreak: 'break-all' }}>{row.url}</TableCell>
                <TableCell>{row.poll_seconds}</TableCell>
                <TableCell>{row.max_articles}</TableCell>
                <InterestedToggleCell
                  checked={row.enabled}
                  disabled={!canWrite}
                  ariaLabel={`Interested in news feed ${feedName}`}
                  onToggle={(enabled) => onPatch(row.id, { enabled })}
                />
                <CatalogRowActions
                  canWrite={canWrite}
                  onEdit={() => onEdit(row)}
                  onDelete={() => onDelete(row.id)}
                />
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

function RssInterestCard({
  row,
  canWrite,
  onEdit,
  onDelete,
  onPatch,
}: {
  row: RssFeedRow;
  canWrite: boolean;
  onEdit: () => void;
  onDelete: () => void;
  onPatch: (patch: Partial<RssFeedRow>) => void;
}) {
  const feedName = row.title?.trim() || 'Untitled feed';
  return (
    <Card variant="outlined" sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Typography variant="subtitle1" fontWeight={600} sx={{ wordBreak: 'break-word' }}>
            {feedName}
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ wordBreak: 'break-all' }}>
            {row.url}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            Poll {row.poll_seconds}s · max {row.max_articles} articles
          </Typography>
          <FormControlLabel
            control={
              <Switch
                size="small"
                checked={row.enabled}
                disabled={!canWrite}
                onChange={(_, enabled) => onPatch({ enabled })}
              />
            }
            label="Interested"
          />
        </Stack>
      </CardContent>
      <CatalogCardActions canWrite={canWrite} onEdit={onEdit} onDelete={onDelete} />
    </Card>
  );
}

function StockInterestTable({
  rows,
  canWrite,
  onEdit,
  onDelete,
  onPatch,
}: {
  rows: StockSymbolRow[];
  canWrite: boolean;
  onEdit: (row: StockSymbolRow) => void;
  onDelete: (id: string) => void;
  onPatch: (id: string, patch: Partial<StockSymbolRow>) => void;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Symbol</TableCell>
            <TableCell>Display name</TableCell>
            <TableCell>Interested</TableCell>
            {canWrite ? <TableCell align="right">Actions</TableCell> : null}
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => (
            <TableRow key={row.id} hover>
              <TableCell sx={{ fontWeight: 600 }}>{row.symbol}</TableCell>
              <TableCell>{row.display_name}</TableCell>
              <InterestedToggleCell
                checked={row.enabled}
                disabled={!canWrite}
                ariaLabel={`Interested in stock ${row.symbol}`}
                onToggle={(enabled) => onPatch(row.id, { enabled })}
              />
              <CatalogRowActions
                canWrite={canWrite}
                onEdit={() => onEdit(row)}
                onDelete={() => onDelete(row.id)}
              />
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

function StockInterestCard({
  row,
  canWrite,
  onEdit,
  onDelete,
  onPatch,
}: {
  row: StockSymbolRow;
  canWrite: boolean;
  onEdit: () => void;
  onDelete: () => void;
  onPatch: (patch: Partial<StockSymbolRow>) => void;
}) {
  return (
    <Card variant="outlined" sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Typography variant="subtitle1" fontWeight={600}>
            {row.symbol}
          </Typography>
          {row.display_name.trim() ? (
            <Typography variant="body2" color="text.secondary">
              {row.display_name}
            </Typography>
          ) : null}
          <FormControlLabel
            control={
              <Switch
                size="small"
                checked={row.enabled}
                disabled={!canWrite}
                onChange={(_, enabled) => onPatch({ enabled })}
              />
            }
            label="Interested"
          />
        </Stack>
      </CardContent>
      <CatalogCardActions canWrite={canWrite} onEdit={onEdit} onDelete={onDelete} />
    </Card>
  );
}

function CategoryInterestTable({
  rows,
  canWrite,
  onEdit,
  onDelete,
}: {
  rows: CategoryInterestRow[];
  canWrite: boolean;
  onEdit: (row: CategoryInterestRow) => void;
  onDelete: (id: string) => Promise<void>;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Label</TableCell>
            <TableCell>Seasonal</TableCell>
            <TableCell>Season</TableCell>
            <TableCell>Min</TableCell>
            <TableCell>Max</TableCell>
            {canWrite ? <TableCell align="right">Actions</TableCell> : null}
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => (
            <TableRow key={row.id} hover>
              <TableCell sx={{ fontWeight: 600 }}>{row.label}</TableCell>
              <TableCell>{row.is_seasonal ? 'Yes' : 'No'}</TableCell>
              <TableCell>{formatCategorySeason(row)}</TableCell>
              <TableCell>{row.min_jokes ?? row.min_questions ?? '—'}</TableCell>
              <TableCell>{row.max_jokes ?? row.max_questions ?? '—'}</TableCell>
              <CatalogRowActions
                canWrite={canWrite}
                onEdit={() => onEdit(row)}
                onDelete={() => void onDelete(row.id)}
              />
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

function CategoryInterestCard({
  row,
  canWrite,
  onEdit,
  onDelete,
}: {
  row: CategoryInterestRow;
  canWrite: boolean;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const minPool = row.min_jokes ?? row.min_questions;
  const maxPool = row.max_jokes ?? row.max_questions;
  return (
    <Card variant="outlined" sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Typography variant="subtitle1" fontWeight={600}>
            {row.label}
          </Typography>
          {row.is_seasonal ? (
            <Chip
              size="small"
              label={formatCategorySeason(row)}
              variant="outlined"
              sx={{ alignSelf: 'flex-start' }}
            />
          ) : null}
          <Typography variant="caption" color="text.secondary">
            Pool {minPool ?? '—'}–{maxPool ?? '—'}
          </Typography>
        </Stack>
      </CardContent>
      <CatalogCardActions canWrite={canWrite} onEdit={onEdit} onDelete={onDelete} />
    </Card>
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
  weatherIds,
  rssIds,
  stockIds,
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
  display: SavedDisplay;
  weatherIds: string[];
  rssIds: string[];
  stockIds: string[];
}) {
  const [weatherForm, setWeatherForm] = useState({
    name: '',
    latitude: '',
    longitude: '',
    include_weather: false,
    include_weather_alerts: false,
    include_local_news: false,
  });
  const [rssForm, setRssForm] = useState({
    feedName: '',
    url: '',
    category: 'general',
    poll_seconds: '3600',
    max_articles: '3',
    enabled: true,
  });
  const [stockForm, setStockForm] = useState({
    symbol: '',
    display_name: '',
    enabled: true,
  });
  const [categoryForm, setCategoryForm] = useState({
    curatorCategoryId: '',
    label: '',
    is_seasonal: false,
    start_month: '',
    start_day: '',
    end_month: '',
    end_day: '',
    category_prompt: '',
    min_pool: '10',
    max_pool: '100',
  });
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    if (editingWeather) {
      setWeatherForm({
        name: editingWeather.name,
        latitude: String(editingWeather.latitude),
        longitude: String(editingWeather.longitude),
        include_weather: editingWeather.include_weather,
        include_weather_alerts: editingWeather.include_weather_alerts,
        include_local_news: editingWeather.include_local_news,
      });
    } else if (tab === 'locations') {
      setWeatherForm({
        name: '',
        latitude: '',
        longitude: '',
        include_weather: false,
        include_weather_alerts: false,
        include_local_news: false,
      });
    }
    if (editingRss) {
      setRssForm({
        feedName: editingRss.title?.trim() ?? '',
        url: editingRss.url,
        category: editingRss.category,
        poll_seconds: String(editingRss.poll_seconds),
        max_articles: String(editingRss.max_articles),
        enabled: editingRss.enabled,
      });
    } else if (tab === 'rss') {
      setRssForm({
        feedName: '',
        url: '',
        category: curatorCategories[0]?.id ?? 'general',
        poll_seconds: '3600',
        max_articles: '3',
        enabled: true,
      });
    }
    if (editingStock) {
      setStockForm({
        symbol: editingStock.symbol,
        display_name: editingStock.display_name,
        enabled: editingStock.enabled,
      });
    } else if (tab === 'stocks') {
      setStockForm({ symbol: '', display_name: '', enabled: true });
    }
    const cat = editingJoke ?? editingTrivia;
    if (cat) {
      setCategoryForm({
        curatorCategoryId: cat.id,
        label: cat.label,
        is_seasonal: cat.is_seasonal,
        start_month: cat.start_month != null ? String(cat.start_month) : '',
        start_day: cat.start_day != null ? String(cat.start_day) : '',
        end_month: cat.end_month != null ? String(cat.end_month) : '',
        end_day: cat.end_day != null ? String(cat.end_day) : '',
        category_prompt: cat.category_prompt ?? '',
        min_pool: String(cat.min_jokes ?? cat.min_questions ?? 10),
        max_pool: String(cat.max_jokes ?? cat.max_questions ?? 100),
      });
    } else if (tab === 'jokes' || tab === 'trivia') {
      const first = curatorCategories[0];
      setCategoryForm({
        curatorCategoryId: first?.id ?? '',
        label: first?.label ?? '',
        is_seasonal: false,
        start_month: '',
        start_day: '',
        end_month: '',
        end_day: '',
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
    setSaving(true);
    try {
      if (tab === 'locations') {
        const lat = Number.parseFloat(weatherForm.latitude);
        const lon = Number.parseFloat(weatherForm.longitude);
        const name = weatherForm.name.trim();
        const category = weatherLocationCategoryFromName(name);
        if (editingWeather) {
          await patchWeatherLocation(display, editingWeather.id, {
            name,
            latitude: lat,
            longitude: lon,
            category,
          });
        } else {
          if (!name) {
            onError('Name is required');
            return;
          }
          const id = weatherLocationInterestId(name, weatherIds);
          if (!id) {
            onError('Could not derive an id from the location name');
            return;
          }
          await createWeatherLocation(display, {
            id,
            name,
            latitude: lat,
            longitude: lon,
            category,
            include_weather: weatherForm.include_weather,
            include_weather_alerts: weatherForm.include_weather_alerts,
            include_local_news: weatherForm.include_local_news,
          });
        }
      } else if (tab === 'rss') {
        const feedName = rssForm.feedName.trim();
        if (!feedName) {
          onError('Feed name is required');
          return;
        }
        const body = {
          url: rssForm.url,
          category: rssForm.category,
          poll_seconds: Number.parseInt(rssForm.poll_seconds, 10),
          max_articles: Number.parseInt(rssForm.max_articles, 10),
          enabled: rssForm.enabled,
          title: feedName,
        };
        if (editingRss) {
          await patchRssFeed(display, editingRss.id, body);
        } else {
          const id = rssFeedInterestId(feedName, rssIds);
          if (!id) {
            onError('Could not derive an id from the feed name');
            return;
          }
          await createRssFeed(display, { id, ...body });
        }
      } else if (tab === 'stocks') {
        const symbol = stockForm.symbol.trim();
        if (!symbol) {
          onError('Symbol is required');
          return;
        }
        if (editingStock) {
          await patchStockSymbol(display, editingStock.id, {
            symbol,
            display_name: stockForm.display_name,
            enabled: stockForm.enabled,
          });
        } else {
          const id = stockSymbolInterestId(symbol, stockIds);
          if (!id) {
            onError('Could not derive an id from the symbol');
            return;
          }
          await createStockSymbol(display, {
            id,
            symbol,
            display_name: stockForm.display_name,
            enabled: stockForm.enabled,
          });
        }
      } else if (tab === 'jokes' || tab === 'trivia') {
        const categoryId = categoryForm.curatorCategoryId.trim();
        if (!categoryId) {
          onError('Select a curator category');
          return;
        }
        const season = categorySeasonPayload(categoryForm);
        if (typeof season === 'string') {
          onError(season);
          return;
        }
        const pool = {
          label: categoryForm.label,
          is_seasonal: categoryForm.is_seasonal,
          ...season,
          category_prompt: categoryForm.category_prompt || null,
        };
        if (tab === 'jokes') {
          const jokePool = {
            ...pool,
            min_jokes: Number.parseInt(categoryForm.min_pool, 10),
            max_jokes: Number.parseInt(categoryForm.max_pool, 10),
          };
          if (editingJoke) {
            await patchJokeCategory(display, editingJoke.id, jokePool);
          } else {
            await createJokeCategory(display, { id: categoryId, ...jokePool });
          }
        } else {
          const triviaPool = {
            ...pool,
            min_questions: Number.parseInt(categoryForm.min_pool, 10),
            max_questions: Number.parseInt(categoryForm.max_pool, 10),
          };
          if (editingTrivia) {
            await patchTriviaCategory(display, editingTrivia.id, triviaPool);
          } else {
            await createTriviaCategory(display, { id: categoryId, ...triviaPool });
          }
        }
      }
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      onError(errMsg(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>{title}</DialogTitle>
      <DialogContent>
        <Box
          component="fieldset"
          disabled={saving}
          sx={{ border: 'none', margin: 0, padding: 0, minWidth: 0 }}
        >
        <Stack spacing={2} sx={{ pt: 1 }}>
          {tab === 'locations' && (
            <>
              <TextField
                label="Name"
                value={weatherForm.name}
                onChange={(e) => setWeatherForm((f) => ({ ...f, name: e.target.value }))}
                helperText={
                  editingWeather
                    ? undefined
                    : 'Use "City, ST" for US or "City, Country" when naming a place.'
                }
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
              {!editingWeather && (
                <>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={weatherForm.include_weather}
                        onChange={(e) =>
                          setWeatherForm((f) => ({ ...f, include_weather: e.target.checked }))
                        }
                      />
                    }
                    label="Weather"
                  />
                  <FormControlLabel
                    control={
                      <Switch
                        checked={weatherForm.include_weather_alerts}
                        onChange={(e) =>
                          setWeatherForm((f) => ({
                            ...f,
                            include_weather_alerts: e.target.checked,
                          }))
                        }
                      />
                    }
                    label="Weather Alerts"
                  />
                  <FormControlLabel
                    control={
                      <Switch
                        checked={weatherForm.include_local_news}
                        onChange={(e) =>
                          setWeatherForm((f) => ({
                            ...f,
                            include_local_news: e.target.checked,
                          }))
                        }
                      />
                    }
                    label="Local News"
                  />
                </>
              )}
            </>
          )}
          {tab === 'rss' && (
            <>
              <TextField
                label="Feed name"
                value={rssForm.feedName}
                onChange={(e) => setRssForm((f) => ({ ...f, feedName: e.target.value }))}
                fullWidth
                required
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
                      {c.label}
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
              <FormControlLabel
                control={
                  <Switch
                    checked={rssForm.enabled}
                    onChange={(e) => setRssForm((f) => ({ ...f, enabled: e.target.checked }))}
                  />
                }
                label="Interested"
              />
            </>
          )}
          {tab === 'stocks' && (
            <>
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
                label="Interested"
              />
            </>
          )}
          {(tab === 'jokes' || tab === 'trivia') && (
            <>
              <Typography variant="caption" color="text.secondary">
                Pick a curator category; its slug is used as the interest id (for icons and labels).
              </Typography>
              <FormControl fullWidth>
                <InputLabel id="interest-cat-label">Curator category</InputLabel>
                <Select
                  labelId="interest-cat-label"
                  label="Curator category"
                  value={categoryForm.curatorCategoryId}
                  disabled={Boolean(editingJoke || editingTrivia)}
                  onChange={(e) => {
                    const id = e.target.value;
                    const match = curatorCategories.find((c) => c.id === id);
                    setCategoryForm((f) => ({
                      ...f,
                      curatorCategoryId: id,
                      label: match?.label ?? f.label,
                    }));
                  }}
                >
                  {curatorCategories.map((c) => (
                    <MenuItem key={c.id} value={c.id}>
                      {c.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
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
                    onChange={(e) => {
                      const is_seasonal = e.target.checked;
                      setCategoryForm((f) => ({
                        ...f,
                        is_seasonal,
                        ...(is_seasonal
                          ? {}
                          : {
                              start_month: '',
                              start_day: '',
                              end_month: '',
                              end_day: '',
                            }),
                      }));
                    }}
                  />
                }
                label="Seasonal"
              />
              {categoryForm.is_seasonal && (
                <Stack spacing={1}>
                  <Typography variant="caption" color="text.secondary">
                    Active between these calendar dates each year (month 1–12).
                  </Typography>
                  <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
                    <TextField
                      label="Start month"
                      type="number"
                      inputProps={{ min: 1, max: 12 }}
                      value={categoryForm.start_month}
                      onChange={(e) =>
                        setCategoryForm((f) => ({ ...f, start_month: e.target.value }))
                      }
                      fullWidth
                    />
                    <TextField
                      label="Start day"
                      type="number"
                      inputProps={{ min: 1, max: 31 }}
                      value={categoryForm.start_day}
                      onChange={(e) =>
                        setCategoryForm((f) => ({ ...f, start_day: e.target.value }))
                      }
                      fullWidth
                    />
                  </Stack>
                  <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
                    <TextField
                      label="End month"
                      type="number"
                      inputProps={{ min: 1, max: 12 }}
                      value={categoryForm.end_month}
                      onChange={(e) =>
                        setCategoryForm((f) => ({ ...f, end_month: e.target.value }))
                      }
                      fullWidth
                    />
                    <TextField
                      label="End day"
                      type="number"
                      inputProps={{ min: 1, max: 31 }}
                      value={categoryForm.end_day}
                      onChange={(e) =>
                        setCategoryForm((f) => ({ ...f, end_day: e.target.value }))
                      }
                      fullWidth
                    />
                  </Stack>
                </Stack>
              )}
            </>
          )}
        </Stack>
        </Box>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        {canWrite && (
          <Button variant="contained" onClick={() => void save()} disabled={saving}>
            {saving ? 'Saving…' : 'Save'}
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
}
