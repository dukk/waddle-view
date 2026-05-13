import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'global_cli_parser.dart';
import 'global_options.dart';
import 'runner/cli_runner.dart';

/// Entry for `dart run waddlectl` / compiled `waddlectl` binary.
Future<int> runWaddlectl(List<String> args) async {
  final globals = buildGlobalArgParser();

  late final ArgResults top;
  try {
    top = globals.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(
      'Run `waddlectl help` or `waddlectl options` for global flags.',
    );
    return 64;
  }

  final rest = top.rest;
  if (rest.isEmpty) {
    stdout.writeln(WaddlectlRootRunner.rootUsage());
    return 0;
  }

  final metaFirst = {'help', 'version', 'options'}.contains(rest.first);
  late final GlobalCliOptions options;
  if (metaFirst) {
    options = GlobalCliOptions.forMetaCommands(
      outputJson: (top['output'] as String?) == 'json',
    );
  } else {
    try {
      options = GlobalCliOptions.fromArgResults(
        databasePath: top['database'] as String?,
        supportDirPath: top['support-dir'] as String?,
        output: top['output'] as String?,
      );
    } on StateError catch (e) {
      stderr.writeln(e.message);
      return 78;
    }
  }

  final runner = WaddlectlRootRunner(options);
  if (rest.first == 'help') {
    return await HelpPrinter.printPath(runner, rest.skip(1).toList());
  }

  try {
    await runner.run(rest);
    return 0;
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    return 64;
  } on Object catch (e, st) {
    stderr.writeln(e);
    if (options.outputJson) {
      stderr.writeln(jsonEncode({'error': '$e', 'stack': '$st'}));
    }
    return 1;
  }
}
