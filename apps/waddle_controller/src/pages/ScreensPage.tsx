import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Chip,
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
import { CatalogPageToolbar } from '@/components/CatalogPageToolbar';
import { CatalogPageHelp } from '@/components/CatalogPageHelp';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import { ScreenSchedulingHelpContent } from '@/components/help/ScreenSchedulingHelpContent';
import {
  ScreenCarouselFallbackIcon,
  SlideScreenPreviewIcon,
} from '@/icons/slideScreenPreviewIcon';
import { screenTypePreviewKind } from '@/util/programTelemetry';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { CatalogDisplayTransferPanel } from '@/components/catalog/CatalogDisplayTransferPanel';
import { CatalogListWithTransferSection } from '@/components/catalog/CatalogListWithTransferSection';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { ScreenDialog, type ScreenDialogRow } from '@/components/screens/ScreenDialog';
import { parseJsonObject } from '@/util/json';
import { useConfigSchemas } from '@/hooks/useConfigSchemas';
import {
  exampleForScreenType,
  schemaForScreenType,
} from '@/storage/configSchemaCache';
import { screenTypeLabel, screenTypeMetaFor } from '@/util/screenTypeLabel';

type ScreenRow = ScreenDialogRow & {
  config_json_schema?: string;
  example_config_json?: string;
  data_key: string;
};

function sortById(a: ScreenRow, b: ScreenRow): number {
  return a.id.localeCompare(b.id);
}

function screenRowTitle(row: Pick<ScreenRow, 'id' | 'label'>): string {
  return (row.label ?? '').trim() || row.id;
}

function screenRowHasCustomTitle(row: Pick<ScreenRow, 'label'>): boolean {
  return Boolean((row.label ?? '').trim());
}

function screenRowDescription(row: Pick<ScreenRow, 'description'>): string {
  return typeof row.description === 'string' ? row.description.trim() : '';
}

function readOptionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function readNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function readOptionalNumber(value: unknown): number | null {
  if (value == null) return null;
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function parseScreenRow(raw: Record<string, unknown>): ScreenRow | null {
  const id = typeof raw.id === 'string' ? raw.id.trim() : '';
  const screenType = typeof raw.screen_type === 'string' ? raw.screen_type.trim() : '';
  if (!id || !screenType) return null;

  let configJson = '{}';
  if (typeof raw.config_json === 'string') {
    configJson = raw.config_json;
  } else if (raw.config_json != null && typeof raw.config_json === 'object') {
    configJson = JSON.stringify(raw.config_json);
  }

  return {
    id,
    label: readOptionalString(raw.label) ?? readOptionalString(raw.name),
    description: readOptionalString(raw.description),
    screen_type: screenType,
    config_json: configJson,
    config_json_schema: readOptionalString(raw.config_json_schema),
    example_config_json: readOptionalString(raw.example_config_json),
    min_dwell_seconds: readNumber(raw.min_dwell_seconds, 8),
    max_dwell_seconds: readNumber(raw.max_dwell_seconds, 15),
    frequency_weight: readNumber(raw.frequency_weight, 100),
    min_gap_between_shows_seconds: readNumber(raw.min_gap_between_shows_seconds),
    min_placements_per_program: readNumber(raw.min_placements_per_program),
    max_placements_per_program: readOptionalNumber(raw.max_placements_per_program),
    data_key: readOptionalString(raw.data_key) ?? '',
  };
}

const screenCardPreviewSx = {
  borderRadius: 1,
  bgcolor: 'action.hover',
  minHeight: 100,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
} as const;

function ScreenTable({
  rows,
  screenTypes,
  onEdit,
  onDelete,
}: {
  rows: ScreenRow[];
  screenTypes: { screen_type: string; config_json_schema?: unknown }[];
  onEdit: (row: ScreenRow) => void;
  onDelete: (id: string) => void;
}) {
  return (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Name</TableCell>
            <TableCell>Type</TableCell>
            <TableCell>Dwell (min–max)</TableCell>
            <TableCell>Weight</TableCell>
            <TableCell>Gap</TableCell>
            <TableCell>Description</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => {
            const title = screenRowTitle(row);
            const meta = screenTypeMetaFor(screenTypes, row.screen_type);
            return (
              <TableRow key={row.id} hover>
                <TableCell sx={{ fontWeight: screenRowHasCustomTitle(row) ? 600 : 400 }}>{title}</TableCell>
                <TableCell>{screenTypeLabel(row.screen_type, meta)}</TableCell>
                <TableCell>
                  {row.min_dwell_seconds}–{row.max_dwell_seconds}s
                </TableCell>
                <TableCell>{row.frequency_weight}</TableCell>
                <TableCell>{row.min_gap_between_shows_seconds}s</TableCell>
                <TableCell sx={{ maxWidth: 280, wordBreak: 'break-word' }}>
                  {screenRowDescription(row)}
                </TableCell>
                <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                  <Button size="small" onClick={() => onEdit(row)}>
                    Edit
                  </Button>
                  <Button size="small" color="error" onClick={() => onDelete(row.id)}>
                    Delete
                  </Button>
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

export function ScreensPage() {
  const { active, displays } = useDisplay();
  const { hasPermission } = useAuth();
  const canWrite = hasPermission('screens.write');
  const { loading, wrapRefresh } = useDisplayRefresh();
  const { layout, setLayout } = useListLayoutPreference('screens');
  const [rows, setRows] = useState<ScreenRow[]>([]);
  const { schemas, error: schemasError } = useConfigSchemas(active);
  const [error, setError] = useState<string | null>(null);
  const [dialogMode, setDialogMode] = useState<'create' | 'edit' | null>(null);
  const [editRow, setEditRow] = useState<ScreenRow | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const s = await apiJson<{ items: unknown[] }>(active, '/v1/screens');
        const items = (s.items ?? [])
          .map((raw) =>
            raw && typeof raw === 'object'
              ? parseScreenRow(raw as Record<string, unknown>)
              : null,
          )
          .filter((row): row is ScreenRow => row != null);
        setRows(items);
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    });
  }, [active, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  const schemaForType = useCallback(
    (screenType: string) => schemaForScreenType(schemas, screenType),
    [schemas],
  );

  const exampleForType = useCallback(
    (screenType: string) => parseJsonObject(exampleForScreenType(schemas, screenType)),
    [schemas],
  );

  const sortedRows = useMemo(() => [...rows].sort(sortById), [rows]);

  const transferItems = useMemo(
    () =>
      sortedRows.map((r) => ({
        id: r.id,
        label: screenRowTitle(r),
      })),
    [sortedRows],
  );

  const deleteScreen = useCallback(
    async (id: string) => {
      if (!active) return;
      if (!confirm(`Delete screen ${id}?`)) return;
      try {
        await apiFetch(active, `/v1/screens/${encodeURIComponent(id)}`, {
          method: 'DELETE',
        });
        await load();
      } catch (e) {
        setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
      }
    },
    [active, load],
  );

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  const screenTypes = schemas?.screen_types ?? [];

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      <Box>
        <Stack direction="row" alignItems="center" spacing={0.25} sx={{ mb: 0.5 }}>
          <Typography variant="h6" fontWeight={600}>
            Slideshow slide catalog
          </Typography>
          <CatalogPageHelp title="Screen scheduling">
            <ScreenSchedulingHelpContent />
          </CatalogPageHelp>
        </Stack>
        <Typography variant="body2" color="text.secondary">
          Catalog slide types in the main slideshow (RSS, weather, photos, and others). Set dwell
          time and frequency weight so the curator fills each program&apos;s time budget; the help
          icon explains how placement and recent-history deprioritization work.
        </Typography>
      </Box>
      {(error || schemasError) && (
        <Alert severity="error">{error ?? schemasError}</Alert>
      )}

      <CatalogListWithTransferSection
        toolbar={
          <CatalogPageToolbar layout={layout} onLayoutChange={setLayout}>
            <Button
              variant="contained"
              onClick={() => {
                setEditRow(null);
                setDialogMode('create');
              }}
              disabled={!screenTypes.length}
            >
              Add screen
            </Button>
          </CatalogPageToolbar>
        }
        list={
          sortedRows.length === 0 ? (
            <Typography variant="body2" color="text.secondary">
              No screens in the catalog yet.
            </Typography>
          ) : layout === 'card' ? (
            <Box sx={catalogCardGridSx}>
              {sortedRows.map((r) => (
                <ScreenCard
                  key={r.id}
                  row={r}
                  screenTypes={screenTypes}
                  onEdit={() => {
                    setEditRow(r);
                    setDialogMode('edit');
                  }}
                  onDelete={() => void deleteScreen(r.id)}
                />
              ))}
            </Box>
          ) : (
            <ScreenTable
              rows={sortedRows}
              screenTypes={screenTypes}
              onEdit={(r) => {
                setEditRow(r);
                setDialogMode('edit');
              }}
              onDelete={(id) => void deleteScreen(id)}
            />
          )
        }
        transferPanel={
          canWrite && displays.length > 1 ? (
            <CatalogDisplayTransferPanel
              kind="screen"
              active={active}
              displays={displays}
              canWrite={canWrite}
              activeItems={transferItems}
              onTransferred={() => void load()}
            />
          ) : null
        }
      />

      {dialogMode && schemas && (
        <ScreenDialog
          open
          mode={dialogMode}
          active={active}
          initial={dialogMode === 'edit' ? editRow : null}
          screenTypes={screenTypes}
          schemaForType={schemaForType}
          exampleForType={exampleForType}
          onClose={() => {
            setDialogMode(null);
            setEditRow(null);
          }}
          onSaved={async () => {
            setDialogMode(null);
            setEditRow(null);
            await load();
          }}
        />
      )}
    </Stack>
  );
}

function ScreenCard({
  row,
  screenTypes,
  onEdit,
  onDelete,
}: {
  row: ScreenRow;
  screenTypes: { screen_type: string; config_json_schema?: unknown }[];
  onEdit: () => void;
  onDelete: () => void;
}) {
  const title = screenRowTitle(row);
  const meta = screenTypeMetaFor(screenTypes, row.screen_type);
  const typeLabel = screenTypeLabel(row.screen_type, meta);
  const previewKind = screenTypePreviewKind(row.screen_type);
  const description = screenRowDescription(row);

  return (
    <Card
      variant="outlined"
      sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
      aria-label={`${title} screen`}
    >
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Box sx={screenCardPreviewSx}>
            {previewKind ? (
              <SlideScreenPreviewIcon
                kind={previewKind}
                aria-hidden
                sx={{
                  fontSize: 64,
                  color: 'primary.main',
                  opacity: 0.72,
                }}
              />
            ) : (
              <ScreenCarouselFallbackIcon
                aria-hidden
                sx={{
                  fontSize: 64,
                  color: 'text.secondary',
                  opacity: 0.45,
                }}
              />
            )}
          </Box>
          <Typography variant="subtitle1" fontWeight={600} sx={{ wordBreak: 'break-word' }}>
            {title}
          </Typography>
          <Chip size="small" label={typeLabel} variant="outlined" sx={{ alignSelf: 'flex-start' }} />
          <Typography variant="caption" color="text.secondary" display="block">
            Dwell {row.min_dwell_seconds}–{row.max_dwell_seconds}s · weight {row.frequency_weight} ·
            gap {row.min_gap_between_shows_seconds}s
          </Typography>
          {description ? (
            <Typography variant="body2" color="text.secondary" sx={{ wordBreak: 'break-word' }}>
              {description}
            </Typography>
          ) : null}
        </Stack>
      </CardContent>
      <CardActions sx={{ justifyContent: 'flex-end', px: 2, pb: 2 }}>
        <Button size="small" variant="outlined" onClick={onEdit}>
          Edit
        </Button>
        <Button size="small" variant="outlined" color="error" onClick={onDelete}>
          Delete
        </Button>
      </CardActions>
    </Card>
  );
}
