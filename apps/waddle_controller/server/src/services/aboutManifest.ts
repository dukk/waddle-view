import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export type ProductLicenseInfo = {
  id: string;
  name: string;
  url: string;
  summary: string;
};

export type DependencyInfo = {
  name: string;
  version: string;
  license?: string;
};

export type AboutManifest = {
  app: string;
  version: string;
  build: string;
  productLicense: ProductLicenseInfo;
  dependencies: DependencyInfo[];
  thirdPartyNotices: string;
};

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const manifestPath = path.join(appRoot, 'server', 'src', 'generated', 'aboutManifest.json');
const repoRoot = path.resolve(appRoot, '..', '..');

function readProductLicenseFallback(): ProductLicenseInfo {
  const licensePath = path.join(repoRoot, 'LICENSE');
  let summary = 'Open Non-Commercial License (ONC) v1.0';
  if (existsSync(licensePath)) {
    const text = readFileSync(licensePath, 'utf8');
    summary = text.split(/\n(?=\d+\. )/)[0]?.trim().slice(0, 1200) ?? summary;
  }
  return {
    id: 'ONC',
    name: 'Open Non-Commercial License (ONC) v1.0',
    url: 'https://github.com/dukk/waddle-view/blob/main/LICENSE',
    summary,
  };
}

function devFallbackManifest(): AboutManifest {
  const pkgPath = path.join(appRoot, 'package.json');
  let version = '0.0.0';
  if (existsSync(pkgPath)) {
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf8')) as { version?: string };
    version = pkg.version ?? version;
  }
  return {
    app: 'waddle_controller',
    version,
    build: 'dev',
    productLicense: readProductLicenseFallback(),
    dependencies: [],
    thirdPartyNotices: '',
  };
}

let cached: AboutManifest | null = null;

export function loadAboutManifest(): AboutManifest {
  if (cached) return cached;
  if (existsSync(manifestPath)) {
    cached = JSON.parse(readFileSync(manifestPath, 'utf8')) as AboutManifest;
    return cached;
  }
  cached = devFallbackManifest();
  return cached;
}

/** Test-only: reset in-memory cache. */
export function resetAboutManifestCacheForTests(): void {
  cached = null;
}
