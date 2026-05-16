import 'dart:io';

import 'package:args/command_runner.dart';

import '../global_options.dart';
import 'emit.dart';
import 'with_backend.dart';

class IntegrationsCommand extends Command<void> {
  IntegrationsCommand(this.globalOptions) : super() {
    addSubcommand(_IntegrationsList(globalOptions));
    addSubcommand(_IntegrationsDescribe(globalOptions));
    addSubcommand(_IntegrationsUpdate(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'integrations';

  @override
  String get description => 'Manage integrations table rows.';
}

class _IntegrationsList extends Command<void> {
  _IntegrationsList(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'list';

  @override
  String get description => 'List all integrations.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      CliEmit(globalOptions).emitRows(await b.listIntegrations());
    });
  }
}

class _IntegrationsDescribe extends Command<void> {
  _IntegrationsDescribe(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'describe';

  @override
  String get description => 'Show one integration row by id.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl integrations describe <id>');
    }
    await withLocalBackend(globalOptions, (b) async {
      final row = await b.describeIntegration(rest.first);
      if (row == null) {
        stderr.writeln('Not found: ${rest.first}');
        return;
      }
      CliEmit(globalOptions).emitJsonOrText(row);
    });
  }
}

class _IntegrationsUpdate extends Command<void> {
  _IntegrationsUpdate(this.globalOptions) : super() {
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
  String get description => 'Update integration poll / URLs / config_json.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl integrations update <id> [flags]');
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
      await b.updateIntegration(
        id: id,
        enabled: enabled,
        pollSeconds: poll,
        baseUrl: o['base-url'] as String?,
        configJson: configJson,
      );
    });
  }
}
