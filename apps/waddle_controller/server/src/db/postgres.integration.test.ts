import { afterEach, describe, expect, it } from 'vitest';
import { createPostgresPool, PostgresDbClient } from './postgresClient.js';
import { runMigrationsAsync } from './migrate.js';
import { createUser } from '../services/users.js';

const testUrl = process.env.WADDLE_CONTROLLER_TEST_DATABASE_URL?.trim();

describe.skipIf(!testUrl)('postgres integration', () => {
  let client: PostgresDbClient | undefined;

  afterEach(async () => {
    if (client) {
      await client.exec(
        'TRUNCATE TABLE backup_snapshots, backup_targets, user_displays, sessions, users, settings, schema_migrations RESTART IDENTITY CASCADE',
      );
      await client.close();
      client = undefined;
    }
  });

  it('runs migrations and supports basic CRUD', async () => {
    client = new PostgresDbClient(createPostgresPool(testUrl!));
    await runMigrationsAsync(client);

    const user = await createUser(client, {
      username: 'pgtest',
      password: 'passwordpassword1',
      role: 'admin',
    });
    expect(user.username).toBe('pgtest');
  });
});
