#!/usr/bin/env node
/**
 * Writes server/src/generated/aboutManifest.json for GET /bff/v1/about.
 * Run before build:server (see package.json).
 */
import { existsSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(toolDir, '..');
const outDir = path.join(appRoot, 'server', 'src', 'generated');
const outFile = path.join(outDir, 'aboutManifest.json');

/** Monorepo root in dev/CI; Docker sets WADDLE_VIEW_REPO_ROOT to a copied LICENSE tree. */
function resolveRepoRoot() {
  const envRoot = process.env.WADDLE_VIEW_REPO_ROOT?.trim();
  if (envRoot) {
    const licensePath = path.join(envRoot, 'LICENSE');
    if (existsSync(licensePath)) return envRoot;
  }
  const monorepoRoot = path.resolve(appRoot, '../..');
  const monorepoLicense = path.join(monorepoRoot, 'LICENSE');
  if (existsSync(monorepoLicense)) return monorepoRoot;
  throw new Error(
    'LICENSE not found for about manifest generation. ' +
      'Set WADDLE_VIEW_REPO_ROOT to a directory containing LICENSE (container builds), ' +
      'or run from the waddle-view monorepo checkout.',
  );
}

const repoRoot = resolveRepoRoot();

const pkg = JSON.parse(readFileSync(path.join(appRoot, 'package.json'), 'utf8'));
const lock = JSON.parse(readFileSync(path.join(appRoot, 'package-lock.json'), 'utf8'));

const licenseText = readFileSync(path.join(repoRoot, 'LICENSE'), 'utf8');
const productLicenseSummary = licenseText
  .split(/\n(?=\d+\. )/)[0]
  .trim()
  .slice(0, 1200);

const productLicense = {
  id: 'ONC',
  name: 'Open Non-Commercial License (ONC) v1.0',
  url: 'https://github.com/dukk/waddle-view/blob/main/LICENSE',
  summary: productLicenseSummary,
};

function packageNameFromKey(key) {
  if (!key || key === '') return null;
  const idx = key.lastIndexOf('node_modules/');
  if (idx < 0) return null;
  return key.slice(idx + 'node_modules/'.length);
}

function resolveDepPath(parentKey, depName) {
  const base = parentKey ? parentKey : '';
  const candidate = base ? `${base}/node_modules/${depName}` : `node_modules/${depName}`;
  if (lock.packages[candidate]) return candidate;
  const parts = base.split('/node_modules/');
  for (let i = parts.length - 1; i >= 0; i--) {
    const prefix = parts.slice(0, i + 1).join('/node_modules/');
    const alt = prefix ? `${prefix}/node_modules/${depName}` : `node_modules/${depName}`;
    if (lock.packages[alt]) return alt;
  }
  return candidate;
}

function collectProductionDependencies() {
  const root = lock.packages[''];
  if (!root?.dependencies) return [];
  const seen = new Set();
  const rows = [];

  function visit(pkgKey) {
    if (seen.has(pkgKey)) return;
    seen.add(pkgKey);
    const entry = lock.packages[pkgKey];
    if (!entry || entry.dev) return;
    const name = packageNameFromKey(pkgKey);
    if (name && pkgKey !== '') {
      rows.push({
        name,
        version: entry.version ?? '',
        license: typeof entry.license === 'string' ? entry.license : undefined,
      });
    }
    if (entry.dependencies) {
      for (const dep of Object.keys(entry.dependencies)) {
        visit(resolveDepPath(pkgKey, dep));
      }
    }
  }

  for (const dep of Object.keys(root.dependencies)) {
    visit(resolveDepPath('', dep));
  }

  rows.sort((a, b) => a.name.localeCompare(b.name));
  return rows;
}

function buildThirdPartyNotices(deps) {
  const lines = [];
  for (const d of deps) {
    if (!d.license) continue;
    const lic = d.license.trim();
    if (/^(MIT|Apache-2\.0|BSD-2-Clause|BSD-3-Clause|ISC)$/i.test(lic)) {
      lines.push(`${d.name}@${d.version} — ${lic}`);
    }
  }
  return lines.length > 0 ? `${lines.join('\n')}\n` : '';
}

const dependencies = collectProductionDependencies();
const build =
  process.env.WADDLE_CONTROLLER_BUILD_NUMBER?.trim() || 'dev';

const manifest = {
  app: 'waddle_controller',
  version: pkg.version ?? '0.0.0',
  build,
  productLicense,
  dependencies,
  thirdPartyNotices: buildThirdPartyNotices(dependencies),
};

mkdirSync(outDir, { recursive: true });
writeFileSync(outFile, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(`Wrote ${outFile} (${dependencies.length} dependencies, build=${build})`);
