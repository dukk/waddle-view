import 'dart:io';

import 'package:args/command_runner.dart';

import '../global_options.dart';
import 'emit.dart';
import 'with_backend.dart';

class TickersCommand extends Command<void> {
  TickersCommand(this.globalOptions) : super() {
    addSubcommand(_TickersList(globalOptions));
    addSubcommand(_TickersDescribe(globalOptions));
    addSubcommand(_TickersUpdate(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'tickers';

  @override
  String get description =>
      'Manage ticker_definitions (curator slots; not live marquee text).';
}

class _TickersList extends Command<void> {
  _TickersList(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'list';

  @override
  String get description => 'List ticker definition rows.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      CliEmit(globalOptions).emitRows(await b.listTickers());
    });
  }
}

class _TickersDescribe extends Command<void> {
  _TickersDescribe(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'describe';

  @override
  String get description => 'Show one ticker definition by id.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl tickers describe <id>');
    }
    await withLocalBackend(globalOptions, (b) async {
      final row = await b.describeTicker(rest.first);
      if (row == null) {
        stderr.writeln('Not found: ${rest.first}');
        return;
      }
      CliEmit(globalOptions).emitJsonOrText(row);
    });
  }
}

class _TickersUpdate extends Command<void> {
  _TickersUpdate(this.globalOptions) : super() {
    argParser
      ..addOption('name')
      ..addOption('enabled', allowed: ['true', 'false'])
      ..addOption('ticker-type')
      ..addOption('frequency-weight')
      ..addOption('sort-order')
      ..addOption('config-key');
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'update';

  @override
  String get description => 'Update a ticker definition row.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl tickers update <id> [flags]');
    }
    final id = rest.first;
    final o = argResults!;
    bool? enabled;
    final en = o['enabled'] as String?;
    if (en != null) {
      enabled = en == 'true';
    }
    await withLocalBackend(globalOptions, (b) async {
      await b.updateTicker(
        id: id,
        name: o['name'] as String?,
        enabled: enabled,
        tickerType: o['ticker-type'] as String?,
        frequencyWeight: int.tryParse(o['frequency-weight'] as String? ?? ''),
        sortOrder: int.tryParse(o['sort-order'] as String? ?? ''),
        configKey: o['config-key'] as String?,
      );
    });
  }
}
