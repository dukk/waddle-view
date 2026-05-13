import 'package:args/args.dart';

/// Global flags parsed before the subcommand name.
ArgParser buildGlobalArgParser() =>
    ArgParser(allowTrailingOptions: true)
      ..addOption(
        'database',
        help: 'Path to waddle_view.sqlite (overrides default / --support-dir).',
      )
      ..addOption(
        'support-dir',
        help: 'Application support directory containing waddle_view.sqlite.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        allowed: ['text', 'json'],
        defaultsTo: 'text',
        help: 'Output format (text | json).',
      );
