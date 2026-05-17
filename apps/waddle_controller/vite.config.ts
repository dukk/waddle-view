/// <reference types="vitest/config" />
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import basicSsl from '@vitejs/plugin-basic-ssl';

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const appVersion = (
  JSON.parse(readFileSync(path.join(rootDir, 'package.json'), 'utf8')) as { version: string }
).version;
const tlsDisabled = process.env.WADDLE_CONTROLLER_TLS === '0';
const devScheme = tlsDisabled ? 'http' : 'https';

export default defineConfig({
  define: {
    __APP_VERSION__: JSON.stringify(appVersion),
  },
  plugins: tlsDisabled ? [react()] : [react(), basicSsl()],
  resolve: {
    alias: { '@': path.resolve(rootDir, 'src') },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    include: ['src/**/*.test.{ts,tsx}', 'server/src/**/*.test.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'json-summary'],
      reportsDirectory: './coverage',
      include: ['src/**/*.{ts,tsx}', 'server/src/**/*.ts'],
      exclude: [
        'server/src/index.ts',
        'server/src/testHelpers.ts',
        'src/main.tsx',
        'src/vite-env.d.ts',
        'src/App.tsx',
        'src/theme.ts',
        'src/pages/**',
        'src/layout/**',
        'src/components/**',
        'src/context/**',
        'src/util/curatorCategoryMaterialIcon.tsx',
        'src/icons/**',
        '**/*.test.{ts,tsx}',
      ],
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/bff': {
        target: `${devScheme}://127.0.0.1:5199`,
        changeOrigin: true,
        secure: false,
      },
    },
  },
});
