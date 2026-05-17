import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material';
import Form from '@rjsf/mui';
import validator from '@rjsf/validator-ajv8';
import type { RJSFSchema } from '@rjsf/utils';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { integrationDisplayName } from '@/util/integrationDisplayName';
import { parseJsonObject } from '@/util/json';

type IntegrationRow = {
  id: string;
  integration_type: string;
  enabled: boolean;
  poll_seconds: number;
  base_url: string | null;
  config_json: unknown;
  config_json_schema?: unknown;
  example_config_json?: unknown;
};

const permissiveConfigSchema: RJSFSchema = {
  type: 'object',
  additionalProperties: true,
};

function integrationConfigSchema(row: IntegrationRow): RJSFSchema {
  const raw = row.config_json_schema;
  if (raw != null && typeof raw === 'object' && !Array.isArray(raw)) {
    return raw as RJSFSchema;
  }
  if (typeof raw === 'string') {
    const t = raw.trim();
    if (t) {
      try {
        const parsed: unknown = JSON.parse(t);
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
          return parsed as RJSFSchema;
        }
      } catch {
        /* fall through */
      }
    }
  }
  return permissiveConfigSchema;
}

function configJsonSatisfiesSchema(row: IntegrationRow): boolean {
  const schema = integrationConfigSchema(row);
  const formData = parseJsonObject(row.config_json);
  const { errors } = validator.validateFormData(formData, schema);
  return errors.length === 0;
}

function sortById(a: IntegrationRow, b: IntegrationRow): number {
  return a.id.localeCompare(b.id);
}

/** Provider `integration_type` values use a `{family}_{implementation}` prefix (e.g. `calendar_google`). */
function integrationDataFamily(integrationType: string): string {
  const t = integrationType.trim();
  const u = t.indexOf('_');
  if (u <= 0) {
    return t.length > 0 ? t : 'other';
  }
  return t.slice(0, u);
}

function familyLabel(family: string): string {
  if (family.length === 0) return 'Other';
  return family.charAt(0).toUpperCase() + family.slice(1);
}

/** Preferred chip order for known integration families; unknown families sort after these. */
const FAMILY_ORDER: readonly string[] = [
  'calendar',
  'joke',
  'media',
  'news',
  'stock',
  'trivia',
  'weather',
  'stub',
];

function compareFamilies(a: string, b: string): number {
  const ai = FAMILY_ORDER.indexOf(a);
  const bi = FAMILY_ORDER.indexOf(b);
  if (ai >= 0 && bi >= 0) return ai - bi;
  if (ai >= 0) return -1;
  if (bi >= 0) return 1;
  return a.localeCompare(b);
}

export function IntegrationsPage() {
  const { active } = useDisplay();
  const [rows, setRows] = useState<IntegrationRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [edit, setEdit] = useState<IntegrationRow | null>(null);
  const [dialogIntent, setDialogIntent] = useState<'edit' | 'enable'>('edit');
  const [filterFamily, setFilterFamily] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    setError(null);
    try {
      const res = await apiJson<{ items: IntegrationRow[] }>(active, '/v1/integrations');
      setRows(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  }, [active]);

  useEffect(() => {
    void load();
  }, [load]);

  const familiesInUse = useMemo(() => {
    const set = new Set(rows.map((r) => integrationDataFamily(r.integration_type)));
    return [...set].sort(compareFamilies);
  }, [rows]);

  useEffect(() => {
    if (filterFamily != null && !familiesInUse.includes(filterFamily)) {
      setFilterFamily(null);
    }
  }, [filterFamily, familiesInUse]);

  const familyCounts = useMemo(() => {
    const m = new Map<string, number>();
    for (const r of rows) {
      const f = integrationDataFamily(r.integration_type);
      m.set(f, (m.get(f) ?? 0) + 1);
    }
    return m;
  }, [rows]);

  const filteredRows = useMemo(() => {
    if (filterFamily == null) return rows;
    return rows.filter((r) => integrationDataFamily(r.integration_type) === filterFamily);
  }, [rows, filterFamily]);

  const { enabledRows, disabledRows } = useMemo(() => {
    const enabled = filteredRows.filter((r) => r.enabled).sort(sortById);
    const disabled = filteredRows.filter((r) => !r.enabled).sort(sortById);
    return { enabledRows: enabled, disabledRows: disabled };
  }, [filteredRows]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      {error && <Alert severity="error">{error}</Alert>}

      <Stack spacing={1}>
        <Typography variant="subtitle2" color="text.secondary">
          Filter by data type
        </Typography>
        <Stack direction="row" flexWrap="wrap" useFlexGap spacing={1}>
          <Chip
            label={`All (${rows.length})`}
            onClick={() => setFilterFamily(null)}
            color={filterFamily === null ? 'primary' : 'default'}
            variant={filterFamily === null ? 'filled' : 'outlined'}
            clickable
          />
          {familiesInUse.map((family) => {
            const n = familyCounts.get(family) ?? 0;
            const selected = filterFamily === family;
            return (
              <Chip
                key={family}
                label={`${familyLabel(family)} (${n})`}
                onClick={() => setFilterFamily(family)}
                color={selected ? 'primary' : 'default'}
                variant={selected ? 'filled' : 'outlined'}
                clickable
              />
            );
          })}
        </Stack>
      </Stack>

      {filterFamily != null && filteredRows.length === 0 ? (
        <Typography variant="body2" color="text.secondary">
          No integrations match this filter.
        </Typography>
      ) : null}

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Enabled
        </Typography>
        {enabledRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            {filterFamily != null
              ? 'No enabled integrations match this filter.'
              : 'No integrations are enabled.'}
          </Typography>
        ) : (
          <Box
            sx={{
              display: 'grid',
              gap: 2,
              gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
            }}
          >
            {enabledRows.map((r) => (
              <IntegrationCard
                key={r.id}
                row={r}
                actionLabel="Edit"
                onAction={() => {
                  setDialogIntent('edit');
                  setEdit(r);
                }}
              />
            ))}
          </Box>
        )}
      </Stack>

      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={600}>
          Available to enable
        </Typography>
        {disabledRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            {filterFamily != null
              ? 'No disabled integrations match this filter.'
              : 'All integrations are enabled.'}
          </Typography>
        ) : (
          <Box
            sx={{
              display: 'grid',
              gap: 2,
              gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
            }}
          >
            {disabledRows.map((r) => {
              const configOk = configJsonSatisfiesSchema(r);
              return (
                <IntegrationCard
                  key={r.id}
                  row={r}
                  actionLabel="Enable"
                  configSatisfied={configOk}
                  onAction={() => {
                    setDialogIntent('enable');
                    setEdit(r);
                  }}
                />
              );
            })}
          </Box>
        )}
      </Stack>

      {edit && (
        <EditIntegrationDialog
          row={edit}
          intent={dialogIntent}
          onClose={() => setEdit(null)}
          onSaved={async () => {
            setEdit(null);
            await load();
          }}
        />
      )}
    </Stack>
  );
}

function IntegrationCard({
  row,
  actionLabel,
  onAction,
  configSatisfied,
}: {
  row: IntegrationRow;
  actionLabel: string;
  onAction: () => void;
  /** When false on an Enable card, turning the integration on is blocked until config_json validates. */
  configSatisfied?: boolean;
}) {
  const showConfigHint = actionLabel === 'Enable' && configSatisfied === false;
  const displayName = integrationDisplayName(row.integration_type);

  return (
    <Card
      variant="outlined"
      sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
      aria-label={`${displayName} integration`}
    >
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Typography variant="subtitle1" fontWeight={600} sx={{ wordBreak: 'break-word' }}>
            {displayName}
          </Typography>
          <Typography variant="caption" color="text.secondary" display="block">
            Poll every {row.poll_seconds}s
          </Typography>
          {row.base_url ? (
            <Typography variant="caption" color="text.secondary" sx={{ wordBreak: 'break-all' }}>
              {row.base_url}
            </Typography>
          ) : null}
          {showConfigHint ? (
            <Chip size="small" color="warning" label="Configuration does not match schema" />
          ) : null}
        </Stack>
      </CardContent>
      <CardActions sx={{ justifyContent: 'flex-end', px: 2, pb: 2 }}>
        <Button size="small" variant="outlined" onClick={onAction}>
          {actionLabel}
        </Button>
      </CardActions>
    </Card>
  );
}

function EditIntegrationDialog({
  row,
  intent,
  onClose,
  onSaved,
}: {
  row: IntegrationRow;
  intent: 'edit' | 'enable';
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const { active } = useDisplay();
  const schema = useMemo(() => integrationConfigSchema(row), [row]);
  const [enabled, setEnabled] = useState(() => (intent === 'enable' ? true : row.enabled));
  const [poll, setPoll] = useState(row.poll_seconds);
  const [baseUrl, setBaseUrl] = useState(row.base_url ?? '');
  const [formData, setFormData] = useState<Record<string, unknown>>(() =>
    parseJsonObject(row.config_json),
  );
  const [err, setErr] = useState<string | null>(null);

  const displayName = useMemo(
    () => integrationDisplayName(row.integration_type),
    [row.integration_type],
  );

  const save = async () => {
    if (!active) return;
    setErr(null);
    if (enabled) {
      const { errors } = validator.validateFormData(formData, schema);
      if (errors.length > 0) {
        setErr(errors.map((e) => e.stack ?? e.message ?? 'Invalid field').join('\n'));
        return;
      }
    }
    if (poll <= 0) {
      setErr('Poll seconds must be greater than zero.');
      return;
    }
    try {
      await apiFetch(active, `/v1/integrations/${encodeURIComponent(row.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          enabled,
          poll_seconds: poll,
          base_url: baseUrl.trim() || null,
          config_json: formData,
        }),
      });
      await onSaved();
    } catch (e) {
      setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
    }
  };

  const title = intent === 'enable' ? `Enable ${displayName}` : `Edit ${displayName}`;

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="md">
      <DialogTitle>{title}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          {err && <Alert severity="error">{err}</Alert>}
          <Stack direction="row" alignItems="center" spacing={1}>
            <Switch checked={enabled} onChange={(_, v) => setEnabled(v)} />
            <Typography>Enabled</Typography>
          </Stack>
          <TextField
            label="Poll seconds"
            type="number"
            value={poll}
            onChange={(e) => setPoll(Number(e.target.value) || 0)}
            fullWidth
          />
          <TextField
            label="Base URL"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            fullWidth
          />
          <Typography variant="subtitle2">Configuration (config_json)</Typography>
          <Box sx={{ '& .MuiFormControl-root': { mb: 1 } }}>
            <Form
              schema={schema}
              formData={formData}
              validator={validator}
              onChange={(e) => setFormData(e.formData as Record<string, unknown>)}
            >
              <Box sx={{ display: 'none' }}>
                <button type="submit" />
              </Box>
            </Form>
          </Box>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void save()} disabled={poll <= 0}>
          Save
        </Button>
      </DialogActions>
    </Dialog>
  );
}
