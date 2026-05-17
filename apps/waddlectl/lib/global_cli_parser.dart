import 'package:args/args.dart';

/// Global flags parsed before the subcommand name.
ArgParser buildGlobalArgParser() => ArgParser(allowTrailingOptions: true)
  ..addOption(
    'database',
    help: 'Path to waddle_display.db (overrides default / --support-dir).',
  )
  ..addOption(
    'support-dir',
    help: 'Application support directory containing waddle_display.db.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: 'Output format (text | json).',
  );

/// Peels only [buildGlobalArgParser] options from the start of [args]. Everything
/// else (including subcommand-specific flags like `--program-duration-seconds`)
/// stays in [commandArgs] for [CommandRunner.run].
({
  String? databasePath,
  String? supportDirPath,
  String output,
  List<String> commandArgs,
})
parseLeadingGlobalFlags(List<String> args) {
  String? databasePath;
  String? supportDirPath;
  var output = 'text';
  var i = 0;
  while (i < args.length) {
    final a = args[i];
    if (a == '--database') {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for --database');
      }
      databasePath = args[++i];
      i++;
      continue;
    }
    if (a.startsWith('--database=')) {
      databasePath = a.substring('--database='.length);
      i++;
      continue;
    }
    if (a == '--support-dir') {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for --support-dir');
      }
      supportDirPath = args[++i];
      i++;
      continue;
    }
    if (a.startsWith('--support-dir=')) {
      supportDirPath = a.substring('--support-dir='.length);
      i++;
      continue;
    }
    if (a == '-o' || a == '--output') {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for --output');
      }
      output = args[++i];
      i++;
      continue;
    }
    if (a.startsWith('-o=')) {
      output = a.substring('-o='.length);
      i++;
      continue;
    }
    if (a.startsWith('--output=')) {
      output = a.substring('--output='.length);
      i++;
      continue;
    }
    break;
  }
  if (output != 'text' && output != 'json') {
    throw FormatException('Invalid --output (expected text or json): $output');
  }
  return (
    databasePath: databasePath,
    supportDirPath: supportDirPath,
    output: output,
    commandArgs: args.sublist(i),
  );
}
