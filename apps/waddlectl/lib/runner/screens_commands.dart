import 'dart:io';

import 'package:args/command_runner.dart';

import '../global_options.dart';
import 'emit.dart';
import 'with_backend.dart';

class ScreensCommand extends Command<void> {
  ScreensCommand(this.globalOptions) : super() {
    addSubcommand(_ScreensList(globalOptions));
    addSubcommand(_ScreensDescribe(globalOptions));
    addSubcommand(_ScreensUpdate(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'screens';

  @override
  String get description => 'Manage screen_definitions (TV slides).';
}

class _ScreensList extends Command<void> {
  _ScreensList(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'list';

  @override
  String get description => 'List all screen definitions.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      CliEmit(globalOptions).emitRows(await b.listScreens());
    }, productionSecrets: false);
  }
}

class _ScreensDescribe extends Command<void> {
  _ScreensDescribe(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'describe';

  @override
  String get description => 'Show one screen definition by id.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl screens describe <id>');
    }
    await withLocalBackend(globalOptions, (b) async {
      final row = await b.describeScreen(rest.first);
      if (row == null) {
        stderr.writeln('Not found: ${rest.first}');
        return;
      }
      CliEmit(globalOptions).emitJsonOrText(row);
    }, productionSecrets: false);
  }
}

class _ScreensUpdate extends Command<void> {
  _ScreensUpdate(this.globalOptions) : super() {
    argParser
      ..addOption('name')
      ..addOption('enabled', allowed: ['true', 'false'])
      ..addOption('dwell-seconds')
      ..addOption('frequency-weight')
      ..addOption('min-gap-between-shows-seconds')
      ..addOption(
        'config-json-file',
        help: 'Path to JSON file for config_json.',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'update';

  @override
  String get description => 'Update scheduling fields for a screen.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl screens update <id> [flags]');
    }
    final id = rest.first;
    final o = argResults!;
    bool? enabled;
    final e = o['enabled'] as String?;
    if (e != null) {
      enabled = e == 'true';
    }
    final dwell = int.tryParse(o['dwell-seconds'] as String? ?? '');
    final weight = int.tryParse(o['frequency-weight'] as String? ?? '');
    final gap = int.tryParse(
      o['min-gap-between-shows-seconds'] as String? ?? '',
    );
    String? configJson;
    final cjf = o['config-json-file'] as String?;
    if (cjf != null && cjf.isNotEmpty) {
      configJson = await File(cjf).readAsString();
    }
    await withLocalBackend(globalOptions, (b) async {
      await b.updateScreen(
        id: id,
        name: o['name'] as String?,
        enabled: enabled,
        dwellSeconds: dwell,
        frequencyWeight: weight,
        minGapBetweenShowsSeconds: gap,
        configJson: configJson,
      );
    }, productionSecrets: false);
  }
}
