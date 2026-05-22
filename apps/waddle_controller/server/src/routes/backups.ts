import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import { requireAuth, requireAdmin } from '../middleware/guards.js';
import { fetchLatestWaddleViewRelease } from '../services/githubReleases.js';
import {
  deleteBackupTarget,
  findBackupTarget,
  listBackupTargets,
  upsertBackupTarget,
} from '../services/backupTargets.js';
import {
  deleteSnapshot,
  findSnapshot,
  insertSnapshot,
  listAllBackupSnapshots,
  listSnapshotsForTarget,
  pruneSnapshotsForTarget,
  readSnapshotBytes,
} from '../services/backupSnapshots.js';
import type { BackupScheduleFields } from '../services/backupSchedule.js';
import { pullBackupFromDisplay, restoreSnapshotToDisplay } from '../services/displayBackupPull.js';
import type { PublicUser } from '../types.js';

function userIdForRequest(c: {
  get: (k: 'config' | 'user') => unknown;
}): string | null {
  const config = c.get('config') as AppVariables['config'];
  if (!config.authEnabled) {
    return null;
  }
  const user = c.get('user') as PublicUser | null;
  return user?.id ?? null;
}

function requireUserWhenAuth(c: {
  get: (k: 'config' | 'user') => unknown;
}): PublicUser | null | Response {
  const config = c.get('config') as AppVariables['config'];
  if (!config.authEnabled) {
    return null;
  }
  const user = c.get('user') as PublicUser | null;
  if (!user) {
    return Response.json({ error: 'Unauthorized', code: 'unauthorized' }, { status: 401 });
  }
  return user;
}

export function backupsRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.get('/releases/waddle-view', async (c) => {
    try {
      const release = await fetchLatestWaddleViewRelease();
      return c.json(release);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return c.json({ error: msg, code: 'github_error' }, 502);
    }
  });

  const protectedRoutes = new Hono<{ Variables: AppVariables }>();
  protectedRoutes.use('*', async (c, next) => {
    if (c.get('config').authEnabled) {
      return requireAuth(c, next);
    }
    await next();
  });

  protectedRoutes.get('/backup-targets', (c) => {
    const uid = userIdForRequest(c);
    if (c.get('config').authEnabled && uid == null) {
      return c.json({ error: 'Unauthorized', code: 'unauthorized' }, 401);
    }
    return c.json({ targets: listBackupTargets(c.get('db'), uid) });
  });

  protectedRoutes.put('/backup-targets', async (c) => {
    const user = requireUserWhenAuth(c);
    if (user instanceof Response) return user;
    const body = (await c.req.json<{
      displayId?: string;
      label?: string;
      baseUrl?: string;
      apiKey?: string;
      schedule?: Partial<BackupScheduleFields>;
      timezone?: string;
      retentionCount?: number;
      enabled?: boolean;
    }>().catch(() => ({}))) as {
      displayId?: string;
      label?: string;
      baseUrl?: string;
      apiKey?: string;
      schedule?: Partial<BackupScheduleFields>;
      timezone?: string;
      retentionCount?: number;
      enabled?: boolean;
    };
    const displayId = body.displayId?.trim() ?? '';
    const baseUrl = body.baseUrl?.trim() ?? '';
    const apiKey = body.apiKey?.trim() ?? '';
    const label = body.label?.trim() || displayId;
    if (!displayId || !baseUrl || !apiKey) {
      return c.json({ error: 'displayId, baseUrl, and apiKey are required', code: 'invalid_request' }, 400);
    }
    const target = upsertBackupTarget(c.get('config'), c.get('db'), {
      userId: user?.id ?? null,
      displayId,
      label,
      baseUrl,
      apiKey,
      schedule: body.schedule,
      timezone: body.timezone?.trim() || 'UTC',
      retentionCount: body.retentionCount ?? 3,
      enabled: body.enabled !== false,
    });
    return c.json({ target });
  });

  protectedRoutes.get('/backup-snapshots', (c) => {
    const uid = userIdForRequest(c);
    if (c.get('config').authEnabled && uid == null) {
      return c.json({ error: 'Unauthorized', code: 'unauthorized' }, 401);
    }
    return c.json({ snapshots: listAllBackupSnapshots(c.get('db'), uid) });
  });

  protectedRoutes.delete('/backup-targets/:id', (c) => {
    const uid = userIdForRequest(c);
    if (c.get('config').authEnabled && uid == null) {
      return c.json({ error: 'Unauthorized', code: 'unauthorized' }, 401);
    }
    const ok = deleteBackupTarget(c.get('db'), c.req.param('id'), uid);
    if (!ok) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    return c.json({ ok: true });
  });

  protectedRoutes.get('/backup-targets/:id/snapshots', (c) => {
    const uid = userIdForRequest(c);
    const target = findBackupTarget(c.get('db'), c.req.param('id'), uid);
    if (!target) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    return c.json({
      snapshots: listSnapshotsForTarget(c.get('db'), target.id, target.label),
    });
  });

  protectedRoutes.post('/backup-targets/:id/pull-now', async (c) => {
    const uid = userIdForRequest(c);
    const target = findBackupTarget(c.get('db'), c.req.param('id'), uid);
    if (!target) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    try {
      const result = await pullBackupFromDisplay(c.get('config'), c.get('db'), target, 'manual');
      return c.json(result);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return c.json({ error: msg, code: 'pull_failed' }, 502);
    }
  });

  protectedRoutes.get('/backup-snapshots/:id/download', (c) => {
    const uid = userIdForRequest(c);
    const snap = findSnapshot(c.get('db'), c.req.param('id'));
    if (!snap) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    const target = findBackupTarget(c.get('db'), snap.target_id, uid);
    if (!target) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    const bytes = readSnapshotBytes(snap);
    return new Response(bytes, {
      headers: {
        'Content-Type': 'application/zip',
        'Content-Disposition': `attachment; filename="${snap.file_name}"`,
        'Content-Length': String(bytes.length),
      },
    });
  });

  protectedRoutes.delete('/backup-snapshots/:id', (c) => {
    const uid = userIdForRequest(c);
    const snap = findSnapshot(c.get('db'), c.req.param('id'));
    if (!snap) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    const target = findBackupTarget(c.get('db'), snap.target_id, uid);
    if (!target) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    deleteSnapshot(c.get('db'), snap.id);
    return c.json({ ok: true });
  });

  const adminRestore = new Hono<{ Variables: AppVariables }>();
  adminRestore.use('*', async (c, next) => {
    if (c.get('config').authEnabled) {
      return requireAdmin(c, next);
    }
    await next();
  });

  adminRestore.post('/backup-snapshots/:id/restore', async (c) => {
    const uid = userIdForRequest(c);
    const snap = findSnapshot(c.get('db'), c.req.param('id'));
    if (!snap) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    const target = findBackupTarget(c.get('db'), snap.target_id, uid);
    if (!target) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    try {
      await restoreSnapshotToDisplay(c.get('config'), c.get('db'), snap.id, target);
      return c.json({ restored: true, restart_required: true });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return c.json({ error: msg, code: 'restore_failed' }, 502);
    }
  });

  adminRestore.post('/backup-targets/:id/upload', async (c) => {
    const uid = userIdForRequest(c);
    const target = findBackupTarget(c.get('db'), c.req.param('id'), uid);
    if (!target) {
      return c.json({ error: 'Not found', code: 'not_found' }, 404);
    }
    const buf = Buffer.from(await c.req.arrayBuffer());
    if (buf.length === 0) {
      return c.json({ error: 'Empty body', code: 'invalid_request' }, 400);
    }
    const snap = insertSnapshot(c.get('db'), c.get('config'), {
      targetId: target.id,
      displayId: target.display_id,
      bytes: buf,
      fileName: `upload_${Date.now()}.zip`,
      source: 'upload',
    });
    pruneSnapshotsForTarget(c.get('db'), target.id, target.retention_count);
    return c.json({ snapshot: { ...snap, displayLabel: target.label } });
  });

  app.route('/', protectedRoutes);
  app.route('/', adminRestore);

  return app;
}
