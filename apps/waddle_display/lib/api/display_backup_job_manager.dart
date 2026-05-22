import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:waddle_backup/waddle_backup_service.dart';
import 'package:waddle_display/api/display_about.dart';

/// Status of an async display backup job.
enum DisplayBackupJobStatus { pending, running, ready, failed }

/// In-memory + on-disk backup job tracked for REST polling.
class DisplayBackupJobRecord {
  DisplayBackupJobRecord({
    required this.id,
    required this.status,
    required this.format,
    required this.createdAtUtc,
    this.completedAtUtc,
    this.byteSize,
    this.error,
    this.manifestSummary,
    this.archivePath,
  });

  final String id;
  DisplayBackupJobStatus status;
  final WaddleBackupArchiveFormat format;
  final DateTime createdAtUtc;
  DateTime? completedAtUtc;
  int? byteSize;
  String? error;
  Map<String, Object?>? manifestSummary;
  String? archivePath;
}

/// Runs backup archives asynchronously and stores results under [jobsDir].
class DisplayBackupJobManager {
  DisplayBackupJobManager({
    required this.databaseFile,
    required Directory jobsDir,
  }) : _service = WaddleBackupService(databaseFile: databaseFile) {
    jobsDir.createSync(recursive: true);
    _jobsDir = jobsDir;
  }

  final File databaseFile;
  final WaddleBackupService _service;
  late final Directory _jobsDir;
  final Map<String, DisplayBackupJobRecord> _jobs = {};
  final Random _rnd = Random.secure();

  DisplayBackupJobRecord? job(String id) => _jobs[id];

  DisplayBackupJobRecord? lastJob() {
    if (_jobs.isEmpty) return null;
    final list = _jobs.values.toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return list.first;
  }

  String startJob({
    WaddleBackupArchiveFormat format = WaddleBackupArchiveFormat.zip,
    bool includeDatabase = true,
    bool includeBlobs = true,
  }) {
    final id = _newId();
    final record = DisplayBackupJobRecord(
      id: id,
      status: DisplayBackupJobStatus.pending,
      format: format,
      createdAtUtc: DateTime.now().toUtc(),
    );
    _jobs[id] = record;
    unawaited(_runJob(
      record,
      format: format,
      includeDatabase: includeDatabase,
      includeBlobs: includeBlobs,
    ));
    return id;
  }

  Future<void> _runJob(
    DisplayBackupJobRecord record, {
    required WaddleBackupArchiveFormat format,
    required bool includeDatabase,
    required bool includeBlobs,
  }) async {
    record.status = DisplayBackupJobStatus.running;
    try {
      _service.validateCreateOptions(
        WaddleBackupCreateOptions(
          includeDatabase: includeDatabase,
          includeBlobs: includeBlobs,
          format: format,
          creatorVersion: kWaddleDisplayAppVersion,
        ),
      );
      final result = await _service.createArchive(
        WaddleBackupCreateOptions(
          includeDatabase: includeDatabase,
          includeBlobs: includeBlobs,
          format: format,
          creatorVersion: kWaddleDisplayAppVersion,
        ),
      );
      final ext = format == WaddleBackupArchiveFormat.zip ? '.zip' : '.tar.gz';
      final out = File(p.join(_jobsDir.path, '${record.id}$ext'));
      await out.writeAsBytes(result.bytes, flush: true);
      record.archivePath = out.path;
      record.byteSize = result.bytes.length;
      record.manifestSummary = {
        'include_database': result.manifest.includeDatabase,
        'include_blobs': result.manifest.includeBlobs,
        'created_at_utc': result.manifest.createdAtUtcIso,
        'sqlite_basename': result.manifest.sqliteBasename,
      };
      record.status = DisplayBackupJobStatus.ready;
      record.completedAtUtc = DateTime.now().toUtc();
    } on Object catch (e) {
      record.status = DisplayBackupJobStatus.failed;
      record.error = e.toString();
      record.completedAtUtc = DateTime.now().toUtc();
    }
  }

  Future<void> deleteJob(String id) async {
    final job = _jobs.remove(id);
    if (job == null) return;
    final path = job.archivePath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
  }

  Future<Uint8List?> readArchiveBytes(String id) async {
    final job = _jobs[id];
    if (job == null || job.status != DisplayBackupJobStatus.ready) {
      return null;
    }
    final path = job.archivePath;
    if (path == null) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    return Uint8List.fromList(await f.readAsBytes());
  }

  String _newId() {
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final r = _rnd.nextInt(0xffffff).toRadixString(16).padLeft(6, '0');
    return 'bu_$ts$r';
  }
}
