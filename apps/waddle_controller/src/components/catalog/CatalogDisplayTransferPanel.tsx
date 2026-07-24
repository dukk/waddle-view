import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Divider,
  FormControl,
  FormControlLabel,
  FormLabel,
  InputLabel,
  LinearProgress,
  MenuItem,
  Paper,
  Radio,
  RadioGroup,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { listCatalogItems } from '@/api/catalogTransfer/listCatalogItems';
import { transferCatalogItem } from '@/api/catalogTransfer/transferCatalogItem';
import type {
  CatalogKind,
  CatalogListItem,
  ConflictPolicy,
  TransferResult,
} from '@/api/catalogTransfer/types';
import type { SavedDisplay } from '@/storage/displays';
import { validateCatalogId } from '@/util/catalogId';
import {
  useDisplaysReachability,
  type DisplaysReachabilityMap,
} from '@/util/useDisplaysReachability';

export type CatalogDisplayTransferPanelProps = {
  kind: CatalogKind;
  active: SavedDisplay;
  displays: SavedDisplay[];
  canWrite: boolean;
  /** Items on the active display (for send mode). */
  activeItems: CatalogListItem[];
  onTransferred: () => void;
};

type TransferDirection = 'import' | 'send';

const KIND_LABEL: Record<CatalogKind, string> = {
  screen: 'screen',
  overlay: 'overlay',
  ticker: 'ticker tape',
};

function displayReachable(
  map: DisplaysReachabilityMap,
  displayId: string,
): boolean {
  return map[displayId]?.state === 'online';
}

function formatResultLine(r: TransferResult): string {
  const label = r.displayLabel || r.displayId;
  if (r.status === 'skipped') {
    return `${label}: skipped${r.message ? ` (${r.message})` : ''}`;
  }
  if (r.status === 'failed') {
    return `${label}: failed${r.message ? ` — ${r.message}` : ''}`;
  }
  return `${label}: ${r.status}`;
}

export function CatalogDisplayTransferPanel({
  kind,
  active,
  displays,
  canWrite,
  activeItems,
  onTransferred,
}: CatalogDisplayTransferPanelProps) {
  const otherDisplays = useMemo(
    () => displays.filter((d) => d.id !== active.id),
    [displays, active.id],
  );
  const { reachability } = useDisplaysReachability(displays);

  const [direction, setDirection] = useState<TransferDirection>('send');
  const [sourceDisplayId, setSourceDisplayId] = useState('');
  const [importItems, setImportItems] = useState<CatalogListItem[]>([]);
  const [importItemsLoading, setImportItemsLoading] = useState(false);
  const [importItemsError, setImportItemsError] = useState<string | null>(null);
  const [selectedItemId, setSelectedItemId] = useState('');
  const [targetIds, setTargetIds] = useState<Set<string>>(() => new Set());
  const [policy, setPolicy] = useState<ConflictPolicy>('skip');
  const [newId, setNewId] = useState('');
  const [newLabel, setNewLabel] = useState('');
  const [running, setRunning] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [results, setResults] = useState<TransferResult[] | null>(null);
  const [sourceMissing, setSourceMissing] = useState(false);

  useEffect(() => {
    if (otherDisplays.length > 0 && !sourceDisplayId) {
      setSourceDisplayId(otherDisplays[0]!.id);
    }
  }, [otherDisplays, sourceDisplayId]);

  const sourceDisplay = useMemo(
    () =>
      direction === 'import'
        ? displays.find((d) => d.id === sourceDisplayId) ?? null
        : active,
    [direction, displays, sourceDisplayId, active],
  );

  const itemOptions = direction === 'send' ? activeItems : importItems;

  useEffect(() => {
    setSelectedItemId('');
    setResults(null);
    setSourceMissing(false);
  }, [direction, sourceDisplayId, kind]);

  useEffect(() => {
    if (direction !== 'import' || !sourceDisplay) {
      setImportItems([]);
      return;
    }
    let cancelled = false;
    setImportItemsLoading(true);
    setImportItemsError(null);
    void listCatalogItems(kind, sourceDisplay)
      .then((items) => {
        if (!cancelled) setImportItems(items);
      })
      .catch((e) => {
        if (!cancelled) {
          setImportItemsError(String(e));
          setImportItems([]);
        }
      })
      .finally(() => {
        if (!cancelled) setImportItemsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [direction, sourceDisplay, kind]);

  const toggleTarget = useCallback((id: string) => {
    setTargetIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const selectAllTargets = useCallback(() => {
    setTargetIds(new Set(otherDisplays.map((d) => d.id)));
  }, [otherDisplays]);

  const clearTargets = useCallback(() => {
    setTargetIds(new Set());
  }, []);

  const runTransfer = async () => {
    setFormError(null);
    setResults(null);
    setSourceMissing(false);

    if (!selectedItemId) {
      setFormError(`Select a ${KIND_LABEL[kind]} to transfer.`);
      return;
    }

    if (!sourceDisplay) {
      setFormError('Select a source display.');
      return;
    }

    if (!displayReachable(reachability, sourceDisplay.id)) {
      setFormError('Source display is offline or unreachable.');
      return;
    }

    const targets: SavedDisplay[] =
      direction === 'import'
        ? [active]
        : otherDisplays.filter((d) => targetIds.has(d.id));

    if (direction === 'send' && targets.length === 0) {
      setFormError('Select at least one target display.');
      return;
    }

    for (const t of targets) {
      if (!displayReachable(reachability, t.id)) {
        setFormError(`Target display “${t.label}” is offline or unreachable.`);
        return;
      }
    }

    if (policy === 'new_id') {
      const idErr = validateCatalogId(newId);
      if (idErr) {
        setFormError(idErr);
        return;
      }
    }

    setRunning(true);
    try {
      const out = await transferCatalogItem({
        kind,
        source: sourceDisplay,
        targets,
        itemId: selectedItemId,
        policy,
        newId: policy === 'new_id' ? newId.trim() : undefined,
        newLabel:
          policy === 'new_id' && kind === 'overlay' ? newLabel.trim() : undefined,
      });
      if (out.sourceMissing) {
        setSourceMissing(true);
        setFormError(`Item not found on source display.`);
        return;
      }
      setResults(out.results);
      const touchedActive = out.results.some(
        (r) =>
          r.displayId === active.id &&
          (r.status === 'created' || r.status === 'updated'),
      );
      if (touchedActive) {
        onTransferred();
      }
    } catch (e) {
      setFormError(String(e));
    } finally {
      setRunning(false);
    }
  };

  if (!canWrite || displays.length <= 1) {
    return null;
  }

  const kindLabel = KIND_LABEL[kind];

  return (
    <Paper variant="outlined" sx={{ p: 2, width: '100%' }}>
      <Typography variant="subtitle1" gutterBottom sx={{
        fontWeight: 600
      }}>
        Copy between displays
      </Typography>
      <Typography
        variant="body2"
        sx={{
          color: "text.secondary",
          mb: 2
        }}>
        Copy a {kindLabel} from another display into{' '}
        <strong>{active.label}</strong>, or send one from this display to others.
        Curator membership and feed/content rows are not copied.
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }}>
        Screens and ticker tapes may reference data keys, integrations, or content that
        exists only on the source display. Overlay images are re-uploaded to each target.
      </Alert>
      <Stack spacing={2}>
        <FormControl>
          <FormLabel id="transfer-direction">Direction</FormLabel>
          <RadioGroup
            row
            aria-labelledby="transfer-direction"
            value={direction}
            onChange={(_, v) => setDirection(v as TransferDirection)}
          >
            <FormControlLabel
              value="import"
              control={<Radio />}
              label={`Import into ${active.label}`}
            />
            <FormControlLabel
              value="send"
              control={<Radio />}
              label={`Send from ${active.label}`}
            />
          </RadioGroup>
        </FormControl>

        {direction === 'import' ? (
          <FormControl fullWidth>
            <InputLabel id="transfer-source-display">Source display</InputLabel>
            <Select
              labelId="transfer-source-display"
              label="Source display"
              value={sourceDisplayId}
              onChange={(e) => setSourceDisplayId(String(e.target.value))}
            >
              {otherDisplays.map((d) => (
                <MenuItem key={d.id} value={d.id} disabled={!displayReachable(reachability, d.id)}>
                  {d.label}
                  {reachability[d.id]?.state === 'offline' ? ' (offline)' : ''}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        ) : null}

        <FormControl fullWidth disabled={importItemsLoading && direction === 'import'}>
          <InputLabel id="transfer-item">{kindLabel}</InputLabel>
          <Select
            labelId="transfer-item"
            label={kindLabel}
            value={selectedItemId}
            onChange={(e) => setSelectedItemId(String(e.target.value))}
          >
            {itemOptions.map((item) => (
              <MenuItem key={item.id} value={item.id}>
                {item.label} ({item.id})
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        {importItemsError ? (
          <Alert severity="error">{importItemsError}</Alert>
        ) : null}

        {direction === 'send' ? (
          <Box>
            <Stack
              direction="row"
              sx={{
                alignItems: "center",
                justifyContent: "space-between",
                mb: 1
              }}>
              <Typography variant="body2" sx={{
                fontWeight: 600
              }}>
                Target displays
              </Typography>
              <Stack direction="row" spacing={1}>
                <Button size="small" onClick={selectAllTargets}>
                  Select all
                </Button>
                <Button size="small" onClick={clearTargets}>
                  Clear
                </Button>
              </Stack>
            </Stack>
            <Stack spacing={0.5}>
              {otherDisplays.map((d) => (
                <FormControlLabel
                  key={d.id}
                  control={
                    <Checkbox
                      checked={targetIds.has(d.id)}
                      onChange={() => toggleTarget(d.id)}
                      disabled={!displayReachable(reachability, d.id)}
                    />
                  }
                  label={
                    <>
                      {d.label}
                      {reachability[d.id]?.state === 'offline' ? ' (offline)' : ''}
                    </>
                  }
                />
              ))}
            </Stack>
          </Box>
        ) : null}

        <FormControl>
          <FormLabel id="transfer-conflict">If the id already exists on target</FormLabel>
          <RadioGroup
            aria-labelledby="transfer-conflict"
            value={policy}
            onChange={(_, v) => setPolicy(v as ConflictPolicy)}
          >
            <FormControlLabel value="skip" control={<Radio />} label="Skip" />
            <FormControlLabel value="overwrite" control={<Radio />} label="Overwrite" />
            <FormControlLabel value="new_id" control={<Radio />} label="Use new id" />
          </RadioGroup>
        </FormControl>

        {policy === 'new_id' ? (
          <Stack spacing={2} direction={{ xs: 'column', sm: 'row' }}>
            <TextField
              label="New id"
              value={newId}
              onChange={(e) => setNewId(e.target.value)}
              fullWidth
              required
              helperText="Applied on each target when sending to multiple displays."
            />
            {kind === 'overlay' ? (
              <TextField
                label="New label (optional)"
                value={newLabel}
                onChange={(e) => setNewLabel(e.target.value)}
                fullWidth
                helperText="Defaults to the copied overlay label."
              />
            ) : null}
          </Stack>
        ) : null}

        {formError ? <Alert severity="error">{formError}</Alert> : null}
        {sourceMissing ? (
          <Alert severity="warning">The selected item was not found on the source display.</Alert>
        ) : null}

        {results && results.length > 0 ? (
          <Alert severity={results.some((r) => r.status === 'failed') ? 'warning' : 'success'}>
            <Typography variant="body2" sx={{ fontWeight: 600, mb: 0.5 }}>
              Transfer results
            </Typography>
            {results.map((r) => (
              <Typography key={r.displayId} variant="body2" sx={{
                display: "block"
              }}>
                {formatResultLine(r)}
              </Typography>
            ))}
          </Alert>
        ) : null}

        {running ? <LinearProgress /> : null}

        <Divider />

        <Box>
          <Button variant="contained" disabled={running} onClick={() => void runTransfer()}>
            {direction === 'import' ? 'Import' : 'Send'}
          </Button>
        </Box>
      </Stack>
    </Paper>
  );
}
