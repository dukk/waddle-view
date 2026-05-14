import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../export_sqlite_seed_sql.dart';
import '../global_options.dart';

class SqliteCommand extends Command<void> {
  SqliteCommand(this.globalOptions) : super() {
    addSubcommand(_SqliteExportSeed(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'sqlite';

  @override
  String get description => 'SQLite utilities (data-only seed export).';
}

class _SqliteExportSeed extends Command<void> {
  _SqliteExportSeed(this.globalOptions) : super() {
    argParser
      ..addOption(
        'file',
        abbr: 'o',
        help:
            'Write SQL to this path. Default: <database-stem>_seed.sql next to the database.',
      )
      ..addFlag(
        'stdout',
        negatable: false,
        help: 'Write SQL to stdout as UTF-8 (use for piping).',
      )
      ..addFlag(
        'include-sqlite-sequence-rows',
        negatable: false,
        help:
            'Also emit INSERTs for sqlite_sequence after data (normally not needed).',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'export-seed';

  @override
  String get description =>
      'Export all user-table rows to a data-only SQL seed script (DELETE + INSERT).';

  @override
  Future<void> run() async {
    final dbFile = globalOptions.databaseFile;
    if (!dbFile.existsSync()) {
      stderr.writeln('SQLite file not found: ${dbFile.absolute.path}');
      throw StateError('missing database file');
    }

    final includeSeq = argResults!['include-sqlite-sequence-rows'] as bool;
    final sql = exportSqliteSeedSql(
      dbFile,
      includeSqliteSequenceRows: includeSeq,
    );

    final toStdout = argResults!['stdout'] as bool;
    if (toStdout) {
      stdout.add(utf8.encode(sql));
      return;
    }

    final explicit = argResults!['file'] as String?;
    final outPath = explicit != null && explicit.isNotEmpty
        ? File(p.normalize(explicit)).absolute
        : File(
            p.join(
              p.dirname(dbFile.absolute.path),
              '${p.basenameWithoutExtension(dbFile.path)}_seed.sql',
            ),
          );

    outPath.parent.createSync(recursive: true);
    outPath.writeAsStringSync(sql, encoding: utf8, flush: true);
    stderr.writeln(
      'Wrote ${outPath.path} (${utf8.encode(sql).length} bytes) from ${dbFile.absolute.path}',
    );
  }
}
