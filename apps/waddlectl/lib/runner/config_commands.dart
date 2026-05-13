import 'package:args/command_runner.dart';

import '../global_options.dart';
import 'emit.dart';
import 'with_backend.dart';

class ConfigCommand extends Command<void> {
  ConfigCommand(this.globalOptions) : super() {
    addSubcommand(_ConfigList(globalOptions));
    addSubcommand(_ConfigGet(globalOptions));
    addSubcommand(_ConfigSet(globalOptions));
    addSubcommand(_ConfigUnset(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'config';

  @override
  String get description =>
      'Manage config_key_values (curator, theme, display options).';
}

class _ConfigList extends Command<void> {
  _ConfigList(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'list';

  @override
  String get description => 'List all configuration keys.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      final rows = await b.listConfig();
      CliEmit(globalOptions).emitRows(rows);
    }, productionSecrets: false);
  }
}

class _ConfigGet extends Command<void> {
  _ConfigGet(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'get';

  @override
  String get description => 'Print one configuration value.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl config get <key>');
    }
    final key = rest.first;
    await withLocalBackend(globalOptions, (b) async {
      final v = await b.getConfig(key);
      CliEmit(globalOptions).emitJsonOrText({'key': key, 'value': v});
    }, productionSecrets: false);
  }
}

class _ConfigSet extends Command<void> {
  _ConfigSet(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'set';

  @override
  String get description =>
      'Set a configuration key (value = all remaining arguments).';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length < 2) {
      usageException('Usage: waddlectl config set <key> <value...>');
    }
    final key = rest.first;
    final value = rest.sublist(1).join(' ');
    await withLocalBackend(globalOptions, (b) async {
      await b.setConfig(key, value);
    }, productionSecrets: false);
  }
}

class _ConfigUnset extends Command<void> {
  _ConfigUnset(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'unset';

  @override
  String get description => 'Delete a configuration key.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl config unset <key>');
    }
    await withLocalBackend(globalOptions, (b) async {
      await b.unsetConfig(rest.first);
    }, productionSecrets: false);
  }
}
