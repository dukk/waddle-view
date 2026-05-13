import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Runs the real `dart run waddlectl` subprocess on Linux (secret-tool + SQLite).
void main() {
  test('subprocess: secrets export then import with password file', () async {
    if (!Platform.isLinux) {
      return;
    }
    final tmp = Directory.systemTemp.createTempSync('waddlectl_cli_linux');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final db1 = p.join(tmp.path, 'a.sqlite');
    final db2 = p.join(tmp.path, 'b.sqlite');
    File(db1).writeAsStringSync('');
    File(db2).writeAsStringSync('');

    final bundle = p.join(tmp.path, 'secrets.bin');
    final pwFile = File(p.join(tmp.path, 'pw.txt'))
      ..writeAsStringSync('bundle-pass\n');

    Future<int> runCli(List<String> args) async {
      final r = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'waddlectl', ...args],
        workingDirectory: Directory.current.path,
        environment: Platform.environment,
      );
      if (r.exitCode != 0) {
        fail(
          'dart run waddlectl failed (${r.exitCode})\n'
          'stdout:\n${r.stdout}\nstderr:\n${r.stderr}',
        );
      }
      return r.exitCode;
    }

    await runCli([
      '--database',
      db1,
      'secrets',
      'export',
      '--file',
      bundle,
      '--password-file',
      pwFile.path,
    ]);

    await runCli([
      '--database',
      db2,
      'secrets',
      'import',
      '--file',
      bundle,
      '--password-file',
      pwFile.path,
    ]);
  });
}
