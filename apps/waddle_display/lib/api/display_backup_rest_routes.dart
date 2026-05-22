import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_backup/waddle_backup_service.dart';

import 'display_backup_job_manager.dart';

const _jsonHeaders = {'content-type': 'application/json'};

void registerDisplayBackupRestRoutes(
  Router r, {
  required File databaseFile,
  required Directory supportDirectory,
  required Future<void> Function() onAfterRestore,
}) {
  final jobsDir = Directory(p.join(supportDirectory.path, 'backups', 'jobs'));
  jobsDir.createSync(recursive: true);
  final manager = DisplayBackupJobManager(
    databaseFile: databaseFile,
    jobsDir: jobsDir,
  );
  final service = WaddleBackupService(databaseFile: databaseFile);

  r.get('/v1/display/backup/status', (Request req) async {
    final last = manager.lastJob();
    return Response.ok(
      jsonEncode({
        'database_path': databaseFile.path,
        'jobs_directory': jobsDir.path,
        'last_job': last == null ? null : _jobJson(last),
      }),
      headers: _jsonHeaders,
    );
  });

  r.post('/v1/display/backup/jobs', (Request req) async {
    final qp = req.url.queryParameters;
    final format = _parseFormat(qp['format']);
    final includeDatabase = qp['include_database'] != '0' && qp['include_database'] != 'false';
    final includeBlobs = qp['include_blobs'] != '0' && qp['include_blobs'] != 'false';
    try {
      service.validateCreateOptions(
        WaddleBackupCreateOptions(
          includeDatabase: includeDatabase,
          includeBlobs: includeBlobs,
          format: format,
          creatorVersion: 'waddle_display',
        ),
      );
    } on ArgumentError catch (e) {
      return Response(
        400,
        body: jsonEncode({'error': e.message}),
        headers: _jsonHeaders,
      );
    }
    final id = manager.startJob(
      format: format,
      includeDatabase: includeDatabase,
      includeBlobs: includeBlobs,
    );
    return Response(
      202,
      body: jsonEncode({'job_id': id, 'status': 'pending'}),
      headers: _jsonHeaders,
    );
  });

  r.get('/v1/display/backup/jobs/<id>', (Request req, String id) async {
    final job = manager.job(id);
    if (job == null) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: _jsonHeaders,
      );
    }
    return Response.ok(
      jsonEncode(_jobJson(job)),
      headers: _jsonHeaders,
    );
  });

  r.get('/v1/display/backup/jobs/<id>/download', (Request req, String id) async {
    final job = manager.job(id);
    if (job == null) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: _jsonHeaders,
      );
    }
    if (job.status != DisplayBackupJobStatus.ready) {
      return Response(
        409,
        body: jsonEncode({'error': 'job_not_ready', 'status': job.status.name}),
        headers: _jsonHeaders,
      );
    }
    final path = job.archivePath;
    if (path == null || !File(path).existsSync()) {
      return Response(
        404,
        body: '{"error":"archive_missing"}',
        headers: _jsonHeaders,
      );
    }
    final ext = job.format == WaddleBackupArchiveFormat.zip ? '.zip' : '.tar.gz';
    final mime = job.format == WaddleBackupArchiveFormat.zip
        ? 'application/zip'
        : 'application/gzip';
    final bytes = await File(path).readAsBytes();
    return Response.ok(
      bytes,
      headers: {
        'content-type': mime,
        'content-disposition': 'attachment; filename="waddle_backup_$id$ext"',
        'content-length': bytes.length.toString(),
      },
    );
  });

  r.delete('/v1/display/backup/jobs/<id>', (Request req, String id) async {
    if (manager.job(id) == null) {
      return Response(
        404,
        body: '{"error":"not_found"}',
        headers: _jsonHeaders,
      );
    }
    await manager.deleteJob(id);
    return Response.ok('{}', headers: _jsonHeaders);
  });

  r.post('/v1/display/backup/restore', (Request req) async {
    final confirm = req.url.queryParameters['confirm']?.trim().toLowerCase();
    if (confirm != 'yes') {
      return Response(
        400,
        body: '{"error":"confirm_required","hint":"Add ?confirm=yes"}',
        headers: _jsonHeaders,
      );
    }
    final body = await req.read().expand((e) => e).toList();
    if (body.isEmpty) {
      return Response(
        400,
        body: '{"error":"empty_body"}',
        headers: _jsonHeaders,
      );
    }
    try {
      final restored = await service.restoreArchive(
        Uint8List.fromList(body),
        confirmYes: true,
      );
      await onAfterRestore();
      return Response.ok(
        jsonEncode({
          'restored': true,
          'include_database': restored.manifest.includeDatabase,
          'include_blobs': restored.manifest.includeBlobs,
          'secrets_bundle_ignored': restored.secretsBundleIgnored,
          'restart_required': true,
        }),
        headers: _jsonHeaders,
      );
    } on FormatException catch (e) {
      return Response(
        400,
        body: jsonEncode({'error': e.message}),
        headers: _jsonHeaders,
      );
    } on Object catch (e) {
      return Response(
        500,
        body: jsonEncode({'error': e.toString()}),
        headers: _jsonHeaders,
      );
    }
  });
}

WaddleBackupArchiveFormat _parseFormat(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'tgz':
    case 'tar.gz':
      return WaddleBackupArchiveFormat.tgz;
    case 'zip':
    case null:
    case '':
      return WaddleBackupArchiveFormat.zip;
    default:
      return WaddleBackupArchiveFormat.zip;
  }
}

Map<String, Object?> _jobJson(DisplayBackupJobRecord job) => {
  'id': job.id,
  'status': job.status.name,
  'format': job.format == WaddleBackupArchiveFormat.zip ? 'zip' : 'tgz',
  'created_at_utc': job.createdAtUtc.toIso8601String(),
  if (job.completedAtUtc != null)
    'completed_at_utc': job.completedAtUtc!.toIso8601String(),
  if (job.byteSize != null) 'byte_size': job.byteSize,
  if (job.error != null) 'error': job.error,
  if (job.manifestSummary != null) 'manifest': job.manifestSummary,
};
