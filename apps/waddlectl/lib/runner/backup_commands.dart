import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../backup_archive_codec.dart';
import '../backup_fs_sync.dart';
import '../backup_manifest.dart';
import '../backup_schedule.dart';
import '../backup_sqlite_checkpoint.dart';
import '../global_options.dart';
import '../version.dart';
import 'emit.dart';

Future<bool> confirmDestructiveRestore({
  required WaddleBackupManifest manifest,
  required bool yesFlag,
  bool? stdinHasTerminalForTest,
  Iterator<String>? interactiveLinesForTest,
}) async {
  if (yesFlag) {
    return true;
  }
  final hasTerminal = stdinHasTerminalForTest ?? stdin.hasTerminal;
  if (!hasTerminal) {
    throw StateError(
      'Refusing destructive restore without a TTY. Pass --yes to confirm.',
    );
  }
  stdout.writeln('WARNING: This will overwrite existing local data from the backup:');
  if (manifest.includeDatabase) {
    stdout.writeln('  - SQLite database file');
  }
  if (manifest.includeBlobs) {
    stdout.writeln('  - media/ blob directory next to the database');
  }
  stdout.writeln();
  stdout.writeln('Type the word yes (lowercase) to continue:');
  final line = _readConfirmLine(interactiveLinesForTest);
  stdout.writeln();
  return line.trim() == 'yes';
}

String _readConfirmLine(Iterator<String>? testIt) {
  if (testIt != null) {
    if (!testIt.moveNext()) {
      throw StateError('confirm prompt iterator exhausted.');
    }
    return testIt.current;
  }
  return stdin.readLineSync(encoding: utf8) ?? '';
}

void _validateArchiveMatchesManifest(
  Archive archive,
  WaddleBackupManifest m,
  void Function(String message) fail,
) {
  if (m.includeDatabase) {
    if (archive.find(m.dbArchivePath) == null) {
      fail(
        'Backup is inconsistent: manifest includes database but '
        '"${m.dbArchivePath}" is missing from the archive.',
      );
    }
  }
  if (m.includeSecrets) {
    if (archive.find(kBackupSecretsBundlePath) == null) {
      fail(
        'Backup is inconsistent: manifest includes secrets but '
        '"$kBackupSecretsBundlePath" is missing from the archive.',
      );
    }
  }
}

class BackupCommand extends Command<void> {
  BackupCommand(this.globalOptions) {
    addSubcommand(_BackupCreate(globalOptions));
    addSubcommand(_BackupRestore(globalOptions));
    addSubcommand(_BackupSchedule(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'backup';

  @override
  String get description => 'Create, restore, or schedule full backups (SQLite + media).';
}

class _BackupCreate extends Command<void> {
  _BackupCreate(this.globalOptions) {
    argParser
      ..addOption(
        'format',
        allowed: ['zip', 'tgz'],
        defaultsTo: 'zip',
        help: 'Archive container: zip or tgz (.tar.gz).',
      )
      ..addOption(
        'output',
        help:
            'Write path: a .zip / .tar.gz file, or a directory (timestamped name is chosen). '
            'Defaults to the current working directory.',
      )
      ..addFlag(
        'include-database',
        defaultsTo: true,
        help: 'Include the SQLite database file (after WAL checkpoint).',
      )
      ..addFlag(
        'include-blobs',
        defaultsTo: true,
        help: 'Include the media/ directory next to the database.',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'create';

  @override
  String get description => 'Write a timestamped backup archive.';

  @override
  Future<void> run() async {
    final rawFormat = argResults!['format'] as String?;
    late final WaddleBackupArchiveFormat format;
    switch (rawFormat) {
      case 'zip':
        format = WaddleBackupArchiveFormat.zip;
        break;
      case 'tgz':
        format = WaddleBackupArchiveFormat.tgz;
        break;
      default:
        usageException('Invalid --format (expected zip|tgz): $rawFormat');
    }
    final includeDatabase = argResults!['include-database'] as bool;
    final includeBlobs = argResults!['include-blobs'] as bool;

    if (!includeDatabase && !includeBlobs) {
      usageException(
        'Nothing to backup: enable at least one of --include-database, --include-blobs.',
      );
    }

    if (includeDatabase && !await globalOptions.databaseFile.exists()) {
      usageException('Database file not found: ${globalOptions.databaseFile.path}');
    }

    final createdAt = DateTime.now().toUtc();
    final ts = compactTimestampUtc(createdAt);
    final outFile = resolveBackupOutputPath(
      outputArg: argResults!['output'] as String?,
      format: format,
      timestampUtcCompact: ts,
    );
    await outFile.parent.create(recursive: true);

    Uint8List? sqliteBytes;
    if (includeDatabase) {
      await walCheckpointFull(globalOptions.databaseFile);
      sqliteBytes = await globalOptions.databaseFile.readAsBytes();
    }

    final mediaRoot = mediaDirectoryNextToSqlite(globalOptions.databaseFile);
    final mediaMap = includeBlobs ? await readMediaTreeForArchive(mediaRoot) : <String, Uint8List>{};
    final includeEmptyMediaDir = includeBlobs && mediaMap.isEmpty;

    final manifest = WaddleBackupManifest(
      includeDatabase: includeDatabase,
      includeBlobs: includeBlobs,
      includeSecrets: false,
      waddlectlVersion: kWaddlectlPackageVersion,
      createdAtUtcIso: createdAt.toIso8601String(),
      sqliteBasename: p.basename(globalOptions.databaseFile.path),
    );

    final archive = buildWaddleBackupArchive(
      manifest: manifest,
      sqliteBytes: sqliteBytes,
      secretBundleBytes: null,
      mediaRelativePosixPaths: mediaMap,
      includeEmptyMediaDirectory: includeEmptyMediaDir,
    );
    final encoded = encodeArchive(archive, format);
    await outFile.writeAsBytes(encoded, flush: true);

    CliEmit(globalOptions).emitJsonOrText({
      'file': outFile.path,
      'format': format == WaddleBackupArchiveFormat.zip ? 'zip' : 'tgz',
      'include_database': includeDatabase,
      'include_blobs': includeBlobs,
      'include_secrets': false,
      'bytes': encoded.length,
    });
    if (!globalOptions.outputJson) {
      stdout.writeln('Wrote backup (${encoded.length} bytes) to ${outFile.path}.');
    }
  }
}

class _BackupRestore extends Command<void> {
  _BackupRestore(this.globalOptions) {
    argParser
      ..addOption('file', help: 'Path to a .zip or .tar.gz backup produced by backup create.')
      ..addFlag(
        'yes',
        help: 'Skip the interactive destructive-restore confirmation.',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'restore';

  @override
  String get description => 'Restore database / media from a backup archive.';

  @override
  Future<void> run() async {
    final path = argResults!['file'] as String?;
    if (path == null || path.isEmpty) {
      usageException('Usage: waddlectl backup restore --file=PATH [--yes] ...');
    }
    final yes = argResults!['yes'] as bool;
    final backupFile = File(path);
    if (!await backupFile.exists()) {
      usageException('Backup file not found: $path');
    }

    final bytes = Uint8List.fromList(await backupFile.readAsBytes());
    final archive = decodeWaddleBackupBytes(bytes);
    final manifest = readManifestFromArchive(archive);
    _validateArchiveMatchesManifest(archive, manifest, usageException);

    try {
      if (!await confirmDestructiveRestore(
        manifest: manifest,
        yesFlag: yes,
      )) {
        stdout.writeln('Aborted.');
        return;
      }
    } on StateError catch (e) {
      usageException(e.message);
    }

    final staging = Directory.systemTemp.createTempSync('waddle_restore_');
    try {
      await extractArchiveToDirectory(archive, staging);

      if (manifest.includeDatabase) {
        final srcDb = File(p.join(staging.path, manifest.dbArchivePath));
        if (!await srcDb.exists()) {
          usageException('Missing database file in archive: ${manifest.dbArchivePath}');
        }
        final dst = globalOptions.databaseFile;
        await dst.parent.create(recursive: true);
        await deleteSqliteSidecarsIfPresent(dst);
        await srcDb.copy(dst.path);
        await deleteSqliteSidecarsIfPresent(dst);
      }

      if (manifest.includeBlobs) {
        final srcMedia = Directory(p.join(staging.path, 'media'));
        final dstMedia = mediaDirectoryNextToSqlite(globalOptions.databaseFile);
        if (await dstMedia.exists()) {
          await dstMedia.delete(recursive: true);
        }
        if (await srcMedia.exists()) {
          await copyDirectoryContents(srcMedia, dstMedia);
        } else {
          await dstMedia.create(recursive: true);
        }
      }

      if (manifest.includeSecrets) {
        stderr.writeln(
          'Warning: backup manifest lists encrypted secrets; secret bundles '
          'are no longer restored. Database/media (if present) were restored.',
        );
      }

      CliEmit(globalOptions).emitJsonOrText({
        'restored_from': backupFile.path,
        'include_database': manifest.includeDatabase,
        'include_blobs': manifest.includeBlobs,
        'include_secrets': manifest.includeSecrets,
      });
      if (!globalOptions.outputJson) {
        stdout.writeln('Restore completed from ${backupFile.path}.');
      }
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

class _BackupSchedule extends Command<void> {
  _BackupSchedule(this.globalOptions) {
    argParser
      ..addOption(
        'cron',
        defaultsTo: '0 2 * * *',
        help: 'Cron schedule (five fields). Used in the printed crontab line.',
      )
      ..addOption(
        'format',
        allowed: ['zip', 'tgz'],
        defaultsTo: 'zip',
        help: 'Same as backup create --format.',
      )
      ..addOption(
        'output',
        help: 'Same as backup create --output (directory recommended for cron).',
      )
      ..addFlag('include-database', defaultsTo: true)
      ..addFlag('include-blobs', defaultsTo: true)
      ..addOption(
        'lock-file',
        help:
            'Optional path for flock(1) (Linux). When set, the printed cron line wraps the backup with flock -n.',
      )
      ..addOption(
        'waddlectl-prefix',
        help:
            'Override the printed waddlectl invocation (default: dart run waddlectl from repo, or resolved executable).',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'schedule';

  @override
  String get description => 'Print example cron and systemd user timer snippets (does not install them).';

  @override
  Future<void> run() async {
    final rawFormat = argResults!['format'] as String?;
    late final WaddleBackupArchiveFormat format;
    switch (rawFormat) {
      case 'zip':
        format = WaddleBackupArchiveFormat.zip;
        break;
      case 'tgz':
        format = WaddleBackupArchiveFormat.tgz;
        break;
      default:
        usageException('Invalid --format (expected zip|tgz): $rawFormat');
    }
    final includeDatabase = argResults!['include-database'] as bool;
    final includeBlobs = argResults!['include-blobs'] as bool;
    final cron = (argResults!['cron'] as String?) ?? '0 2 * * *';
    final output = argResults!['output'] as String?;
    final lockFile = (argResults!['lock-file'] as String?) ?? '';

    final dbFlag = '--database=${shellSingleQuote(globalOptions.databaseFile.path)}';
    final prefixOverride = argResults!['waddlectl-prefix'] as String?;
    final wPrefix = (prefixOverride != null && prefixOverride.isNotEmpty)
        ? prefixOverride.trim()
        : _defaultWaddlectlInvocation();

    final createArgs = backupCreateArgLine(
      format: format,
      output: output,
      includeDatabase: includeDatabase,
      includeBlobs: includeBlobs,
    );
    final inner = '$wPrefix $dbFlag $createArgs';
    final cronBody = wrapWithFlock(lockFile, inner);
    final cronLine = '$cron $cronBody';

    final onCal = systemdOnCalendarFromCronOrNull(cron);

    stdout.writeln('# Example: add ONE of the blocks below to your system.');
    stdout.writeln();
    stdout.writeln('# --- crontab line (crontab -e) ---');
    stdout.writeln(cronLine);
    stdout.writeln();
    stdout.writeln('# --- systemd user units (~/.config/systemd/user/) ---');
    stdout.writeln('# waddle-backup.service');
    stdout.writeln('[Unit]');
    stdout.writeln('Description=Waddle View backup');
    stdout.writeln();
    stdout.writeln('[Service]');
    stdout.writeln('Type=oneshot');
    stdout.writeln('ExecStart=/bin/sh -c ${shellSingleQuote(inner)}');
    stdout.writeln();
    stdout.writeln('# waddle-backup.timer');
    stdout.writeln('[Unit]');
    stdout.writeln('Description=Waddle View backup timer');
    stdout.writeln();
    stdout.writeln('[Timer]');
    if (onCal != null) {
      stdout.writeln('OnCalendar=$onCal');
    } else {
      stdout.writeln(
        '# Set OnCalendar= from your cron expression (could not derive automatically from ${shellSingleQuote(cron)}).',
      );
      stdout.writeln('# Example: OnCalendar=*-*-* 02:00:00');
    }
    stdout.writeln('Persistent=true');
    stdout.writeln();
    stdout.writeln('[Install]');
    stdout.writeln('WantedBy=timers.target');
  }

  String _defaultWaddlectlInvocation() {
    final exe = Platform.resolvedExecutable;
    final base = p.basename(exe).toLowerCase();
    if (base == 'dart.exe' ||
        base == 'dart' ||
        base == 'flutter_tester.exe' ||
        base == 'flutter_tester') {
      return 'dart run waddlectl';
    }
    return shellSingleQuote(exe);
  }
}
