import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  IconButton,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import {
  listMealviewerDistrictSchools,
  listMealviewerDistricts,
  probeMealviewerSchool,
  searchMealviewerSchools,
  type MealviewerDistrictItem,
  type MealviewerSchoolItem,
} from '@/api/mealviewerSchools';
import { ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import {
  CategoryMultiSelect,
  type ContentCategoryOption,
} from '@/components/CategoryMultiSelect';
import { IntegrationConfigSection } from '@/components/IntegrationConfigSection';
import {
  mergeSchoolIntoList,
  type MealviewerCalendarConfigState,
  type MealviewerSchoolConfig,
} from '@/util/mealviewerCalendarConfig';

export type { ContentCategoryOption };

type Props = {
  display: SavedDisplay;
  value: MealviewerCalendarConfigState;
  onChange: (next: MealviewerCalendarConfigState) => void;
  categories: ContentCategoryOption[];
  disabled?: boolean;
};

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

function schoolFromApi(
  item: MealviewerSchoolItem,
  categoryIds: string[] = [],
): MealviewerSchoolConfig {
  return {
    schoolSlug: item.school_slug,
    label: item.label,
    districtSlug: item.district_slug,
    categoryIds,
  };
}

export function MealviewerCalendarConfigSection({
  display,
  value,
  onChange,
  categories,
  disabled = false,
}: Props) {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [searchResults, setSearchResults] = useState<MealviewerSchoolItem[]>([]);

  const [districtQuery, setDistrictQuery] = useState('');
  const [districtsLoading, setDistrictsLoading] = useState(false);
  const [districtsError, setDistrictsError] = useState<string | null>(null);
  const [districts, setDistricts] = useState<MealviewerDistrictItem[]>([]);
  const [selectedDistrict, setSelectedDistrict] = useState<MealviewerDistrictItem | null>(
    null,
  );
  const [districtSchoolsLoading, setDistrictSchoolsLoading] = useState(false);
  const [districtSchools, setDistrictSchools] = useState<MealviewerSchoolItem[]>([]);

  const [manualSlug, setManualSlug] = useState('');
  const [probeLoading, setProbeLoading] = useState(false);
  const [probeError, setProbeError] = useState<string | null>(null);

  const configuredKeys = useMemo(
    () => new Set(value.schools.map((s) => s.schoolSlug)),
    [value.schools],
  );

  const defaultCategoryIds = useMemo(
    () => (categories.length > 0 ? [categories[0].id] : []),
    [categories],
  );

  const addSchool = useCallback(
    (item: MealviewerSchoolItem) => {
      const school = schoolFromApi(item, defaultCategoryIds);
      onChange({
        ...value,
        schools: mergeSchoolIntoList(value.schools, school),
      });
    },
    [defaultCategoryIds, onChange, value],
  );

  const runSearch = useCallback(async () => {
    const q = searchQuery.trim();
    if (q.length < 2) {
      setSearchResults([]);
      return;
    }
    setSearchLoading(true);
    setSearchError(null);
    try {
      const items = await searchMealviewerSchools(display, q);
      setSearchResults(items.filter((s) => !configuredKeys.has(s.school_slug)));
    } catch (e) {
      setSearchError(errMsg(e));
      setSearchResults([]);
    } finally {
      setSearchLoading(false);
    }
  }, [configuredKeys, display, searchQuery]);

  useEffect(() => {
    const t = window.setTimeout(() => {
      void runSearch();
    }, 350);
    return () => window.clearTimeout(t);
  }, [runSearch]);

  const loadDistricts = useCallback(async () => {
    setDistrictsLoading(true);
    setDistrictsError(null);
    try {
      const items = await listMealviewerDistricts(display, districtQuery.trim() || undefined);
      setDistricts(items);
    } catch (e) {
      setDistrictsError(errMsg(e));
      setDistricts([]);
    } finally {
      setDistrictsLoading(false);
    }
  }, [display, districtQuery]);

  useEffect(() => {
    void loadDistricts();
  }, [loadDistricts]);

  const selectDistrict = useCallback(
    async (district: MealviewerDistrictItem) => {
      setSelectedDistrict(district);
      setDistrictSchoolsLoading(true);
      try {
        const items = await listMealviewerDistrictSchools(display, district.district_slug);
        setDistrictSchools(items.filter((s) => !configuredKeys.has(s.school_slug)));
      } catch (e) {
        setDistrictsError(errMsg(e));
        setDistrictSchools([]);
      } finally {
        setDistrictSchoolsLoading(false);
      }
    },
    [configuredKeys, display],
  );

  const verifyManualSlug = useCallback(async () => {
    const slug = manualSlug.trim().split(/\s+/).join('');
    if (!slug) {
      return;
    }
    setProbeLoading(true);
    setProbeError(null);
    try {
      const res = await probeMealviewerSchool(display, slug);
      addSchool(res.school);
      setManualSlug('');
    } catch (e) {
      setProbeError(errMsg(e));
    } finally {
      setProbeLoading(false);
    }
  }, [addSchool, display, manualSlug]);

  const patchSchool = (slug: string, partial: Partial<MealviewerSchoolConfig>) => {
    onChange({
      ...value,
      schools: value.schools.map((s) =>
        s.schoolSlug === slug ? { ...s, ...partial } : s,
      ),
    });
  };

  const removeSchool = (slug: string) => {
    onChange({
      ...value,
      schools: value.schools.filter((s) => s.schoolSlug !== slug),
    });
  };

  return (
    <IntegrationConfigSection
      title="MealViewer school menus"
      description="Search or browse districts to add schools, then assign event categories for each school menu."
    >
      <Typography variant="subtitle2">Sync window (days)</Typography>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
        <TextField
          label="Past days"
          type="number"
          value={value.pastDays}
          onChange={(e) =>
            onChange({ ...value, pastDays: Math.max(1, Number(e.target.value) || 30) })
          }
          disabled={disabled}
          size="small"
          fullWidth
        />
        <TextField
          label="Future days"
          type="number"
          value={value.futureDays}
          onChange={(e) =>
            onChange({ ...value, futureDays: Math.max(1, Number(e.target.value) || 30) })
          }
          disabled={disabled}
          size="small"
          fullWidth
        />
      </Stack>

      <Typography variant="subtitle2">Search schools</Typography>
      <TextField
        label="School name"
        placeholder="Type at least 2 characters"
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        disabled={disabled}
        size="small"
        fullWidth
      />
      {searchLoading ? <CircularProgress size={24} /> : null}
      {searchError ? <Alert severity="error">{searchError}</Alert> : null}
      {searchResults.length > 0 ? (
        <List dense disablePadding>
          {searchResults.slice(0, 15).map((s) => (
            <ListItem key={s.school_slug} disablePadding>
              <ListItemButton onClick={() => addSchool(s)} disabled={disabled}>
                <ListItemText
                  primary={s.label}
                  secondary={[s.city, s.state, s.school_slug].filter(Boolean).join(' · ')}
                />
              </ListItemButton>
            </ListItem>
          ))}
        </List>
      ) : null}

      <Typography variant="subtitle2">Browse by district</Typography>
      <TextField
        label="Filter districts"
        value={districtQuery}
        onChange={(e) => setDistrictQuery(e.target.value)}
        disabled={disabled}
        size="small"
        fullWidth
      />
      {districtsLoading ? <CircularProgress size={24} /> : null}
      {districtsError ? <Alert severity="error">{districtsError}</Alert> : null}
      <Stack direction={{ xs: 'column', md: 'row' }} spacing={2}>
        <Box sx={{ flex: 1, maxHeight: 200, overflow: 'auto', border: 1, borderColor: 'divider' }}>
          <List dense>
            {districts.slice(0, 40).map((d) => (
              <ListItem key={d.district_slug} disablePadding>
                <ListItemButton
                  selected={selectedDistrict?.district_slug === d.district_slug}
                  onClick={() => void selectDistrict(d)}
                  disabled={disabled}
                >
                  <ListItemText
                    primary={d.label}
                    secondary={d.state_code ?? d.district_slug}
                  />
                </ListItemButton>
              </ListItem>
            ))}
          </List>
        </Box>
        <Box sx={{ flex: 1, maxHeight: 200, overflow: 'auto', border: 1, borderColor: 'divider' }}>
          {districtSchoolsLoading ? (
            <Box sx={{ p: 2 }}>
              <CircularProgress size={24} />
            </Box>
          ) : selectedDistrict == null ? (
            <Typography variant="body2" color="text.secondary" sx={{ p: 2 }}>
              Select a district to list schools.
            </Typography>
          ) : districtSchools.length === 0 ? (
            <Typography variant="body2" color="text.secondary" sx={{ p: 2 }}>
              No schools to add in this district.
            </Typography>
          ) : (
            <List dense>
              {districtSchools.map((s) => (
                <ListItem key={s.school_slug} disablePadding>
                  <ListItemButton onClick={() => addSchool(s)} disabled={disabled}>
                    <ListItemText primary={s.label} secondary={s.school_slug} />
                  </ListItemButton>
                </ListItem>
              ))}
            </List>
          )}
        </Box>
      </Stack>

      <Typography variant="subtitle2">Manual school slug</Typography>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems="flex-start">
        <TextField
          label="School slug"
          placeholder="ElmwoodElementary"
          value={manualSlug}
          onChange={(e) => setManualSlug(e.target.value)}
          disabled={disabled}
          size="small"
          fullWidth
        />
        <Button
          variant="outlined"
          onClick={() => void verifyManualSlug()}
          disabled={disabled || probeLoading || manualSlug.trim() === ''}
        >
          {probeLoading ? 'Verifying…' : 'Verify & add'}
        </Button>
      </Stack>
      {probeError ? <Alert severity="error">{probeError}</Alert> : null}

      <Typography variant="subtitle2">Configured schools</Typography>
      {value.schools.length === 0 ? (
        <Alert severity="info">Add at least one school before enabling this integration.</Alert>
      ) : (
        value.schools.map((school) => (
          <Stack
            key={school.schoolSlug}
            spacing={1}
            sx={{ p: 1.5, border: 1, borderColor: 'divider', borderRadius: 1 }}
          >
            <Stack direction="row" alignItems="center" justifyContent="space-between">
              <Box>
                <Typography variant="body2" fontWeight={600}>
                  {school.label}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {school.schoolSlug}
                  {school.districtSlug ? ` · ${school.districtSlug}` : ''}
                </Typography>
              </Box>
              <IconButton
                aria-label="Remove school"
                onClick={() => removeSchool(school.schoolSlug)}
                disabled={disabled}
                size="small"
              >
                <DeleteOutlineIcon fontSize="small" />
              </IconButton>
            </Stack>
            <CategoryMultiSelect
              id={`mealviewer-cal-cat-${school.schoolSlug}`}
              label="Event categories"
              categories={categories}
              value={school.categoryIds}
              onChange={(ids) => patchSchool(school.schoolSlug, { categoryIds: ids })}
              disabled={disabled}
            />
          </Stack>
        ))
      )}
    </IntegrationConfigSection>
  );
}
