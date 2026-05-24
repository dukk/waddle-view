import { describe, expect, it, vi, afterEach } from 'vitest';
import { createTestApp, sessionCookieHeader } from '../testHelpers.js';
import { setUserManagementEnabled } from '../services/settings.js';
import { upsertBackupTarget } from '../services/backupTargets.js';
import * as displayBackupPull from '../services/displayBackupPull.js';
import * as githubReleases from '../services/githubReleases.js';

describe('backups routes', () => {
  let cleanup: (() => void | Promise<void>) | undefined;

  afterEach(async () => {
    vi.restoreAllMocks();
    await cleanup?.();
    cleanup = undefined;
  });

  it('GET /releases/waddle-view returns release metadata', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    vi.spyOn(githubReleases, 'fetchLatestWaddleViewRelease').mockResolvedValue({
      tag_name: 'v1.0.0',
      name: 'v1.0.0',
      published_at: '2026-01-01T00:00:00Z',
      html_url: 'https://github.com/dukk/waddle-view/releases/tag/v1.0.0',
      body: '',
      pi_asset: null,
    });

    const res = await t.app.request('/bff/v1/releases/waddle-view');
    expect(res.status).toBe(200);
    const body = (await res.json()) as { tag_name: string };
    expect(body.tag_name).toBe('v1.0.0');
  });

  it('GET /releases/waddle-view maps github errors to 502', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    vi.spyOn(githubReleases, 'fetchLatestWaddleViewRelease').mockRejectedValue(
      new Error('rate limited'),
    );

    const res = await t.app.request('/bff/v1/releases/waddle-view');
    expect(res.status).toBe(502);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('github_error');
  });

  it('manages backup targets and snapshots when auth is disabled', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const put = await t.app.request('/bff/v1/backup-targets', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        displayId: 'd_route',
        label: 'Route display',
        baseUrl: 'https://127.0.0.1:8787',
        apiKey: 'route-key',
        timezone: 'UTC',
        retentionCount: 2,
        enabled: true,
      }),
    });
    expect(put.status).toBe(200);
    const putBody = (await put.json()) as { target: { id: string } };
    const targetId = putBody.target.id;

    const list = await t.app.request('/bff/v1/backup-targets');
    expect(list.status).toBe(200);
    const listBody = (await list.json()) as { targets: { id: string }[] };
    expect(listBody.targets).toHaveLength(1);

    const badPut = await t.app.request('/bff/v1/backup-targets', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayId: 'x' }),
    });
    expect(badPut.status).toBe(400);

    const emptyBody = await t.app.request(`/bff/v1/backup-targets/${targetId}/upload`, {
      method: 'POST',
      body: Buffer.alloc(0),
    });
    expect(emptyBody.status).toBe(400);

    const upload = await t.app.request(`/bff/v1/backup-targets/${targetId}/upload`, {
      method: 'POST',
      body: Buffer.from([0x50, 0x4b]),
    });
    expect(upload.status).toBe(200);
    const uploadBody = (await upload.json()) as { snapshot: { id: string } };
    const snapshotId = uploadBody.snapshot.id;

    const snaps = await t.app.request(`/bff/v1/backup-targets/${targetId}/snapshots`);
    expect(snaps.status).toBe(200);

    const allSnaps = await t.app.request('/bff/v1/backup-snapshots');
    expect(allSnaps.status).toBe(200);

    const download = await t.app.request(`/bff/v1/backup-snapshots/${snapshotId}/download`);
    expect(download.status).toBe(200);
    expect(download.headers.get('Content-Type')).toBe('application/zip');

    vi.spyOn(displayBackupPull, 'restoreSnapshotToDisplay').mockResolvedValue(undefined);
    const restore = await t.app.request(`/bff/v1/backup-snapshots/${snapshotId}/restore`, {
      method: 'POST',
    });
    expect(restore.status).toBe(200);

    const delSnap = await t.app.request(`/bff/v1/backup-snapshots/${snapshotId}`, {
      method: 'DELETE',
    });
    expect(delSnap.status).toBe(200);

    const delTarget = await t.app.request(`/bff/v1/backup-targets/${targetId}`, {
      method: 'DELETE',
    });
    expect(delTarget.status).toBe(200);
  });

  it('POST pull-now returns 502 when pull fails', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const target = await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_pull_fail',
      label: 'Pull fail',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });

    vi.spyOn(displayBackupPull, 'pullBackupFromDisplay').mockRejectedValue(
      new Error('display offline'),
    );

    const res = await t.app.request(`/bff/v1/backup-targets/${target.id}/pull-now`, {
      method: 'POST',
    });
    expect(res.status).toBe(502);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('pull_failed');
  });

  it('POST pull-now invokes displayBackupPull', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const target = await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_pull_route',
      label: 'Pull route',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'pull-key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });

    vi.spyOn(displayBackupPull, 'pullBackupFromDisplay').mockResolvedValue({
      snapshotId: 'snap-route',
      byteSize: 10,
    });

    const res = await t.app.request(`/bff/v1/backup-targets/${target.id}/pull-now`, {
      method: 'POST',
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { snapshotId: string };
    expect(body.snapshotId).toBe('snap-route');
  });

  it('PUT backup-targets requires session when auth is enabled', async () => {
    const t = createTestApp({ authEnabled: true });
    cleanup = t.cleanup;
    await setUserManagementEnabled(t.db, true);

    const res = await t.app.request('/bff/v1/backup-targets', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        displayId: 'd_auth',
        baseUrl: 'https://127.0.0.1:8787',
        apiKey: 'key',
      }),
    });
    expect([401, 409]).toContain(res.status);
  });

  it('returns 404 for unknown target and snapshot ids', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const missing = await t.app.request('/bff/v1/backup-targets/missing-id/snapshots');
    expect(missing.status).toBe(404);

    const snap = await t.app.request('/bff/v1/backup-snapshots/missing-snap/download');
    expect(snap.status).toBe(404);

    const emptyUpload = await t.app.request('/bff/v1/backup-targets/missing-id/upload', {
      method: 'POST',
      body: Buffer.alloc(0),
    });
    expect(emptyUpload.status).toBe(404);
  });

  it('authenticated admin can save backup targets', async () => {
    const t = createTestApp({ authEnabled: true });
    cleanup = t.cleanup;
    await setUserManagementEnabled(t.db, true);

    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'test-password1' }),
    });
    const cookie = sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);

    const put = await t.app.request('/bff/v1/backup-targets', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...(cookie ? { Cookie: cookie } : {}),
      },
      body: JSON.stringify({
        displayId: 'd_auth_ok',
        label: 'Auth OK',
        baseUrl: 'https://127.0.0.1:8787',
        apiKey: 'auth-key',
        timezone: 'UTC',
        retentionCount: 3,
        enabled: true,
      }),
    });
    expect(put.status).toBe(200);
  });
});
