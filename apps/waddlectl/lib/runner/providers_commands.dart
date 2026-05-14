import 'dart:io';

import 'package:args/command_runner.dart';

import '../global_options.dart';
import 'emit.dart';
import 'with_backend.dart';

class ProvidersCommand extends Command<void> {
  ProvidersCommand(this.globalOptions) : super() {
    addSubcommand(_ProvidersList(globalOptions));
    addSubcommand(_ProvidersDescribe(globalOptions));
    addSubcommand(_ProvidersUpdate(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'providers';

  @override
  String get description => 'Manage provider_settings rows.';
}

class _ProvidersList extends Command<void> {
  _ProvidersList(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'list';

  @override
  String get description => 'List all providers.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      CliEmit(globalOptions).emitRows(await b.listProviders());
    });
  }
}

class _ProvidersDescribe extends Command<void> {
  _ProvidersDescribe(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'describe';

  @override
  String get description => 'Show one provider row by id.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl providers describe <id>');
    }
    await withLocalBackend(globalOptions, (b) async {
      final row = await b.describeProvider(rest.first);
      if (row == null) {
        stderr.writeln('Not found: ${rest.first}');
        return;
      }
      CliEmit(globalOptions).emitJsonOrText(row);
    });
  }
}

class _ProvidersUpdate extends Command<void> {
  _ProvidersUpdate(this.globalOptions) : super() {
    argParser
      ..addOption('enabled', allowed: ['true', 'false'])
      ..addOption('poll-seconds')
      ..addOption('base-url')
      ..addOption('config-json-file');
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'update';

  @override
  String get description => 'Update provider poll / URLs / config_json.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl providers update <id> [flags]');
    }
    final id = rest.first;
    final o = argResults!;
    bool? enabled;
    final en = o['enabled'] as String?;
    if (en != null) {
      enabled = en == 'true';
    }
    final poll = int.tryParse(o['poll-seconds'] as String? ?? '');
    String? configJson;
    final cjf = o['config-json-file'] as String?;
    if (cjf != null && cjf.isNotEmpty) {
      configJson = await File(cjf).readAsString();
    }
    await withLocalBackend(globalOptions, (b) async {
      await b.updateProvider(
        id: id,
        enabled: enabled,
        pollSeconds: poll,
        baseUrl: o['base-url'] as String?,
        configJson: configJson,
      );
    });
  }
}
