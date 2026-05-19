import type { CatalogKind } from './types';

export function catalogListPath(kind: CatalogKind): string {
  switch (kind) {
    case 'screen':
      return '/v1/screens';
    case 'overlay':
      return '/v1/display/overlays';
    case 'ticker':
      return '/v1/ticker/tapes';
  }
}

export function catalogItemPath(kind: CatalogKind, id: string): string {
  const encoded = encodeURIComponent(id);
  switch (kind) {
    case 'screen':
      return `/v1/screens/${encoded}`;
    case 'overlay':
      return `/v1/display/overlays/${encoded}`;
    case 'ticker':
      return `/v1/ticker/tapes/${encoded}`;
  }
}
