import fs from 'node:fs';
import { describe, expect, it, afterEach } from 'vitest';
import { createTestApp } from '../testHelpers.js';
import { upsertBackupTarget } from './backupTargets.js';
import {
  backupsRootDir,
  deleteSnapshot,
  findSnapshot,
  insertSnapshot,
  listAllBackupSnapshots,
  listSnapshotsForTarget,
  pruneSnapshotsForTarget,
  readSnapshotBytes,
  snapshotDirForDisplay,
} from './backupSnapshots.js';

describe('backupSnapshots', () => {
  let cleanup: (() => void | Promise<void>) | undefined;

  afterEach(async () => {
    await cleanup?.();
    cleanup = undefined;
  });

  it('inserts, lists, reads, prunes, and deletes snapshots', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const target = await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_snap',
      label: 'Snap display',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'snap-key',
      timezone: 'UTC',
      retentionCount: 2,
      enabled: true,
    });

    const zip = Buffer.from([0x50, 0x4b, 0x03, 0x04]);
    const snap1 = await insertSnapshot(t.db, t.config, {
      targetId: target.id,
      displayId: target.displayId,
      bytes: zip,
      fileName: 'first.zip',
      source: 'manual',
      manifest: { schema: 48 },
    });
    expect(snap1.byteSize).toBe(zip.length);
    expect(snap1.manifest).toEqual({ schema: 48 });

    const snap2 = await insertSnapshot(t.db, t.config, {
      targetId: target.id,
      displayId: target.displayId,
      bytes: zip,
      fileName: 'second.zip',
      source: 'upload',
    });

    expect(await listSnapshotsForTarget(t.db, target.id, target.label)).toHaveLength(2);
    expect(await listAllBackupSnapshots(t.db, null)).toHaveLength(2);
    expect((await listAllBackupSnapshots(t.db, null))[0]!.displayLabel).toBe('Snap display');

    const row = (await findSnapshot(t.db, snap1.id))!;
    expect(readSnapshotBytes(row).equals(zip)).toBe(true);
    expect(fs.existsSync(row.file_path)).toBe(true);
    expect(snapshotDirForDisplay(t.config, target.displayId)).toContain(
      backupsRootDir(t.config),
    );

    await pruneSnapshotsForTarget(t.db, target.id, 1);
    expect(await listSnapshotsForTarget(t.db, target.id)).toHaveLength(1);
    expect(await findSnapshot(t.db, snap1.id)).toBeNull();
    expect(await findSnapshot(t.db, snap2.id)).not.toBeNull();

    expect(await deleteSnapshot(t.db, snap2.id)).toBe(true);
    expect(await deleteSnapshot(t.db, snap2.id)).toBe(false);
    expect(await listSnapshotsForTarget(t.db, target.id)).toHaveLength(0);
  });

  it('parses invalid manifest_json as null in list output', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const target = await upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_bad_manifest',
      label: 'Bad manifest',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'key',
      timezone: 'UTC',
      retentionCount: 3,
      enabled: true,
    });

    const snap = await insertSnapshot(t.db, t.config, {
      targetId: target.id,
      displayId: target.displayId,
      bytes: Buffer.from('x'),
      fileName: 'x.zip',
      source: 'manual',
    });
    await t.db.run('UPDATE backup_snapshots SET manifest_json = ? WHERE id = ?', [
      '{not-json',
      snap.id,
    ]);

    const listed = await listSnapshotsForTarget(t.db, target.id);
    expect(listed[0]!.manifest).toBeNull();
  });
});
