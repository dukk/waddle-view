#!/usr/bin/env node
/**
 * Parses coverage/lcov.info and enforces a line hit ratio on controller logic
 * under src/auth, src/api, src/storage, src/util (*.ts), and src/constants.
 *
 * UI shells (pages, layout, components, context, App.tsx, main.tsx) are out of
 * scope for the CI floor — cover them with component tests over time.
 *
 * Usage: node tool/coverage_check.mjs [--min=80] [--target=90] [lcovPath]
 */
import { readFileSync } from 'node:fs';

function includeSourceFile(sf) {
  const norm = sf.replaceAll('\\', '/');
  const idx = norm.indexOf('src/');
  if (idx < 0) return false;
  const rel = norm.slice(idx);

  if (rel.endsWith('.test.ts') || rel.endsWith('.test.tsx')) return false;
  if (rel === 'src/main.tsx' || rel === 'src/vite-env.d.ts' || rel === 'src/App.tsx') {
    return false;
  }
  if (rel === 'src/theme.ts' || rel === 'src/util/curatorCategoryMaterialIcon.tsx') {
    return false;
  }
  if (
    rel.startsWith('src/pages/') ||
    rel.startsWith('src/layout/') ||
    rel.startsWith('src/components/') ||
    rel.startsWith('src/context/')
  ) {
    return false;
  }

  if (rel.startsWith('src/auth/')) return true;
  if (rel.startsWith('src/api/')) return true;
  if (rel.startsWith('src/storage/')) return true;
  if (rel.startsWith('src/constants/')) return true;
  if (rel.startsWith('src/util/') && rel.endsWith('.ts')) return true;
  const serverIdx = norm.indexOf('server/src/');
  if (serverIdx >= 0) {
    const serverRel = norm.slice(serverIdx);
    if (serverRel.endsWith('.test.ts')) return false;
    if (serverRel === 'server/src/index.ts') return false;
    if (serverRel.startsWith('server/src/')) return true;
  }
  return false;
}

function parseArgs(argv) {
  let minPct = 80;
  let targetPct = 90;
  let lcovPath = 'coverage/lcov.info';
  for (const a of argv) {
    if (a.startsWith('--min=')) minPct = Number(a.split('=').pop());
    else if (a.startsWith('--target=')) targetPct = Number(a.split('=').pop());
    else if (!a.startsWith('--')) lcovPath = a;
  }
  return { minPct, targetPct, lcovPath };
}

const { minPct, targetPct, lcovPath } = parseArgs(process.argv.slice(2));
const raw = readFileSync(lcovPath, 'utf8');
const records = raw.split('end_of_record');

let totalLf = 0;
let totalLh = 0;

for (const block of records) {
  if (!block.trim()) continue;
  let sf;
  let lf = 0;
  let lh = 0;
  for (const line of block.split('\n')) {
    if (line.startsWith('SF:')) sf = line.slice(3).trim();
    else if (line.startsWith('LF:')) lf = Number(line.slice(3).trim());
    else if (line.startsWith('LH:')) lh = Number(line.slice(3).trim());
  }
  if (sf && includeSourceFile(sf)) {
    totalLf += lf;
    totalLh += lh;
  }
}

if (totalLf === 0) {
  console.error(
    'No LF entries for gated controller paths (auth, api, storage, util/*.ts, constants).',
  );
  process.exit(1);
}

const pct = (100 * totalLh) / totalLf;
const rounded = Math.round(pct * 10) / 10;
console.log(`Controller logic coverage: ${totalLh}/${totalLf} lines (${rounded}%)`);

if (pct < minPct) {
  console.error(`FAIL: coverage ${rounded}% is below CI floor ${minPct}%`);
  process.exit(1);
}

if (pct < targetPct) {
  console.warn(`WARN: coverage ${rounded}% is below aspirational target ${targetPct}%`);
}

process.exit(0);
