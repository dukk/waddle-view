import { apiFetch, ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { catalogItemExists } from './listCatalogItems';
import { catalogItemPath, catalogListPath } from './paths';
import { remapOverlayBlobKeys } from './remapOverlayBlobKeys';
import type {
  CatalogPayload,
  ConflictPolicy,
  TransferResult,
  TransferResultStatus,
} from './types';

export type PushCatalogItemInput = {
  source: SavedDisplay;
  target: SavedDisplay;
  payload: CatalogPayload;
  policy: ConflictPolicy;
  newId?: string;
  newLabel?: string;
};

export async function pushCatalogItem(
  input: PushCatalogItemInput,
): Promise<TransferResult> {
  const { source, target, payload, policy, newId, newLabel } = input;
  const base: TransferResult = {
    displayId: target.id,
    displayLabel: target.label,
    status: 'failed',
  };

  let targetId = payload.id;
  if (policy === 'new_id') {
    const trimmed = newId?.trim() ?? '';
    if (!trimmed) {
      return { ...base, message: 'New id is required.' };
    }
    targetId = trimmed;
    const taken = await catalogItemExists(payload.kind, target, targetId);
    if (taken) {
      return { ...base, message: `Id "${targetId}" already exists on target display.` };
    }
  }

  const exists = await catalogItemExists(payload.kind, target, targetId);
  if (policy === 'skip' && exists) {
    return { ...base, status: 'skipped', message: 'Already exists on target display.' };
  }

  try {
    if (payload.kind === 'overlay') {
      return await pushOverlay({
        source,
        target,
        payload,
        policy,
        targetId,
        exists,
        newLabel,
        base,
      });
    }
    if (payload.kind === 'screen') {
      return await pushScreen({
        target,
        payload,
        policy,
        targetId,
        exists,
        base,
      });
    }
    return await pushTicker({
      target,
      payload,
      policy,
      targetId,
      exists,
      base,
    });
  } catch (e) {
    const message =
      e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
    return { ...base, message };
  }
}

async function pushOverlay(input: {
  source: SavedDisplay;
  target: SavedDisplay;
  payload: Extract<CatalogPayload, { kind: 'overlay' }>;
  policy: ConflictPolicy;
  targetId: string;
  exists: boolean;
  newLabel?: string;
  base: TransferResult;
}): Promise<TransferResult> {
  const { source, target, payload, policy, targetId, exists, newLabel, base } = input;
  let configJson = payload.config_json;
  if (source.id !== target.id) {
    configJson = await remapOverlayBlobKeys(source, target, configJson);
  }
  const label =
    policy === 'new_id' && newLabel?.trim()
      ? newLabel.trim()
      : payload.label;
  const body = {
    id: targetId,
    label,
    overlay_type: payload.overlay_type,
    config_json: configJson,
  };

  if (policy === 'overwrite' && exists) {
    await apiFetch(target, catalogItemPath('overlay', targetId), {
      method: 'PATCH',
      body: JSON.stringify(body),
    });
    return resultWithStatus(base, 'updated');
  }

  await apiFetch(target, catalogListPath('overlay'), {
    method: 'POST',
    body: JSON.stringify(body),
  });
  return resultWithStatus(base, exists ? 'updated' : 'created');
}

async function pushScreen(input: {
  target: SavedDisplay;
  payload: Extract<CatalogPayload, { kind: 'screen' }>;
  policy: ConflictPolicy;
  targetId: string;
  exists: boolean;
  base: TransferResult;
}): Promise<TransferResult> {
  const { target, payload, policy, targetId, exists, base } = input;
  const patchBody = {
    label: payload.label,
    description: payload.description,
    min_dwell_seconds: payload.min_dwell_seconds,
    max_dwell_seconds: payload.max_dwell_seconds,
    frequency_weight: payload.frequency_weight,
    min_gap_between_shows_seconds: payload.min_gap_between_shows_seconds,
    min_placements_per_program: payload.min_placements_per_program,
    max_placements_per_program: payload.max_placements_per_program,
    config_json: payload.config_json,
  };

  if (policy === 'overwrite' && exists) {
    await apiFetch(target, catalogItemPath('screen', targetId), {
      method: 'PATCH',
      body: JSON.stringify(patchBody),
    });
    return resultWithStatus(base, 'updated');
  }

  const postBody = {
    id: targetId,
    screen_type: payload.screen_type,
    label: payload.label || undefined,
    description: payload.description,
    min_dwell_seconds: payload.min_dwell_seconds,
    max_dwell_seconds: payload.max_dwell_seconds,
    frequency_weight: payload.frequency_weight,
    min_gap_between_shows_seconds: payload.min_gap_between_shows_seconds,
    min_placements_per_program: payload.min_placements_per_program,
    max_placements_per_program: payload.max_placements_per_program,
    data_key: payload.data_key || undefined,
    config_json: payload.config_json,
  };

  await apiFetch(target, catalogListPath('screen'), {
    method: 'POST',
    body: JSON.stringify(postBody),
  });
  return resultWithStatus(base, 'created');
}

async function pushTicker(input: {
  target: SavedDisplay;
  payload: Extract<CatalogPayload, { kind: 'ticker' }>;
  policy: ConflictPolicy;
  targetId: string;
  exists: boolean;
  base: TransferResult;
}): Promise<TransferResult> {
  const { target, payload, policy, targetId, exists, base } = input;
  const patchBody = {
    label: payload.label || undefined,
    description: payload.description,
    frequency_weight: payload.frequency_weight,
    sort_order: payload.sort_order,
    config_json: payload.config_json,
  };

  if (policy === 'overwrite' && exists) {
    await apiFetch(target, catalogItemPath('ticker', targetId), {
      method: 'PATCH',
      body: JSON.stringify(patchBody),
    });
    return resultWithStatus(base, 'updated');
  }

  const postBody = {
    id: targetId,
    ticker_type: payload.ticker_type,
    label: payload.label || undefined,
    description: payload.description,
    frequency_weight: payload.frequency_weight,
    sort_order: payload.sort_order,
    config_json: payload.config_json,
  };

  await apiFetch(target, catalogListPath('ticker'), {
    method: 'POST',
    body: JSON.stringify(postBody),
  });
  return resultWithStatus(base, 'created');
}

function resultWithStatus(
  base: TransferResult,
  status: TransferResultStatus,
): TransferResult {
  return { ...base, status, message: undefined };
}
