/**
 * Ensures @waddle/node-tls runtime deps exist (selfsigned). postinstall runs npm ci
 * there, but tsx watch / partial deletes can leave an empty node_modules tree.
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const controllerRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);
const tlsRoot = path.resolve(controllerRoot, '../../packages/waddle_node_tls');
const selfsignedEntry = path.join(tlsRoot, 'node_modules', 'selfsigned', 'package.json');

function depsPresent() {
  try {
    return fs.existsSync(selfsignedEntry);
  } catch {
    return false;
  }
}

if (depsPresent()) {
  process.exit(0);
}

console.warn(
  '[waddle_controller] @waddle/node-tls dependencies missing; running npm ci in packages/waddle_node_tls…',
);

const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const result = spawnSync(npm, ['ci'], {
  cwd: tlsRoot,
  stdio: 'inherit',
  shell: process.platform === 'win32',
  env: process.env,
});

if (result.status !== 0 || !depsPresent()) {
  console.error(
    '[waddle_controller] Failed to install @waddle/node-tls dependencies.\n' +
      'Run manually: cd packages/waddle_node_tls && npm ci\n' +
      'Then restart: cd apps/waddle_controller && npm run dev',
  );
  process.exit(result.status === 0 ? 1 : (result.status ?? 1));
}
