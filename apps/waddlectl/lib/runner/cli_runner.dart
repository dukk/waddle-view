import 'dart:io';

import 'package:args/command_runner.dart';

import '../global_cli_parser.dart';
import '../global_options.dart';
import '../version.dart';
import 'backup_commands.dart';
import 'config_commands.dart';
import 'curator_commands.dart';
import 'emit.dart';
import 'providers_commands.dart';
import 'reject_commands.dart';
import 'screens_commands.dart';
import 'sqlite_commands.dart';
import 'tickers_commands.dart';

/// Handles `waddlectl help ...` without registering a second `help` command on
/// the root [ArgParser] (the default [CommandRunner] `help` is kept for `-h`).
class HelpPrinter {
  static Future<int> printPath(
    WaddlectlRootRunner root,
    List<String> parts,
  ) async {
    if (parts.isEmpty) {
      stdout.writeln(WaddlectlRootRunner.rootUsage());
      return 0;
    }
    final first = root.commands[parts.first];
    if (first == null) {
      stderr.writeln('Unknown command "${parts.first}".');
      return 64;
    }
    Command<void> command = first;
    for (var i = 1; i < parts.length; i++) {
      final next = command.subcommands[parts[i]];
      if (next == null) {
        stderr.writeln('Unknown subcommand: ${parts[i]}');
        return 64;
      }
      command = next;
    }
    stdout.writeln(command.usage);
    return 0;
  }
}

/// Top-level `waddlectl` command runner (after global flags are parsed).
class WaddlectlRootRunner extends CommandRunner<void> {
  WaddlectlRootRunner(this.globalOptions)
    : super('waddlectl', 'Waddle View operator CLI (local SQLite).') {
    addCommand(OptionsCommand());
    addCommand(VersionCommand(globalOptions));
    addCommand(ConfigCommand(globalOptions));
    addCommand(ScreensCommand(globalOptions));
    addCommand(ProvidersCommand(globalOptions));
    addCommand(TickersCommand(globalOptions));
    addCommand(CuratorCommand(globalOptions));
    addCommand(BackupCommand(globalOptions));
    addCommand(RejectCommand(globalOptions));
    addCommand(SqliteCommand(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  static String rootUsage() {
    final b = StringBuffer()
      ..writeln('Usage: waddlectl [<global-flags>] <command> [<args>...]')
      ..writeln()
      ..writeln('Overview:')
      ..writeln(
        '  Configure the Waddle View dashboard from the shell using the same',
      )
      ..writeln('  SQLite database file as the display app.')
      ..writeln()
      ..writeln('Command groups:')
      ..writeln(
        '  ${'config'.padRight(14)} Configuration key-value pairs (config_key_values)',
      )
      ..writeln(
        '  ${'screens'.padRight(14)} Screen definitions (screen_definitions)',
      )
      ..writeln(
        '  ${'providers'.padRight(14)} Provider settings (provider_settings)',
      )
      ..writeln(
        '  ${'tickers'.padRight(14)} Ticker definition slots (ticker_definitions)',
      )
      ..writeln(
        '  ${'curator'.padRight(14)} Curator program settings and data-key limits',
      )
      ..writeln(
        '  ${'backup'.padRight(14)} Full backup / restore / schedule (SQLite + media)',
      )
      ..writeln(
        '  ${'reject'.padRight(14)} Curse-word reject list (block + censor) & rescan',
      )
      ..writeln('  ${'sqlite'.padRight(14)} SQLite utilities (export-seed)')
      ..writeln(
        '  ${'help'.padRight(14)} Print help for a command path (see below)',
      )
      ..writeln('  ${'options'.padRight(14)} List global flags only')
      ..writeln('  ${'version'.padRight(14)} Print tool version')
      ..writeln()
      ..writeln(
        'Use `waddlectl help <group>` for nested commands (gcloud-style).',
      )
      ..writeln('Examples:')
      ..writeln('  waddlectl --database=/path/waddle_view.sqlite config list')
      ..writeln('  waddlectl help screens')
      ..writeln('  waddlectl help screens update')
      ..writeln()
      ..writeln(
        'Use `waddlectl options` for global flags (--database, --output, …).',
      );
    return b.toString();
  }
}

class OptionsCommand extends Command<void> {
  OptionsCommand() : super();

  @override
  String get name => 'options';

  @override
  String get description => 'List global flags (like kubectl options).';

  @override
  Future<void> run() async {
    stdout.writeln(buildGlobalArgParser().usage);
  }
}

class VersionCommand extends Command<void> {
  VersionCommand(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'version';

  @override
  String get description => 'Print waddlectl version information.';

  @override
  Future<void> run() async {
    CliEmit(
      globalOptions,
    ).emitJsonOrText({'waddlectl': kWaddlectlPackageVersion});
  }
}
