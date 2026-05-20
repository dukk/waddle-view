/**
 * Rebuild better-sqlite3 / @node-rs/argon2 when NODE_MODULE_VERSION mismatches
 * process.versions.modules (common when Cursor Vitest uses a different Node than npm ci).
 */
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const controllerRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);

const NATIVE_PACKAGES = ['better-sqlite3', '@node-rs/argon2'];

function probeNativeModules() {
  const require = createRequire(import.meta.url);
  const mismatches = [];
  for (const pkg of NATIVE_PACKAGES) {
    try {
      require(pkg);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.includes('NODE_MODULE_VERSION')) {
        mismatches.push({ pkg, err: e });
      } else {
        throw e;
      }
    }
  }
  return mismatches;
}

export function rebuildNativeModules() {
  const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  const result = spawnSync(npm, ['rebuild', ...NATIVE_PACKAGES], {
    cwd: controllerRoot,
    stdio: 'inherit',
    shell: process.platform === 'win32',
    env: process.env,
  });
  if (result.status !== 0) {
    throw new Error(
      `npm rebuild ${NATIVE_PACKAGES.join(' ')} failed (exit ${result.status ?? 'unknown'}). ` +
        'Stop npm run dev, then run: cd apps/waddle_controller && npm rebuild better-sqlite3 @node-rs/argon2',
    );
  }
}

/** Rebuild native addons for the current Node binary when ABI does not match. */
export function ensureNativeModules() {
  const mismatches = probeNativeModules();
  if (mismatches.length === 0) {
    return;
  }
  console.warn(
    `[waddle_controller] Rebuilding native modules for Node ${process.version} ` +
      `(NODE_MODULE_VERSION ${process.versions.modules})…`,
  );
  rebuildNativeModules();
  const remaining = probeNativeModules();
  if (remaining.length > 0) {
    throw remaining[0].err;
  }
}

const isMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (isMain) {
  ensureNativeModules();
}
