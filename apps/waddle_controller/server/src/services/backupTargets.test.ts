import { describe, expect, it, afterEach } from 'vitest';
import { createTestApp } from '../testHelpers.js';
import { createUser } from './users.js';
import {
  deleteBackupTarget,
  findBackupTarget,
  findBackupTargetByDisplayId,
  getDecryptedApiKey,
  listBackupTargets,
  listEnabledBackupTargets,
  rowScheduleFields,
  updateBackupTargetRunStatus,
  upsertBackupTarget,
} from './backupTargets.js';

describe('backupTargets', () => {
  let cleanup: (() => void | Promise<void>) | undefined;

  afterEach(async () => {
    await cleanup?.();
    cleanup = undefined;
  });

  it('upserts, lists, updates, and deletes targets when auth is disabled', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const created = await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_lab',
      label: 'Lab',
      baseUrl: 'https://127.0.0.1:8787/',
      apiKey: 'wk_test_key',
      timezone: 'UTC',
      retentionCount: 5,
      enabled: true,
    });
    expect(created.displayId).toBe('d_lab');
    expect(created.baseUrl).toBe('https://127.0.0.1:8787');
    expect(created.retentionCount).toBe(5);
    expect(created.enabled).toBe(true);

    const row = await findBackupTarget(t.db, created.id, null);
    expect(row).not.toBeNull();
    expect(getDecryptedApiKey(t.config, row!)).toBe('wk_test_key');
    expect(rowScheduleFields(row!).frequency).toBe('weekly');

    const updated = await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_lab',
      label: 'Lab renamed',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'wk_rotated',
      schedule: { frequency: 'daily', interval: 1, hour: 3, minute: 15 },
      timezone: 'America/New_York',
      retentionCount: 150,
      enabled: false,
    });
    expect(updated.id).toBe(created.id);
    expect(updated.label).toBe('Lab renamed');
    expect(updated.retentionCount).toBe(100);
    expect(updated.enabled).toBe(false);
    expect(updated.schedule.frequency).toBe('daily');
    expect(updated.schedule.minute).toBe(15);

    expect(await listBackupTargets(t.db, null)).toHaveLength(1);
    expect((await findBackupTargetByDisplayId(t.db, 'd_lab', null))?.id).toBe(created.id);
    expect(getDecryptedApiKey(t.config, (await findBackupTarget(t.db, created.id, null))!)).toBe(
      'wk_rotated',
    );

    await updateBackupTargetRunStatus(t.db, created.id, 'error', 'pull failed');
    const afterRun = (await findBackupTarget(t.db, created.id, null))!;
    expect(afterRun.last_status).toBe('error');
    expect(afterRun.last_error).toBe('pull failed');

    expect(await deleteBackupTarget(t.db, created.id, null)).toBe(true);
    expect(await deleteBackupTarget(t.db, created.id, null)).toBe(false);
    expect(await listBackupTargets(t.db, null)).toHaveLength(0);
  });

  it('scopes targets by user when auth is enabled', async () => {
    const t = createTestApp({ authEnabled: true });
    cleanup = t.cleanup;
    const user = await createUser(t.db, {
      username: 'backup-user',
      password: 'passwordpassword1',
      role: 'admin',
    });

    await upsertBackupTarget(t.config, t.db, {
      userId: user.id,
      displayId: 'd_user',
      label: 'User display',
      baseUrl: 'https://127.0.0.1:8788',
      apiKey: 'user-key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });

    const userTargets = await listBackupTargets(t.db, user.id);
    expect(userTargets).toHaveLength(1);
    expect(await listBackupTargets(t.db, null)).toHaveLength(0);
    expect(await findBackupTarget(t.db, userTargets[0]!.id, null)).toBeNull();
  });

  it('listEnabledBackupTargets returns only enabled rows', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_on',
      label: 'On',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'k1',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });
    await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_off',
      label: 'Off',
      baseUrl: 'https://127.0.0.1:8788',
      apiKey: 'k2',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: false,
    });

    const enabled = await listEnabledBackupTargets(t.db);
    expect(enabled).toHaveLength(1);
    expect(enabled[0]!.display_id).toBe('d_on');
  });

  it('staggers schedule times for new targets in the same scope', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const first = await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_a',
      label: 'A',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'k1',
      retentionCount: 3,
      enabled: true,
    });
    expect(first.schedule).toEqual({
      frequency: 'weekly',
      interval: 1,
      dayOfWeek: 0,
      hour: 2,
      minute: 0,
    });

    const second = await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_b',
      label: 'B',
      baseUrl: 'https://127.0.0.1:8788',
      apiKey: 'k2',
      retentionCount: 3,
      enabled: true,
    });
    expect(second.schedule.hour).toBe(2);
    expect(second.schedule.minute).toBe(5);
    expect(second.timezone).toBe(first.timezone);
  });
});
