import type { SavedDisplay } from '@/storage/displays';

export type CatalogKind = 'screen' | 'overlay' | 'ticker';

export type ConflictPolicy = 'skip' | 'overwrite' | 'new_id';

export type CatalogListItem = {
  id: string;
  label: string;
};

export type ScreenCatalogPayload = {
  kind: 'screen';
  id: string;
  screen_type: string;
  label: string;
  description: string;
  config_json: unknown;
  min_dwell_seconds: number;
  max_dwell_seconds: number;
  frequency_weight: number;
  min_gap_between_shows_seconds: number;
  min_placements_per_program: number;
  max_placements_per_program: number | null;
  data_key: string;
};

export type OverlayCatalogPayload = {
  kind: 'overlay';
  id: string;
  overlay_type: string;
  label: string;
  config_json: unknown;
};

export type TickerCatalogPayload = {
  kind: 'ticker';
  id: string;
  ticker_type: string;
  label: string;
  description: string;
  frequency_weight: number;
  sort_order: number;
  config_json: unknown;
};

export type CatalogPayload =
  | ScreenCatalogPayload
  | OverlayCatalogPayload
  | TickerCatalogPayload;

export type TransferResultStatus = 'created' | 'updated' | 'skipped' | 'failed';

export type TransferResult = {
  displayId: string;
  displayLabel: string;
  status: TransferResultStatus;
  message?: string;
};

export type TransferCatalogItemInput = {
  kind: CatalogKind;
  source: SavedDisplay;
  targets: SavedDisplay[];
  itemId: string;
  policy: ConflictPolicy;
  newId?: string;
  newLabel?: string;
};
