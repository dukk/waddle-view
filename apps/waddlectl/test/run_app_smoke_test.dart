import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    final dbPath = p.join(tmp.path, 'waddle_view.sqlite');
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
}
