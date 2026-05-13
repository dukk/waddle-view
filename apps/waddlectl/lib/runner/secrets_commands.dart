import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../global_options.dart';
import 'emit.dart';
import 'with_backend.dart';

class SecretsCommand extends Command<void> {
  SecretsCommand(this.globalOptions) : super() {
    addSubcommand(_SecretsDescribe(globalOptions));
    addSubcommand(_SecretsSet(globalOptions));
    addSubcommand(_SecretsDelete(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'secrets';

  @override
  String get description => 'Read/write raw SecretStore keys (advanced).';
}

class _SecretsDescribe extends Command<void> {
  _SecretsDescribe(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'describe';

  @override
  String get description =>
      'Read a secret (value redacted in text output).';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl secrets describe <key>');
    }
    final key = rest.first;
    await withLocalBackend(globalOptions, (b) async {
      final v = await b.describeSecret(key);
      if (globalOptions.outputJson) {
        CliEmit(globalOptions).emitJsonOrText({
          'key': key,
          'present': v != null,
          if (v != null) 'value_length': v.length,
        });
      } else {
        if (v == null) {
          stdout.writeln('(not set)');
        } else {
          stdout.writeln('(set, ${v.length} chars)');
        }
      }
    }, productionSecrets: true);
  }
}

class _SecretsSet extends Command<void> {
  _SecretsSet(this.globalOptions) : super() {
    argParser.addOption('from-file');
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'set';

  @override
  String get description => 'Write a secret value (stdin or --from-file).';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException(
        'Usage: waddlectl secrets set <key> [--from-file=PATH]',
      );
    }
    final key = rest.first;
    final path = argResults!['from-file'] as String?;
    final String raw;
    if (path != null && path.isNotEmpty) {
      raw = await File(path).readAsString();
    } else {
      raw = await utf8.decodeStream(stdin);
    }
    final value = raw.trim();
    if (value.isEmpty) {
      stderr.writeln('Refusing empty secret.');
      return;
    }
    await withLocalBackend(globalOptions, (b) async {
      await b.setSecret(key, value);
    }, productionSecrets: true);
  }
}

class _SecretsDelete extends Command<void> {
  _SecretsDelete(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'delete';

  @override
  String get description => 'Remove a secret key.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl secrets delete <key>');
    }
    await withLocalBackend(globalOptions, (b) async {
      await b.deleteSecret(rest.first);
    }, productionSecrets: true);
  }
}
