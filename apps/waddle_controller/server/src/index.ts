import { serve } from '@hono/node-server';
import { loadConfig } from './config.js';
import { openDatabase } from './db/database.js';
import { createApp } from './app.js';

const config = loadConfig();
const db = openDatabase(config);
const app = createApp(config, db);

console.error(
  `waddle_controller BFF listening on ${config.bindHost}:${config.port} (auth=${config.authEnabled})`,
);

serve({ fetch: app.fetch, hostname: config.bindHost, port: config.port });
