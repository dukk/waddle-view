import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:waddlectl/run_app.dart';

void main() {
  test('runWaddlectl version returns 0', () async {
    final code = await runWaddlectl(['--output=json', 'version']);
    expect(code, 0);
  });

  test('runWaddlectl options returns 0', () async {
    final code = await runWaddlectl(['options']);
    expect(code, 0);
  });

  test('config set/get with temp database', () async {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_cli');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // Best-effort; temp dir may be locked or already removed.
      }
    });
    final dbPath = p.join(tmp.path, 'waddle_display.db');
    File(dbPath).writeAsStringSync('');

    expect(
      await runWaddlectl([
        '--database',
        dbPath,
        'config',
        'set',
        'waddlectl.cli',
        'ok',
      ]),
      0,
    );
    expect(
      await runWaddlectl([
        '--database',
        dbPath,
        '--output=json',
        'config',
        'get',
        'waddlectl.cli',
      ]),
      0,
    );
  });

  test('help config lists subcommands', () async {
    final code = await runWaddlectl(['help', 'config']);
    expect(code, 0);
  });

  test('reject add/list/remove with temp database', () async {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_cli_reject');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // Best-effort cleanup; locks are acceptable.
      }
    });
    final dbPath = p.join(tmp.path, 'waddle_display.db');
    File(dbPath).writeAsStringSync('');

    expect(
      await runWaddlectl([
        '--database',
        dbPath,
        'reject',
        'add',
        '--action=block',
        'cussword',
      ]),
      0,
    );
    expect(
      await runWaddlectl([
        '--database',
        dbPath,
        '--output=json',
        'reject',
        'list',
      ]),
      0,
    );
    expect(
      await runWaddlectl([
        '--database',
        dbPath,
        'reject',
        'format',
        'set',
        'bracketed_token',
      ]),
      0,
    );
    expect(
      await runWaddlectl([
        '--database',
        dbPath,
        'reject',
        'rescan',
      ]),
      0,
    );
    expect(
      await runWaddlectl([
        '--database',
        dbPath,
        'reject',
        'remove',
        'cussword',
      ]),
      0,
    );
  });

  test('help backup lists subcommands', () async {
    final code = await runWaddlectl(['help', 'backup']);
    expect(code, 0);
  });
}
