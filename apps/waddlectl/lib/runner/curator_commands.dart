import 'dart:io';

import 'package:args/command_runner.dart';

import '../global_options.dart';
import 'emit.dart';
import 'with_backend.dart';

class CuratorCommand extends Command<void> {
  CuratorCommand(this.globalOptions) : super() {
    addSubcommand(_CuratorDescribeProgram(globalOptions));
    addSubcommand(_CuratorUpdateProgram(globalOptions));
    addSubcommand(CuratorLimitsCommand(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'curator';

  @override
  String get description =>
      'Curator program settings and per-data-key limits.';
}

class _CuratorDescribeProgram extends Command<void> {
  _CuratorDescribeProgram(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'describe-program';

  @override
  String get description => 'Show curator-related config_key_values.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      CliEmit(globalOptions).emitJsonOrText(await b.describeCuratorProgram());
    }, productionSecrets: false);
  }
}

class _CuratorUpdateProgram extends Command<void> {
  _CuratorUpdateProgram(this.globalOptions) : super() {
    argParser
      ..addOption('program-duration-seconds')
      ..addOption('history-depth')
      ..addOption('ticker-news-pixels-per-second')
      ..addOption('require-news-photo-for-screens', allowed: ['true', 'false'])
      ..addOption('display-theme-id')
      ..addOption('display-text-scale-screen')
      ..addOption('display-text-scale-ticker');
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'update-program';

  @override
  String get description =>
      'Update curator program / theme / text scale keys.';

  @override
  Future<void> run() async {
    final o = argResults!;
    final dur = int.tryParse(o['program-duration-seconds'] as String? ?? '');
    final depth = int.tryParse(o['history-depth'] as String? ?? '');
    final tickerPx = o['ticker-news-pixels-per-second'] as String?;
    bool? reqPhoto;
    final rp = o['require-news-photo-for-screens'] as String?;
    if (rp != null) {
      reqPhoto = rp == 'true';
    }
    await withLocalBackend(globalOptions, (b) async {
      await b.updateCuratorProgram(
        programDurationSeconds: dur,
        historyDepth: depth,
        tickerNewsPixelsPerSecond: tickerPx,
        requireNewsPhotoForScreens: reqPhoto,
        displayThemeId: o['display-theme-id'] as String?,
        displayTextScaleScreen: o['display-text-scale-screen'] as String?,
        displayTextScaleTicker: o['display-text-scale-ticker'] as String?,
      );
    }, productionSecrets: false);
  }
}

class CuratorLimitsCommand extends Command<void> {
  CuratorLimitsCommand(this.globalOptions) : super() {
    addSubcommand(_LimitsList(globalOptions));
    addSubcommand(_LimitsDescribe(globalOptions));
    addSubcommand(_LimitsUpdate(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'limits';

  @override
  String get description =>
      'Per data_key min/max placements per program (curator_data_key_program_limits).';
}

class _LimitsList extends Command<void> {
  _LimitsList(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'list';

  @override
  String get description => 'List curator_data_key_program_limits rows.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      CliEmit(globalOptions).emitRows(await b.listCuratorLimits());
    }, productionSecrets: false);
  }
}

class _LimitsDescribe extends Command<void> {
  _LimitsDescribe(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'describe';

  @override
  String get description => 'Show limits for one data_key.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl curator limits describe <data_key>');
    }
    await withLocalBackend(globalOptions, (b) async {
      final row = await b.describeCuratorLimit(rest.first);
      if (row == null) {
        stderr.writeln('Not found: ${rest.first}');
        return;
      }
      CliEmit(globalOptions).emitJsonOrText(row);
    }, productionSecrets: false);
  }
}

class _LimitsUpdate extends Command<void> {
  _LimitsUpdate(this.globalOptions) : super() {
    argParser
      ..addOption('min-placements-per-program')
      ..addOption('max-placements-per-program');
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'update';

  @override
  String get description => 'Upsert limits for a data_key.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException(
        'Usage: waddlectl curator limits update <data_key> [flags]',
      );
    }
    final dataKey = rest.first;
    final o = argResults!;
    await withLocalBackend(globalOptions, (b) async {
      await b.updateCuratorLimit(
        dataKey: dataKey,
        minPlacementsPerProgram: int.tryParse(
          o['min-placements-per-program'] as String? ?? '',
        ),
        maxPlacementsPerProgram: int.tryParse(
          o['max-placements-per-program'] as String? ?? '',
        ),
      );
    }, productionSecrets: false);
  }
}
