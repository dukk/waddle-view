import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'backup_archive_codec.dart';
import 'backup_fs_sync.dart';
import 'backup_manifest.dart';
import 'backup_sqlite_checkpoint.dart';

export 'backup_archive_codec.dart';
export 'backup_fs_sync.dart';
export 'backup_manifest.dart';
export 'backup_schedule.dart';
export 'backup_sqlite_checkpoint.dart';

/// Options for [WaddleBackupService.createArchive].
class WaddleBackupCreateOptions {
  const WaddleBackupCreateOptions({
    this.includeDatabase = true,
    this.includeBlobs = true,
    this.format = WaddleBackupArchiveFormat.zip,
    required this.creatorVersion,
    this.createdAt,
  });

  final bool includeDatabase;
  final bool includeBlobs;
  final WaddleBackupArchiveFormat format;
  final String creatorVersion;
  final DateTime? createdAt;
}

/// Result of [WaddleBackupService.createArchive].
class WaddleBackupCreateResult {
  const WaddleBackupCreateResult({
    required this.bytes,
    required this.manifest,
    required this.format,
  });

  final Uint8List bytes;
  final WaddleBackupManifest manifest;
  final WaddleBackupArchiveFormat format;
}

/// Creates and restores Waddle backup archives (SQLite + `media/`).
class WaddleBackupService {
  WaddleBackupService({required this.databaseFile});

  final File databaseFile;

  void validateCreateOptions(WaddleBackupCreateOptions options) {
    if (!options.includeDatabase && !options.includeBlobs) {
      throw ArgumentError(
        'Nothing to backup: enable at least one of includeDatabase, includeBlobs.',
      );
    }
  }

  Future<WaddleBackupCreateResult> createArchive(
    WaddleBackupCreateOptions options,
  ) async {
    validateCreateOptions(options);
    if (options.includeDatabase && !await databaseFile.exists()) {
      throw StateError('Database file not found: ${databaseFile.path}');
    }

    final createdAt = (options.createdAt ?? DateTime.now()).toUtc();
    Uint8List? sqliteBytes;
    if (options.includeDatabase) {
      await walCheckpointFull(databaseFile);
      sqliteBytes = await databaseFile.readAsBytes();
    }

    final mediaRoot = mediaDirectoryNextToSqlite(databaseFile);
    final mediaMap = options.includeBlobs
        ? await readMediaTreeForArchive(mediaRoot)
        : <String, Uint8List>{};
    final includeEmptyMediaDir = options.includeBlobs && mediaMap.isEmpty;

    final manifest = WaddleBackupManifest(
      includeDatabase: options.includeDatabase,
      includeBlobs: options.includeBlobs,
      includeSecrets: false,
      creatorVersion: options.creatorVersion,
      createdAtUtcIso: createdAt.toIso8601String(),
      sqliteBasename: p.basename(databaseFile.path),
    );

    final archive = buildWaddleBackupArchive(
      manifest: manifest,
      sqliteBytes: sqliteBytes,
      secretBundleBytes: null,
      mediaRelativePosixPaths: mediaMap,
      includeEmptyMediaDirectory: includeEmptyMediaDir,
    );
    final encoded = encodeArchive(archive, options.format);
    return WaddleBackupCreateResult(
      bytes: encoded,
      manifest: manifest,
      format: options.format,
    );
  }

  static void validateArchiveMatchesManifest(
    Archive archive,
    WaddleBackupManifest manifest,
  ) {
    if (manifest.includeDatabase) {
      if (archive.find(manifest.dbArchivePath) == null) {
        throw FormatException(
          'Backup is inconsistent: manifest includes database but '
          '"${manifest.dbArchivePath}" is missing from the archive.',
        );
      }
    }
    if (manifest.includeSecrets) {
      if (archive.find(kBackupSecretsBundlePath) == null) {
        throw FormatException(
          'Backup is inconsistent: manifest includes secrets but '
          '"$kBackupSecretsBundlePath" is missing from the archive.',
        );
      }
    }
  }

  /// Restores database and/or media from [archiveBytes]. Requires [confirmYes] when non-interactive.
  Future<WaddleBackupRestoreResult> restoreArchive(
    Uint8List archiveBytes, {
    required bool confirmYes,
  }) async {
    final archive = decodeWaddleBackupBytes(archiveBytes);
    final manifest = readManifestFromArchive(archive);
    validateArchiveMatchesManifest(archive, manifest);

    final staging = Directory.systemTemp.createTempSync('waddle_restore_');
    try {
      await extractArchiveToDirectory(archive, staging);

      if (manifest.includeDatabase) {
        final srcDb = File(p.join(staging.path, manifest.dbArchivePath));
        if (!await srcDb.exists()) {
          throw FormatException(
            'Missing database file in archive: ${manifest.dbArchivePath}',
          );
        }
        await databaseFile.parent.create(recursive: true);
        await deleteSqliteSidecarsIfPresent(databaseFile);
        await srcDb.copy(databaseFile.path);
        await deleteSqliteSidecarsIfPresent(databaseFile);
      }

      if (manifest.includeBlobs) {
        final srcMedia = Directory(p.join(staging.path, 'media'));
        final dstMedia = mediaDirectoryNextToSqlite(databaseFile);
        if (await dstMedia.exists()) {
          await dstMedia.delete(recursive: true);
        }
        if (await srcMedia.exists()) {
          await copyDirectoryContents(srcMedia, dstMedia);
        } else {
          await dstMedia.create(recursive: true);
        }
      }

      return WaddleBackupRestoreResult(
        manifest: manifest,
        secretsBundleIgnored: manifest.includeSecrets,
      );
    } finally {
      try {
        if (staging.existsSync()) {
          staging.deleteSync(recursive: true);
        }
      } on Object {
        // best-effort
      }
    }
  }
}

/// Outcome of [WaddleBackupService.restoreArchive].
class WaddleBackupRestoreResult {
  const WaddleBackupRestoreResult({
    required this.manifest,
    required this.secretsBundleIgnored,
  });

  final WaddleBackupManifest manifest;
  final bool secretsBundleIgnored;
}
