import { describe, expect, it, vi, afterEach } from 'vitest';
import { createTestApp } from '../testHelpers.js';
import { upsertBackupTarget, findBackupTarget } from './backupTargets.js';
import { findSnapshot, listSnapshotsForTarget } from './backupSnapshots.js';
import { pullBackupFromDisplay, restoreSnapshotToDisplay } from './displayBackupPull.js';
import * as insecureFetch from './insecureFetch.js';

describe('displayBackupPull', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    vi.restoreAllMocks();
    cleanup?.();
    cleanup = undefined;
  });

  it('pullBackupFromDisplay stores snapshot and marks target ok', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const publicTarget = upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_pull',
      label: 'Pull',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'pull-key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });
    const target = findBackupTarget(t.db, publicTarget.id, null)!;

    const zip = Buffer.from([0x50, 0x4b, 0x05, 0x06]);
    const fetchMock = vi.spyOn(insecureFetch, 'insecureNodeFetch').mockImplementation(
      async (url: string | URL) => {
        const path = String(url);
        if (path.endsWith('/v1/display/backup/jobs') && !path.includes('/jobs/')) {
          return new Response(JSON.stringify({ job_id: 'job-abc' }), { status: 202 });
        }
        if (path.endsWith('/jobs/job-abc') && !path.endsWith('/download')) {
          return new Response(JSON.stringify({ status: 'ready', manifest: { v: 1 } }), {
            status: 200,
          });
        }
        if (path.endsWith('/jobs/job-abc/download')) {
          return new Response(zip, { status: 200 });
        }
        return new Response('not found', { status: 404 });
      },
    );

    vi.useFakeTimers();
    const pending = pullBackupFromDisplay(t.config, t.db, target, 'manual');
    await vi.advanceTimersByTimeAsync(600);
    const result = await pending;
    vi.useRealTimers();

    expect(result.byteSize).toBe(zip.length);
    expect(fetchMock).toHaveBeenCalled();
    const snaps = listSnapshotsForTarget(t.db, target.id);
    expect(snaps).toHaveLength(1);
    expect(snaps[0]!.source).toBe('manual');

    const row = findBackupTarget(t.db, target.id, null)!;
    expect(row.last_status).toBe('ok');
    expect(row.last_error).toBeNull();
  });

  it('pullBackupFromDisplay rejects missing job_id', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const publicTarget = upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_nojob',
      label: 'No job',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });
    const target = findBackupTarget(t.db, publicTarget.id, null)!;

    vi.spyOn(insecureFetch, 'insecureNodeFetch').mockResolvedValue(
      new Response('{}', { status: 202 }),
    );

    await expect(pullBackupFromDisplay(t.config, t.db, target, 'manual')).rejects.toThrow(
      /missing job_id/,
    );
  });

  it('pullBackupFromDisplay records error when job start fails', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const publicTarget = upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_fail',
      label: 'Fail',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'fail-key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });
    const target = findBackupTarget(t.db, publicTarget.id, null)!;

    vi.spyOn(insecureFetch, 'insecureNodeFetch').mockResolvedValue(
      new Response('denied', { status: 403 }),
    );

    await expect(pullBackupFromDisplay(t.config, t.db, target, 'scheduled')).rejects.toThrow(
      /Backup job start failed/,
    );
  });

  it('pullBackupFromDisplay fails when poll reports failed status', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const publicTarget = upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_poll_fail',
      label: 'Poll fail',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });
    const target = findBackupTarget(t.db, publicTarget.id, null)!;

    vi.spyOn(insecureFetch, 'insecureNodeFetch').mockImplementation(async (url: string | URL) => {
      const path = String(url);
      if (path.endsWith('/v1/display/backup/jobs') && !path.includes('/jobs/')) {
        return new Response(JSON.stringify({ job_id: 'job-fail' }), { status: 202 });
      }
      return new Response(JSON.stringify({ status: 'failed', error: 'disk full' }), {
        status: 200,
      });
    });

    vi.useFakeTimers();
    const pending = pullBackupFromDisplay(t.config, t.db, target, 'manual');
    const rejection = expect(pending).rejects.toThrow('disk full');
    await vi.advanceTimersByTimeAsync(600);
    await rejection;
    vi.useRealTimers();
  });

  it('restoreSnapshotToDisplay rejects snapshot for wrong target', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const publicTarget = upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_wrong_snap',
      label: 'Wrong snap',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });
    const target = findBackupTarget(t.db, publicTarget.id, null)!;

    await expect(
      restoreSnapshotToDisplay(t.config, t.db, 'nonexistent-snapshot', target),
    ).rejects.toThrow(/Snapshot not found/);
  });

  it('restoreSnapshotToDisplay posts zip bytes to display', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const publicTarget = upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_restore',
      label: 'Restore',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'restore-key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });
    const target = findBackupTarget(t.db, publicTarget.id, null)!;

    const { insertSnapshot } = await import('./backupSnapshots.js');
    const snap = insertSnapshot(t.db, t.config, {
      targetId: target.id,
      displayId: target.display_id,
      bytes: Buffer.from([0x50, 0x4b]),
      fileName: 'restore.zip',
      source: 'upload',
    });

    const fetchMock = vi.spyOn(insecureFetch, 'insecureNodeFetch').mockResolvedValue(
      new Response('{}', { status: 200 }),
    );

    await restoreSnapshotToDisplay(t.config, t.db, snap.id, target);

    expect(fetchMock).toHaveBeenCalledWith(
      'https://127.0.0.1:8787/v1/display/backup/restore?confirm=yes',
      expect.objectContaining({ method: 'POST' }),
    );
    const row = findSnapshot(t.db, snap.id);
    expect(row).not.toBeNull();
  });
});
