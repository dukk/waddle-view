import 'package:args/command_runner.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../global_options.dart';
import 'emit.dart';
import 'with_backend.dart';

class RejectCommand extends Command<void> {
  RejectCommand(this.globalOptions) : super() {
    addSubcommand(_RejectList(globalOptions));
    addSubcommand(_RejectAdd(globalOptions));
    addSubcommand(_RejectRemove(globalOptions));
    addSubcommand(_RejectFormatCommand(globalOptions));
    addSubcommand(_RejectRescan(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'reject';

  @override
  String get description =>
      'Manage curse-word reject list (block + censor) and rescan stored content.';
}

class _RejectList extends Command<void> {
  _RejectList(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'list';

  @override
  String get description =>
      'List reject terms (censor + block) and the current censor format.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      final rows = await b.listRejectTerms();
      final fmt = await b.getRejectCensorFormat() ?? kRejectCensorFormatAsterisksFull;
      CliEmit(globalOptions).emitJsonOrText({
        'items': rows,
        'censor_format': fmt,
      });
    });
  }
}

class _RejectAdd extends Command<void> {
  _RejectAdd(this.globalOptions) : super() {
    argParser
      ..addOption(
        'action',
        allowed: [kRejectTermActionCensor, kRejectTermActionBlock],
        help: 'How to handle matches (censor masks text; block suppresses).',
      )
      ..addOption(
        'id',
        help: 'Override the generated row id (default: op_<term>).',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'add';

  @override
  String get description =>
      'Add or replace a reject term. Usage: reject add --action=<censor|block> <term>';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException(
        'Usage: waddlectl reject add --action=<censor|block> [--id=<id>] <term>',
      );
    }
    final rawAction = argResults!['action'] as String?;
    if (rawAction == null) {
      usageException('Missing required --action.');
    }
    final action = rawAction;
    final id = argResults!['id'] as String?;
    await withLocalBackend(globalOptions, (b) async {
      final savedId = await b.upsertRejectTerm(
        term: rest.first,
        action: action,
        id: id,
      );
      // Rescan immediately so the operator sees how many rows were affected.
      final res = await b.rescanRejectContent();
      CliEmit(globalOptions).emitJsonOrText({
        'id': savedId,
        'term': rest.first.trim().toLowerCase(),
        'action': action,
        'rescan': res,
      });
    });
  }
}

class _RejectRemove extends Command<void> {
  _RejectRemove(this.globalOptions) : super() {
    argParser.addFlag(
      'by-id',
      negatable: false,
      help: 'Interpret the positional argument as a row id instead of a term.',
    );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'remove';

  @override
  String get description =>
      'Remove a reject term by term (default) or by row id (--by-id).';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Usage: waddlectl reject remove [--by-id] <term-or-id>');
    }
    final byId = argResults!['by-id'] as bool;
    await withLocalBackend(globalOptions, (b) async {
      final removed = byId
          ? await b.removeRejectTermById(rest.first)
          : await b.removeRejectTermByTerm(rest.first);
      CliEmit(globalOptions).emitJsonOrText({
        if (byId) 'id': rest.first else 'term': rest.first.trim().toLowerCase(),
        'removed': removed,
      });
    });
  }
}

class _RejectFormatCommand extends Command<void> {
  _RejectFormatCommand(this.globalOptions) : super() {
    addSubcommand(_RejectFormatGet(globalOptions));
    addSubcommand(_RejectFormatSet(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'format';

  @override
  String get description => 'Inspect or update the censor mask format.';
}

class _RejectFormatGet extends Command<void> {
  _RejectFormatGet(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'get';

  @override
  String get description => 'Print the current censor mask format.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      final fmt = await b.getRejectCensorFormat() ?? kRejectCensorFormatAsterisksFull;
      CliEmit(globalOptions).emitJsonOrText({'format': fmt});
    });
  }
}

class _RejectFormatSet extends Command<void> {
  _RejectFormatSet(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'set';

  @override
  String get description =>
      'Set the censor mask format. Values: asterisks_full, asterisks_fixed, first_last, bracketed_token.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException(
        'Usage: waddlectl reject format set <asterisks_full|asterisks_fixed|first_last|bracketed_token>',
      );
    }
    await withLocalBackend(globalOptions, (b) async {
      await b.setRejectCensorFormat(rest.first);
      CliEmit(globalOptions).emitJsonOrText({'format': rest.first});
    });
  }
}

class _RejectRescan extends Command<void> {
  _RejectRescan(this.globalOptions) : super();

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'rescan';

  @override
  String get description =>
      'Re-evaluate stored content against the current reject list and suppress block matches.';

  @override
  Future<void> run() async {
    await withLocalBackend(globalOptions, (b) async {
      final res = await b.rescanRejectContent();
      CliEmit(globalOptions).emitJsonOrText(res);
    });
  }
}
