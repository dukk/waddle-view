import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../global_options.dart';
import '../secret_bundle_ops.dart';
import '../secret_bundle_password.dart';
import 'emit.dart';
import 'with_backend.dart';

class SecretsCommand extends Command<void> {
  SecretsCommand(this.globalOptions) : super() {
    addSubcommand(_SecretsDescribe(globalOptions));
    addSubcommand(_SecretsSet(globalOptions));
    addSubcommand(_SecretsDelete(globalOptions));
    addSubcommand(_SecretsExport(globalOptions));
    addSubcommand(_SecretsImport(globalOptions));
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
  String get description => 'Read a secret (value redacted in text output).';

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
      usageException('Usage: waddlectl secrets set <key> [--from-file=PATH]');
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

class _SecretsExport extends Command<void> {
  _SecretsExport(this.globalOptions) : super() {
    argParser
      ..addOption('file', help: 'Path to write the encrypted secret bundle.')
      ..addOption(
        'password-file',
        help:
            'Read encryption password from the first line of this file (non-interactive).',
      )
      ..addOption(
        'password-env',
        help:
            'Read encryption password from this environment variable (non-interactive).',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'export';

  @override
  String get description =>
      'Write all SecretStore keys to an encrypted bundle file (password-protected).';

  @override
  Future<void> run() async {
    final path = argResults!['file'] as String?;
    if (path == null || path.isEmpty) {
      usageException(
        'Usage: waddlectl secrets export --file=PATH '
        '[--password-file=PATH] [--password-env=NAME]',
      );
    }
    if (argResults!.rest.isNotEmpty) {
      usageException('Unexpected arguments: ${argResults!.rest.join(' ')}');
    }

    late final String password;
    try {
      password = await resolveSecretBundlePassword(
        passwordFile: argResults!['password-file'] as String?,
        passwordEnv: argResults!['password-env'] as String?,
        confirm: true,
      );
    } on StateError catch (e) {
      usageException(e.message);
    }

    await withLocalBackend(globalOptions, (b) async {
      final n = await exportSecretsToFile(b.secrets, password, File(path));
      if (globalOptions.outputJson) {
        CliEmit(
          globalOptions,
        ).emitJsonOrText({'file': path, 'keys_exported': n});
      } else {
        stdout.writeln('Exported $n secret key(s) to $path.');
      }
    }, productionSecrets: true);
  }
}

class _SecretsImport extends Command<void> {
  _SecretsImport(this.globalOptions) : super() {
    argParser
      ..addOption('file', help: 'Path to an encrypted secret bundle file.')
      ..addOption(
        'password-file',
        help:
            'Read decryption password from the first line of this file (non-interactive).',
      )
      ..addOption(
        'password-env',
        help:
            'Read decryption password from this environment variable (non-interactive).',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'import';

  @override
  String get description =>
      'Merge secrets from an encrypted bundle into the SecretStore (add/update only).';

  @override
  Future<void> run() async {
    final path = argResults!['file'] as String?;
    if (path == null || path.isEmpty) {
      usageException(
        'Usage: waddlectl secrets import --file=PATH '
        '[--password-file=PATH] [--password-env=NAME]',
      );
    }
    if (argResults!.rest.isNotEmpty) {
      usageException('Unexpected arguments: ${argResults!.rest.join(' ')}');
    }

    final file = File(path);
    if (!await file.exists()) {
      usageException('Bundle file not found: $path');
    }

    late final String password;
    try {
      password = await resolveSecretBundlePassword(
        passwordFile: argResults!['password-file'] as String?,
        passwordEnv: argResults!['password-env'] as String?,
        confirm: false,
      );
    } on StateError catch (e) {
      usageException(e.message);
    }

    late final Map<String, String> entries;
    try {
      entries = await decodeSecretBundleFile(file, password);
    } on FormatException catch (e) {
      usageException(e.message);
    }

    await withLocalBackend(globalOptions, (b) async {
      await mergeSecretsImport(b.secrets, entries);
      if (globalOptions.outputJson) {
        CliEmit(
          globalOptions,
        ).emitJsonOrText({'file': path, 'keys_imported': entries.length});
      } else {
        stdout.writeln(
          'Imported ${entries.length} secret key(s) from $path (merge).',
        );
      }
    }, productionSecrets: true);
  }
}
