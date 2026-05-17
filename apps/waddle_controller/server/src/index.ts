import { loadConfig } from './config.js';
import { openDatabase } from './db/database.js';
import { createApp } from './app.js';
import { serveWithOptionalTls } from './tlsServe.js';

const config = loadConfig();
const db = openDatabase(config);
const app = createApp(config, db);

const scheme = config.tls.enabled ? 'https' : 'http';
console.error(
  `waddle_controller BFF listening on ${scheme}://${config.bindHost}:${config.port} (auth=${config.authEnabled}, tls=${config.tls.enabled})`,
);

serveWithOptionalTls({
  fetch: app.fetch,
  hostname: config.bindHost,
  port: config.port,
  tls: config.tls,
});
