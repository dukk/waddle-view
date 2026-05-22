import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_backup/waddle_backup_service.dart';

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

    final service = WaddleBackupService(databaseFile: globalOptions.databaseFile);
    try {
      service.validateCreateOptions(
        WaddleBackupCreateOptions(
          includeDatabase: includeDatabase,
          includeBlobs: includeBlobs,
          format: format,
          creatorVersion: kWaddlectlPackageVersion,
        ),
      );
    } on ArgumentError catch (e) {
      usageException(e.message);
    }

    final createdAt = DateTime.now().toUtc();
    final ts = compactTimestampUtc(createdAt);
    final outFile = resolveBackupOutputPath(
      outputArg: argResults!['output'] as String?,
      format: format,
      timestampUtcCompact: ts,
    );
    await outFile.parent.create(recursive: true);

    final result = await service.createArchive(
      WaddleBackupCreateOptions(
        includeDatabase: includeDatabase,
        includeBlobs: includeBlobs,
        format: format,
        creatorVersion: kWaddlectlPackageVersion,
        createdAt: createdAt,
      ),
    );
    await outFile.writeAsBytes(result.bytes, flush: true);

    CliEmit(globalOptions).emitJsonOrText({
      'file': outFile.path,
      'format': format == WaddleBackupArchiveFormat.zip ? 'zip' : 'tgz',
      'include_database': includeDatabase,
      'include_blobs': includeBlobs,
      'include_secrets': false,
      'bytes': result.bytes.length,
    });
    if (!globalOptions.outputJson) {
      stdout.writeln('Wrote backup (${result.bytes.length} bytes) to ${outFile.path}.');
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

    final bytes = await backupFile.readAsBytes();
    final archive = decodeWaddleBackupBytes(bytes);
    final manifest = readManifestFromArchive(archive);
    try {
      WaddleBackupService.validateArchiveMatchesManifest(archive, manifest);
    } on FormatException catch (e) {
      usageException(e.message);
    }

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

    final service = WaddleBackupService(databaseFile: globalOptions.databaseFile);
    final restored = await service.restoreArchive(bytes, confirmYes: yes);

    if (restored.secretsBundleIgnored) {
      stderr.writeln(
        'Warning: backup manifest lists encrypted secrets; secret bundles '
        'are no longer restored. Database/media (if present) were restored.',
      );
    }

    CliEmit(globalOptions).emitJsonOrText({
      'restored_from': backupFile.path,
      'include_database': restored.manifest.includeDatabase,
      'include_blobs': restored.manifest.includeBlobs,
      'include_secrets': restored.manifest.includeSecrets,
    });
    if (!globalOptions.outputJson) {
      stdout.writeln('Restore completed from ${backupFile.path}.');
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
