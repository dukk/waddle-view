import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import type { AppDatabase } from '../db/database.js';
import type { AppConfig } from '../config.js';

export type BackupSnapshotRow = {
  id: string;
  target_id: string;
  display_id: string;
  file_path: string;
  file_name: string;
  byte_size: number;
  manifest_json: string | null;
  source: 'scheduled' | 'manual' | 'upload';
  created_at: string;
};

export type BackupSnapshotPublic = {
  id: string;
  targetId: string;
  displayId: string;
  displayLabel: string;
  fileName: string;
  byteSize: number;
  manifest: Record<string, unknown> | null;
  source: string;
  createdAt: string;
};

function toPublic(row: BackupSnapshotRow, displayLabel?: string): BackupSnapshotPublic {
  let manifest: Record<string, unknown> | null = null;
  if (row.manifest_json) {
    try {
      manifest = JSON.parse(row.manifest_json) as Record<string, unknown>;
    } catch {
      manifest = null;
    }
  }
  return {
    id: row.id,
    targetId: row.target_id,
    displayId: row.display_id,
    displayLabel: displayLabel ?? row.display_id,
    fileName: row.file_name,
    byteSize: row.byte_size,
    manifest,
    source: row.source,
    createdAt: row.created_at,
  };
}

export function backupsRootDir(config: Pick<AppConfig, 'dataDir'>): string {
  return path.join(config.dataDir, 'backups');
}

export function snapshotDirForDisplay(
  config: Pick<AppConfig, 'dataDir'>,
  displayId: string,
): string {
  const safe = displayId.replace(/[^a-zA-Z0-9._-]+/g, '_');
  return path.join(backupsRootDir(config), safe);
}

export function listSnapshotsForTarget(
  db: AppDatabase,
  targetId: string,
  displayLabel?: string,
): BackupSnapshotPublic[] {
  const rows = db
    .prepare(
      'SELECT * FROM backup_snapshots WHERE target_id = ? ORDER BY created_at DESC',
    )
    .all(targetId) as BackupSnapshotRow[];
  return rows.map((r) => toPublic(r, displayLabel));
}

export function listAllBackupSnapshots(
  db: AppDatabase,
  userId: string | null,
): BackupSnapshotPublic[] {
  const rows = userId
    ? (db
        .prepare(
          `SELECT s.*, t.label AS display_label
           FROM backup_snapshots s
           INNER JOIN backup_targets t ON s.target_id = t.id
           WHERE t.user_id = ?
           ORDER BY s.created_at DESC`,
        )
        .all(userId) as (BackupSnapshotRow & { display_label: string })[])
    : (db
        .prepare(
          `SELECT s.*, t.label AS display_label
           FROM backup_snapshots s
           INNER JOIN backup_targets t ON s.target_id = t.id
           WHERE t.user_id IS NULL
           ORDER BY s.created_at DESC`,
        )
        .all() as (BackupSnapshotRow & { display_label: string })[]);
  return rows.map((r) => toPublic(r, r.display_label));
}

export function findSnapshot(
  db: AppDatabase,
  id: string,
): BackupSnapshotRow | null {
  const row = db.prepare('SELECT * FROM backup_snapshots WHERE id = ?').get(id) as
    | BackupSnapshotRow
    | undefined;
  return row ?? null;
}

export function insertSnapshot(
  db: AppDatabase,
  config: Pick<AppConfig, 'dataDir'>,
  input: {
    targetId: string;
    displayId: string;
    bytes: Buffer;
    fileName: string;
    source: 'scheduled' | 'manual' | 'upload';
    manifest?: Record<string, unknown> | null;
  },
): BackupSnapshotPublic {
  const id = randomUUID();
  const dir = snapshotDirForDisplay(config, input.displayId);
  fs.mkdirSync(dir, { recursive: true });
  const filePath = path.join(dir, `${id}_${input.fileName}`);
  fs.writeFileSync(filePath, input.bytes);
  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO backup_snapshots (
      id, target_id, display_id, file_path, file_name, byte_size, manifest_json, source, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    input.targetId,
    input.displayId,
    filePath,
    input.fileName,
    input.bytes.length,
    input.manifest ? JSON.stringify(input.manifest) : null,
    input.source,
    now,
  );
  return toPublic(findSnapshot(db, id)!);
}

export function deleteSnapshot(db: AppDatabase, id: string): boolean {
  const row = findSnapshot(db, id);
  if (!row) return false;
  try {
    if (fs.existsSync(row.file_path)) {
      fs.unlinkSync(row.file_path);
    }
  } catch {
    // best-effort
  }
  db.prepare('DELETE FROM backup_snapshots WHERE id = ?').run(id);
  return true;
}

export function pruneSnapshotsForTarget(
  db: AppDatabase,
  targetId: string,
  retentionCount: number,
): void {
  const rows = db
    .prepare(
      'SELECT id FROM backup_snapshots WHERE target_id = ? ORDER BY created_at DESC',
    )
    .all(targetId) as { id: string }[];
  for (const row of rows.slice(retentionCount)) {
    deleteSnapshot(db, row.id);
  }
}

export function readSnapshotBytes(row: BackupSnapshotRow): Buffer {
  return fs.readFileSync(row.file_path);
}
