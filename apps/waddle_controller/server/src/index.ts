import type { Server } from 'node:http';
import { loadConfig } from './config.js';
import { openDatabase } from './db/database.js';
import { createApp } from './app.js';
import { serveWithOptionalTls } from './tlsServe.js';
import {
  startBackupScheduler,
  stopBackupScheduler,
} from './services/backupScheduler.js';

const config = loadConfig();
const db = openDatabase(config);
const app = createApp(config, db);
startBackupScheduler(config, db);

const scheme = config.tls.enabled ? 'https' : 'http';

const server: Server = serveWithOptionalTls({
  fetch: app.fetch,
  hostname: config.bindHost,
  port: config.port,
  tls: config.tls,
  config,
  db,
  onListening: () => {
    console.error(
      `waddle_controller BFF listening on ${scheme}://${config.bindHost}:${config.port} ` +
        `(auth=${config.authEnabled}, tls=${config.tls.enabled})`,
    );
  },
});

let shuttingDown = false;

function shutdown(signal: string): void {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;
  console.error(`waddle_controller BFF shutting down (${signal})…`);
  stopBackupScheduler();
  server.close((err) => {
    try {
      db.close();
    } catch {
      // ignore close races during tsx watch restart
    }
    if (err) {
      console.error(err);
      process.exit(1);
    }
    process.exit(0);
  });
}

process.once('SIGINT', () => shutdown('SIGINT'));
process.once('SIGTERM', () => shutdown('SIGTERM'));
