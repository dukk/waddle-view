import {
  Button,
  Chip,
  FormControlLabel,
  Paper,
  Stack,
  Switch,
  Typography,
} from '@mui/material';
import { CatalogBlobMedia } from '@/components/data/CatalogBlobMedia';
import type { SavedDisplay } from '@/storage/displays';
import { alertSeverityIconComponent } from '@/util/alertSeverityIcon';
import {
  alertLifecycleLabel,
  alertLifecycleStatus,
  alertSeverityLabel,
  alertSourceLabel,
  categoryLabelsForRow,
  newsSourceLabel,
  parseCalendarEventSource,
  type CatalogCategory,
  type IntegrationAccountLabel,
} from '@/util/catalogDisplayLabels';
import { integrationDisplayName } from '@/util/integrationDisplayName';

export type DataCatalogKind =
  | 'calendar_events'
  | 'jokes'
  | 'trivia'
  | 'news'
  | 'photos'
  | 'quoterism_quotes'
  | 'videos'
  | 'stocks'
  | 'weather'
  | 'weather_alerts'
  | 'dashboard_alerts'
  | 'tasks';

type Props = {
  kind: DataCatalogKind;
  row: Record<string, unknown>;
  display: SavedDisplay;
  categories: CatalogCategory[];
  feeds: { id: string; title: string | null; url: string }[];
  integrationAccounts: IntegrationAccountLabel[];
  icalFeedsById: Record<string, { label?: string; url: string }>;
  canModerate: boolean;
  canSuppress: boolean;
  formatDateTime: (d: Date) => string;
  onPatchSuppressed: (id: string, next: boolean) => void;
  onDelete: () => void;
  canDelete: boolean;
};

function integrationCell(row: Record<string, unknown>): string {
  const raw = row.integration_type;
  if (raw == null || typeof raw !== 'string' || !raw.trim()) {
    return '—';
  }
  return integrationDisplayName(raw.trim());
}

function calendarEventWhen(
  ms: unknown,
  allDay: boolean,
  formatDateTime: (d: Date) => string,
): string {
  if (ms == null || ms === '') return '—';
  const d = new Date(Number(ms));
  if (allDay) {
    return `${d.toLocaleDateString()} (all day)`;
  }
  return formatDateTime(d);
}

function CategoryChips({ labels }: { labels: string[] }) {
  if (labels.length === 0) return null;
  return (
    <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
      {labels.map((label) => (
        <Chip key={label} size="small" label={label} variant="outlined" />
      ))}
    </Stack>
  );
}

export function DataCatalogCard({
  kind,
  row,
  display,
  categories,
  feeds,
  integrationAccounts,
  icalFeedsById,
  canModerate,
  canSuppress,
  formatDateTime,
  onPatchSuppressed,
  onDelete,
  canDelete,
}: Props) {
  const id = String(row.id ?? '');
  const suppressed = Boolean(row.suppressed);
  const categoryLabels = categoryLabelsForRow(row, categories);

  const footer = (
    <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap sx={{ mt: 1 }}>
      {canModerate && canSuppress && id ? (
        <FormControlLabel
          control={
            <Switch
              size="small"
              checked={suppressed}
              onChange={(_, v) => onPatchSuppressed(id, v)}
            />
          }
          label="Suppressed"
        />
      ) : null}
      {canModerate && canDelete ? (
        <Button size="small" color="error" onClick={onDelete}>
          Delete
        </Button>
      ) : null}
    </Stack>
  );

  if (kind === 'jokes') {
    return (
      <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Stack spacing={1} sx={{ flexGrow: 1 }}>
          <Typography variant="subtitle2" fontWeight={600}>
            {String(row.setup ?? '')}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: 'pre-wrap' }}>
            {String(row.punchline ?? '')}
          </Typography>
          <CategoryChips labels={categoryLabels} />
          <Typography variant="caption" color="text.secondary">
            {integrationCell(row)}
          </Typography>
        </Stack>
        {footer}
      </Paper>
    );
  }

  if (kind === 'dashboard_alerts') {
    const status = alertLifecycleStatus(row);
    const SeverityIcon = alertSeverityIconComponent(String(row.severity ?? ''));
    return (
      <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Stack spacing={1} sx={{ flexGrow: 1 }}>
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
            <SeverityIcon fontSize="small" color="action" />
            <Typography variant="subtitle2" fontWeight={600}>
              {String(row.title ?? '')}
            </Typography>
            <Chip
              size="small"
              label={alertLifecycleLabel(status)}
              color={status === 'active' ? 'success' : status === 'expired' ? 'default' : 'warning'}
              variant="outlined"
            />
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: 'pre-wrap' }}>
            {String(row.body ?? '')}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {alertSeverityLabel(String(row.severity ?? ''))} · {alertSourceLabel(String(row.source ?? ''))}
          </Typography>
        </Stack>
        {footer}
      </Paper>
    );
  }

  if (kind === 'calendar_events') {
    const sources = parseCalendarEventSource(String(row.source ?? ''), {
      integrationAccounts,
      icalFeedsById,
    });
    return (
      <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Stack spacing={1} sx={{ flexGrow: 1 }}>
          <Typography variant="subtitle2" fontWeight={600}>
            {String(row.title ?? '')}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {calendarEventWhen(row.start_ms, Boolean(row.all_day), formatDateTime)}
            {row.end_ms != null ? ` → ${calendarEventWhen(row.end_ms, Boolean(row.all_day), formatDateTime)}` : ''}
          </Typography>
          {row.location ? (
            <Typography variant="caption" color="text.secondary">
              {String(row.location)}
            </Typography>
          ) : null}
          <CategoryChips labels={categoryLabels} />
          <Typography variant="caption" color="text.secondary">
            {sources.integrationLabel} · {sources.accountOrFeedLabel}
          </Typography>
        </Stack>
        {footer}
      </Paper>
    );
  }

  if (kind === 'news') {
    return (
      <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Stack spacing={1} sx={{ flexGrow: 1 }}>
          <Typography variant="subtitle2" fontWeight={600}>
            {String(row.title ?? '')}
          </Typography>
          {row.summary ? (
            <Typography variant="body2" color="text.secondary" sx={{ wordBreak: 'break-word' }}>
              {String(row.summary)}
            </Typography>
          ) : null}
          <Typography variant="caption" color="text.secondary">
            {newsSourceLabel(row, feeds)}
          </Typography>
        </Stack>
        {footer}
      </Paper>
    );
  }

  if (kind === 'quoterism_quotes') {
    return (
      <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Stack spacing={1} sx={{ flexGrow: 1 }}>
          <Typography variant="caption" color="text.secondary" fontWeight={600}>
            {String(row.author_name ?? '—')}
          </Typography>
          <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
            {String(row.text ?? '')}
          </Typography>
          <CategoryChips labels={categoryLabels} />
          <Typography variant="caption" color="text.secondary">
            {integrationCell(row)}
          </Typography>
        </Stack>
        {footer}
      </Paper>
    );
  }

  if (kind === 'tasks') {
    return (
      <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Stack spacing={1} sx={{ flexGrow: 1 }}>
          <Typography variant="subtitle2" fontWeight={600}>
            {String(row.title ?? '')}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {String(row.list_label ?? '—')} · {String(row.board_key ?? '—')}
          </Typography>
          {row.due_at_ms != null ? (
            <Typography variant="caption" color="text.secondary">
              Due {formatDateTime(new Date(Number(row.due_at_ms)))}
            </Typography>
          ) : null}
          <Chip
            size="small"
            label={row.completed ? 'Completed' : 'Open'}
            color={row.completed ? 'default' : 'primary'}
            variant="outlined"
          />
          <Typography variant="caption" color="text.secondary">
            {integrationCell(row)}
          </Typography>
        </Stack>
        {footer}
      </Paper>
    );
  }

  if (kind === 'trivia') {
    const options = [row.option_a, row.option_b, row.option_c, row.option_d]
      .map((o) => String(o ?? ''))
      .filter(Boolean)
      .join(' · ');
    return (
      <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Stack spacing={1} sx={{ flexGrow: 1 }}>
          <Typography variant="subtitle2" fontWeight={600}>
            {String(row.question ?? '')}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ fontSize: 12 }}>
            {options}
          </Typography>
          <CategoryChips labels={categoryLabels} />
          <Typography variant="caption" color="text.secondary">
            {integrationCell(row)}
          </Typography>
        </Stack>
        {footer}
      </Paper>
    );
  }

  if (kind === 'photos' || kind === 'videos') {
    return (
      <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Stack spacing={1} sx={{ flexGrow: 1 }}>
          <CatalogBlobMedia
            display={display}
            blobKey={row.media_blob_key as string | undefined}
            variant={kind === 'videos' ? 'video' : 'image'}
          />
          <Typography variant="body2">{String(row.alt_text ?? '')}</Typography>
          <CategoryChips labels={categoryLabels} />
          <Typography variant="caption" color="text.secondary">
            {integrationCell(row)}
          </Typography>
        </Stack>
        {footer}
      </Paper>
    );
  }

  const summary =
    kind === 'stocks'
      ? String(row.symbol ?? row.display_name ?? '')
      : kind === 'weather'
        ? String(row.location_name ?? row.current_description ?? '')
        : kind === 'weather_alerts'
          ? String(row.event ?? row.headline ?? '')
          : String(row.id ?? '');

  return (
    <Paper variant="outlined" sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <Stack spacing={1} sx={{ flexGrow: 1 }}>
        <Typography variant="subtitle2" fontWeight={600}>
          {summary}
        </Typography>
        <CategoryChips labels={categoryLabels} />
        <Typography variant="caption" color="text.secondary">
          {integrationCell(row)}
        </Typography>
      </Stack>
      {footer}
    </Paper>
  );
}
