import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';

/// Parsed global CLI flags (before subcommands).
class GlobalCliOptions {
  GlobalCliOptions({required this.databaseFile, required this.outputJson});

  /// Used for `version`, `options`, and `help` on hosts where no DB path is set.
  factory GlobalCliOptions.forMetaCommands({required bool outputJson}) {
    return GlobalCliOptions(
      databaseFile: File('__waddlectl_meta_commands_no_db__'),
      outputJson: outputJson,
    );
  }

  final File databaseFile;
  final bool outputJson;

  static GlobalCliOptions fromArgResults({
    required String? databasePath,
    required String? supportDirPath,
    required String? output,
  }) {
    final jsonOut = output == 'json';
    File dbFile;
    if (databasePath != null && databasePath.isNotEmpty) {
      dbFile = File(databasePath);
    } else if (supportDirPath != null && supportDirPath.isNotEmpty) {
      dbFile = File(p.join(supportDirPath, 'waddle_display.db'));
    } else if (Platform.isLinux) {
      dbFile = defaultLinuxWaddleSqliteFile();
    } else {
      throw StateError(
        'Non-Linux host: pass --database=PATH to the waddle_display.db file.',
      );
    }
    return GlobalCliOptions(databaseFile: dbFile, outputJson: jsonOut);
  }
}
